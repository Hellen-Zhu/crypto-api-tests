#!/usr/bin/env python
"""
合并K线测试用例到现有的10、11、12号测试用例中
并清理variables中的test_type、description、expected_interval字段
"""

import os
import sys
from pathlib import Path
sys.path.insert(0, str(Path.cwd()))

from dotenv import load_dotenv
load_dotenv()

from core.db_handler import get_db_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text
import json

def merge_candlestick_cases():
    # 初始化数据库连接
    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        print("开始合并测试用例...")

        # 1. 先删除现有的10、11、12号测试用例的数据集
        print("  1. 删除现有的10、11、12号测试用例数据集...")
        session.execute(text("DELETE FROM case_data_sets WHERE case_id IN (10, 11, 12)"))

        # 2. 将24号测试用例的正向测试数据集合并到10号用例
        print("  2. 合并正向测试用例到用例10...")
        merge_positive = """
        INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, jira_id, tags, is_active)
        SELECT
            10 as case_id,
            data_set_name,
            jsonb_build_object(
                'instrument', variables->>'instrument',
                'timeframe', variables->>'timeframe',
                'count', (variables->>'count')::int
            ) as variables,
            validations_override,
            environments,
            NULL as jira_id,
            ARRAY['positive', 'candlestick'] ||
            CASE
                WHEN 'smoke' = ANY(tags) THEN ARRAY['smoke']
                WHEN 'core' = ANY(tags) THEN ARRAY['core']
                ELSE ARRAY['regression']
            END as tags,
            is_active
        FROM case_data_sets
        WHERE case_id = 24
            AND ('orthogonal' = ANY(tags) OR 'supplementary' = ANY(tags))
        """
        session.execute(text(merge_positive))

        # 3. 将24号测试用例的负向测试数据集合并到11号用例
        print("  3. 合并负向测试用例到用例11...")
        merge_negative = """
        INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, jira_id, tags, is_active)
        SELECT
            11 as case_id,
            data_set_name,
            CASE
                WHEN variables->>'instrument' IS NULL THEN
                    jsonb_build_object(
                        'timeframe', variables->>'timeframe',
                        'count', (variables->>'count')::int,
                        'expected_status', (variables->>'expected_status')::int
                    )
                WHEN variables->>'timeframe' IS NULL THEN
                    jsonb_build_object(
                        'instrument', variables->>'instrument',
                        'count', (variables->>'count')::int,
                        'expected_status', (variables->>'expected_status')::int
                    )
                ELSE
                    jsonb_build_object(
                        'instrument', variables->>'instrument',
                        'timeframe', variables->>'timeframe',
                        'count', (variables->>'count')::int,
                        'expected_status', (variables->>'expected_status')::int
                    )
            END as variables,
            validations_override,
            environments,
            NULL as jira_id,
            ARRAY['negative', 'candlestick', 'error_handling'] as tags,
            is_active
        FROM case_data_sets
        WHERE case_id = 24
            AND 'negative' = ANY(tags)
        """
        session.execute(text(merge_negative))

        # 4. 添加边界值测试到12号用例
        print("  4. 添加边界值测试到用例12...")
        boundary_tests = [
            ("Minimum timeframe - 1m", {"instrument": "BTC_USD", "timeframe": "1m", "count": 100},
             ["edge_case", "boundary", "candlestick"]),
            ("Maximum timeframe - 1M", {"instrument": "ETH_USD", "timeframe": "1M", "count": 50},
             ["edge_case", "boundary", "candlestick"]),
            ("Minimum count - 1", {"instrument": "BTC_USD", "timeframe": "1D", "count": 1},
             ["edge_case", "boundary", "candlestick"]),
            ("Maximum count - 5000", {"instrument": "ETH_USD", "timeframe": "1m", "count": 5000},
             ["edge_case", "boundary", "candlestick", "performance"]),
            ("Case sensitive - lowercase", {"instrument": "btc_usd", "timeframe": "1h", "count": 10},
             ["edge_case", "validation", "candlestick"]),
            ("Different pair - BTC_USDT", {"instrument": "BTC_USDT", "timeframe": "4h", "count": 200},
             ["edge_case", "candlestick"])
        ]

        for name, variables, tags in boundary_tests:
            # 直接使用值构造SQL，避免复杂的参数绑定
            vars_json = json.dumps(variables).replace("'", "''")
            tags_str = '{' + ','.join(tags) + '}'
            insert_boundary = f"""
            INSERT INTO case_data_sets (case_id, data_set_name, variables, environments, tags, is_active)
            VALUES (12, '{name}', '{vars_json}'::jsonb, '{{uat}}', '{tags_str}', true)
            """
            session.execute(text(insert_boundary))

        # 5. 更新用例名称和标签
        print("  5. 更新用例名称和标签...")
        updates = [
            (10, "Get Candlestick - Positive Tests", ["p1", "smoke", "market_data", "candlestick"]),
            (11, "Get Candlestick - Negative Tests", ["p1", "negative", "market_data", "candlestick"]),
            (12, "Get Candlestick - Edge Cases", ["p2", "edge_case", "market_data", "candlestick"])
        ]

        for case_id, name, tags in updates:
            update_case = """
            UPDATE api_auto_cases
            SET name = :name, tags = :tags
            WHERE id = :case_id
            """
            session.execute(text(update_case), {
                "name": name,
                "tags": tags,
                "case_id": case_id
            })

        # 6. 删除24号测试用例
        print("  6. 删除原24号测试用例...")
        # 先删除数据集，再删除测试用例
        session.execute(text("DELETE FROM case_data_sets WHERE case_id = 24"))
        session.execute(text("DELETE FROM api_auto_cases WHERE id = 24"))

        # 7. 统计合并后的数据
        print("\n合并后的统计信息:")
        stat_query = """
        SELECT
            c.id,
            c.name,
            COUNT(d.id) as dataset_count
        FROM api_auto_cases c
        LEFT JOIN case_data_sets d ON c.id = d.case_id
        WHERE c.id IN (10, 11, 12)
        GROUP BY c.id, c.name
        ORDER BY c.id
        """

        result = session.execute(text(stat_query))
        for row in result:
            print(f"  用例 {row[0]}: {row[1]} - {row[2]} 个数据集")

        # 提交事务
        session.commit()
        print("\n✅ 测试用例合并成功!")

        # 查看合并后的部分数据集
        print("\n合并后的部分数据集示例:")
        sample_query = """
        SELECT c.id, d.data_set_name, d.variables::text, d.tags
        FROM api_auto_cases c
        JOIN case_data_sets d ON c.id = d.case_id
        WHERE c.id IN (10, 11, 12)
        ORDER BY c.id, d.id
        LIMIT 6
        """

        result = session.execute(text(sample_query))
        for row in result:
            vars_dict = json.loads(row[2])
            print(f"  用例{row[0]}: {row[1]}")
            print(f"    Variables: {list(vars_dict.keys())}")
            print(f"    Tags: {row[3]}")

    except Exception as e:
        session.rollback()
        print(f"❌ 合并失败: {e}")
        import traceback
        traceback.print_exc()
    finally:
        session.close()

if __name__ == "__main__":
    merge_candlestick_cases()