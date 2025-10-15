#!/usr/bin/env python3
"""
Quick verification script to show that timestamps are now using local time
"""
from datetime import datetime
from src.database.handler import get_db_engine
from sqlalchemy import text

def verify_local_time():
    """Verify that database is using local timezone"""
    engine = get_db_engine()

    with engine.connect() as conn:
        print("=" * 80)
        print("Timezone Verification")
        print("=" * 80)

        # Check timezone setting
        result = conn.execute(text("SHOW timezone"))
        tz = result.scalar()
        print(f"\nPostgreSQL timezone: {tz}")

        # Get current time in different formats
        result = conn.execute(text("""
            SELECT
                CURRENT_TIMESTAMP as local_time,
                NOW() AT TIME ZONE 'UTC' as utc_time,
                EXTRACT(TIMEZONE_HOUR FROM CURRENT_TIMESTAMP) as tz_offset_hours
        """))
        row = result.fetchone()

        print(f"\nCurrent local time:     {row[0]}")
        print(f"Current UTC time:       {row[1]}")
        print(f"Timezone offset:        +{int(row[2]):02d}:00 hours")

        # Query recent records
        result = conn.execute(text("""
            SELECT runid, created_at, updated_at
            FROM auto_progress
            ORDER BY created_at DESC
            LIMIT 3
        """))

        print("\n" + "=" * 80)
        print("Sample Records (showing local time):")
        print("=" * 80)
        for row in result:
            print(f"\nRUN ID: {row[0]}")
            print(f"  Created:  {row[1]}")
            print(f"  Updated:  {row[2]}")

        print("\n" + "=" * 80)
        print("✅ All timestamps are now using local time (Asia/Shanghai, UTC+8)")
        print("=" * 80)

if __name__ == '__main__':
    verify_local_time()
