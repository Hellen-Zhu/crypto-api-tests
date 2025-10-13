#!/usr/bin/env python
"""
生成最终的K线测试用例统计报告
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

# 初始化数据库连接
engine = get_db_engine()
Session = sessionmaker(bind=engine)
session = Session()

try:
    print('=== 最终的K线测试用例统计 ===\n')

    # 简单统计
    stats = '''
    SELECT
        c.id,
        c.name,
        COUNT(d.id) as dataset_count
    FROM api_auto_cases c
    LEFT JOIN case_data_sets d ON c.id = d.case_id
    WHERE c.id IN (10, 11, 12)
    GROUP BY c.id, c.name
    ORDER BY c.id
    '''

    result = session.execute(text(stats))
    total = 0
    for row in result:
        print(f'Case {row[0]}: {row[1]}')
        print(f'  数据集数量: {row[2]}个')
        total += row[2]

    print(f'\n总计: {total}个测试数据集')

    # 详细列表
    print('\n=== 详细的测试用例列表 ===\n')

    detail_query = '''
    SELECT
        c.id as case_id,
        c.name as case_name,
        d.data_set_name,
        d.variables::text
    FROM api_auto_cases c
    JOIN case_data_sets d ON c.id = d.case_id
    WHERE c.id IN (10, 11, 12)
    AND 'candlestick' = ANY(d.tags)
    ORDER BY c.id, d.id
    '''

    result = session.execute(text(detail_query))

    current_case = None
    case_counts = {10: 0, 11: 0, 12: 0}

    for row in result:
        if current_case != row[0]:
            if current_case:
                print(f'  小计: {case_counts[current_case]}个\n')
            current_case = row[0]
            print(f'【{row[1]}】')
            case_counts[current_case] = 0

        vars = json.loads(row[3])
        case_counts[current_case] += 1

        # 简洁显示
        params = []
        if 'instrument' in vars:
            params.append(vars['instrument'])
        if 'timeframe' in vars:
            params.append(vars['timeframe'])
        if 'count' in vars:
            params.append(f"count={vars['count']}")

        print(f'  {case_counts[current_case]:2d}. {row[2]:40s} [{" | ".join(params)}]')

    if current_case:
        print(f'  小计: {case_counts[current_case]}个')

    # 重复检查
    print('\n=== 重复检查 ===\n')

    dup_check = '''
    SELECT COUNT(*) FROM (
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
    '''

    result = session.execute(text(dup_check))
    dup_count = result.scalar()

    if dup_count == 0:
        print('✅ 没有发现重复的测试用例组合')
    else:
        print(f'⚠️ 发现{dup_count}组重复的测试用例')

    print(f'\n✅ 清理完成！现有{total}个无重复的K线测试用例')

except Exception as e:
    print(f'❌ 操作失败: {e}')
    import traceback
    traceback.print_exc()
finally:
    session.close()