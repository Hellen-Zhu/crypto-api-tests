#!/usr/bin/env python
"""
从api_auto_cases的parameters中移除outputs和validations字段
这两个字段不应该放在parameters中
"""

import os
import sys
import json
from pathlib import Path
sys.path.insert(0, str(Path.cwd()))

from dotenv import load_dotenv
load_dotenv()

from core.db_handler import get_db_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text

def clean_parameters():
    # 初始化数据库连接
    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        print("=== 开始清理api_auto_cases的parameters字段 ===\n")

        # 1. 首先获取所有需要清理的测试用例
        query = """
        SELECT id, name, parameters
        FROM api_auto_cases
        WHERE parameters IS NOT NULL
        """

        result = session.execute(text(query))
        cases_to_update = []

        for row in result:
            case_id = row[0]
            case_name = row[1]
            parameters = row[2]

            # 检查是否需要清理
            needs_update = False
            if 'steps' in parameters:
                for step in parameters['steps']:
                    if 'outputs' in step or 'validations' in step:
                        needs_update = True
                        break

            if needs_update:
                cases_to_update.append({
                    'id': case_id,
                    'name': case_name,
                    'parameters': parameters
                })

        print(f"发现 {len(cases_to_update)} 个需要清理的测试用例\n")

        # 2. 清理每个测试用例
        for case in cases_to_update:
            case_id = case['id']
            case_name = case['name']
            parameters = case['parameters']

            print(f"处理 Case {case_id}: {case_name}")

            # 清理parameters
            cleaned_params = {'steps': []}

            for step in parameters.get('steps', []):
                # 创建清理后的step
                cleaned_step = {}

                # 保留需要的字段
                for key in ['order', 'path', 'method', 'description', 'request']:
                    if key in step:
                        cleaned_step[key] = step[key]

                # 明确不保留outputs和validations
                # 这些应该在其他地方管理

                cleaned_params['steps'].append(cleaned_step)

            # 更新数据库
            update_query = """
            UPDATE api_auto_cases
            SET parameters = :parameters
            WHERE id = :case_id
            """

            session.execute(text(update_query), {
                'parameters': json.dumps(cleaned_params),
                'case_id': case_id
            })

            print(f"  ✅ 已清理outputs和validations字段")

        # 3. 提交事务
        session.commit()

        # 4. 验证清理结果
        print("\n=== 验证清理结果 ===\n")

        verify_query = """
        SELECT
            id,
            name,
            CASE
                WHEN parameters::text LIKE '%outputs%' THEN 'Still has outputs'
                WHEN parameters::text LIKE '%validations%' THEN 'Still has validations'
                ELSE 'Clean'
            END as status
        FROM api_auto_cases
        WHERE id IN (SELECT id FROM api_auto_cases ORDER BY id)
        """

        result = session.execute(text(verify_query))

        clean_count = 0
        not_clean = []

        for row in result:
            if row[2] == 'Clean':
                clean_count += 1
            else:
                not_clean.append(f"Case {row[0]} ({row[1]}): {row[2]}")

        print(f"✅ 清理完成: {clean_count} 个测试用例已清理")

        if not_clean:
            print(f"\n⚠️ 以下测试用例可能还需要检查:")
            for item in not_clean:
                print(f"  - {item}")

        # 5. 显示一个清理后的示例
        print("\n=== 清理后的parameters示例 ===\n")

        sample_query = """
        SELECT jsonb_pretty(parameters)
        FROM api_auto_cases
        WHERE id = 10
        LIMIT 1
        """

        result = session.execute(text(sample_query))
        sample = result.scalar()

        if sample:
            print(sample[:500] + '...' if len(sample) > 500 else sample)

    except Exception as e:
        session.rollback()
        print(f"❌ 清理失败: {e}")
        import traceback
        traceback.print_exc()
    finally:
        session.close()

if __name__ == "__main__":
    clean_parameters()