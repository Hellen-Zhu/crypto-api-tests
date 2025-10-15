"""
Verify that timezone fix is working correctly
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy import text
from src.database.handler import get_db_engine
from src.common.logger import logger
import datetime

def verify_timezone():
    """Verify timezone settings and data"""

    engine = get_db_engine()

    with engine.connect() as conn:
        # Check PostgreSQL timezone setting
        result = conn.execute(text("SHOW TIMEZONE;"))
        pg_tz = result.scalar()
        print(f"\nPostgreSQL TIMEZONE setting: {pg_tz}")

        # Check current time in different formats
        result = conn.execute(text("SELECT NOW(), NOW() AT TIME ZONE 'Asia/Shanghai';"))
        now_utc, now_shanghai = result.one()
        print(f"\nCurrent time comparison:")
        print(f"  NOW() (session timezone):           {now_utc}")
        print(f"  NOW() AT TIME ZONE 'Asia/Shanghai': {now_shanghai}")

        # Check column defaults
        result = conn.execute(text("""
            SELECT
                table_name,
                column_name,
                column_default
            FROM information_schema.columns
            WHERE table_name IN ('auto_progress', 'auto_case_audit', 'auto_test_audit', 'api_auto_cases')
                AND column_name IN ('created_at', 'updated_at')
            ORDER BY table_name, column_name;
        """))

        print(f"\n{'='*80}")
        print("Column Defaults:")
        print(f"{'='*80}")
        for row in result:
            print(f"{row.table_name:20} {row.column_name:15} {row.column_default}")

        # Get latest records from auto_progress
        result = conn.execute(text("""
            SELECT
                runid,
                created_at,
                updated_at,
                created_at AT TIME ZONE 'Asia/Shanghai' as created_local,
                updated_at AT TIME ZONE 'Asia/Shanghai' as updated_local
            FROM auto_progress
            ORDER BY created_at DESC
            LIMIT 3;
        """))

        print(f"\n{'='*80}")
        print("Latest Records (comparing UTC vs Local):")
        print(f"{'='*80}")

        for row in result:
            print(f"\nRUN ID: {row.runid}")
            print(f"  Created (stored):  {row.created_at}")
            print(f"  Created (local):   {row.created_local}")
            print(f"  Updated (stored):  {row.updated_at}")
            print(f"  Updated (local):   {row.updated_local}")

            # Check if timezone is correct
            if row.created_at.tzinfo is not None:
                print(f"  ✓ Timezone aware: {row.created_at.tzinfo}")
            else:
                print(f"  ✗ Timezone naive")

    print(f"\n{'='*80}")
    print("Verification complete!")
    print(f"{'='*80}\n")


if __name__ == "__main__":
    verify_timezone()
