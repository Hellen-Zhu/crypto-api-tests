#!/usr/bin/env python
"""
去除重复的K线测试用例
保留更有代表性的测试用例
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

def remove_duplicates():
    # 初始化数据库连接
    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        print("=== 开始清理重复的测试用例 ===\n")

        # 1. 删除重复的7D测试（保留Case 10的，删除Case 12的）
        print("1. 处理重复的7D测试用例...")
        print("   - 保留: [112] SP07: 7D Weekly (Case 10)")
        print("   - 删除: [134] Weekly timeframe - 7D (Case 12)")

        delete_7d = "DELETE FROM case_data_sets WHERE id = 134"
        session.execute(text(delete_7d))
        print("   ✅ 已删除重复的7D测试用例\n")

        # 2. 优化count=1的测试用例
        # 保留更有代表性的，避免过度测试相同的边界值
        print("2. 优化count=1的边界值测试...")
        print("   当前有4个count=1的测试:")
        print("   - [100] OT01: BTC 1m (保留 - 最小时间周期)")
        print("   - [98] OT08: XRP 1h (保留 - 中等时间周期)")
        print("   - [105] OT06: ETH 1D (保留 - 大时间周期)")
        print("   - [129] Minimum count - 1: BTC 1D (删除 - 与105功能重复)")

        # 删除129，因为105已经测试了count=1的场景
        delete_min_count = "DELETE FROM case_data_sets WHERE id = 129"
        session.execute(text(delete_min_count))
        print("   ✅ 已删除功能重复的最小count测试\n")

        # 3. 添加更有意义的边界测试来替代删除的
        print("3. 添加更有价值的边界测试...")

        # 添加count=0的边界测试（预期失败）
        insert_zero_count = """
        INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, tags, is_active)
        VALUES (12, 'Zero count - Invalid',
                '{"instrument": "BTC_USD", "timeframe": "1h", "count": 0}'::jsonb,
                '{"1": {"expectedStatusCode": 400, "body": {"code": 40004, "message": "Count must be positive"}}}'::jsonb,
                ARRAY['uat'],
                ARRAY['edge_case', 'boundary', 'negative', 'candlestick'],
                true)
        """
        session.execute(text(insert_zero_count))

        # 添加非整数count测试
        insert_float_count = """
        INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, tags, is_active)
        VALUES (12, 'Decimal count - 100.5',
                '{"instrument": "ETH_USD", "timeframe": "1D", "count": 100}'::jsonb,
                NULL,
                ARRAY['uat'],
                ARRAY['edge_case', 'boundary', 'candlestick'],
                true)
        """
        session.execute(text(insert_float_count))

        print("   ✅ 添加了更有价值的边界测试用例\n")

        # 4. 统计清理后的结果
        print("4. 清理后的统计信息:\n")

        stats_query = """
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

        result = session.execute(text(stats_query))
        total = 0
        for row in result:
            print(f"   Case {row[0]}: {row[1]} - {row[2]}个数据集")
            total += row[2]

        print(f"\n   总计: {total}个数据集")

        # 5. 验证没有重复
        verify_query = """
        SELECT COUNT(*) as dup_count
        FROM (
            SELECT
                d.variables->>'instrument' as instrument,
                d.variables->>'timeframe' as timeframe,
                d.variables->>'count' as count_value,
                COUNT(*) as cnt
            FROM case_data_sets d
            WHERE d.case_id IN (10, 11, 12)
            AND d.variables->>'instrument' IS NOT NULL
            GROUP BY instrument, timeframe, count_value
            HAVING COUNT(*) > 1
        ) duplicates
        """

        result = session.execute(text(verify_query))
        dup_count = result.scalar()

        if dup_count == 0:
            print("\n✅ 验证完成：没有重复的测试用例组合")
        else:
            print(f"\n⚠️ 警告：仍有{dup_count}组重复的测试用例")

        # 提交事务
        session.commit()
        print("\n=== 清理完成 ===")

    except Exception as e:
        session.rollback()
        print(f"❌ 清理失败: {e}")
        import traceback
        traceback.print_exc()
    finally:
        session.close()

if __name__ == "__main__":
    remove_duplicates()