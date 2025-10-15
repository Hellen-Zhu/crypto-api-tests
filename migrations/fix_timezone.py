"""
Migration script to fix timezone for timestamp columns
This script updates all timestamp columns to use China timezone (UTC+8)
"""

import sys
import os

# Add project root to Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from sqlalchemy import text
from src.database.handler import get_db_engine
from src.common.logger import logger


def fix_timezone():
    """Update all timestamp column defaults to use China timezone"""

    # Get database engine
    engine = get_db_engine()

    # SQL statements to update column defaults
    sql_statements = [
        # api_auto_cases table
        """
        ALTER TABLE api_auto_cases
        ALTER COLUMN created_at SET DEFAULT (NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Shanghai'),
        ALTER COLUMN updated_at SET DEFAULT (NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Shanghai');
        """,

        # auto_progress table
        """
        ALTER TABLE auto_progress
        ALTER COLUMN created_at SET DEFAULT (NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Shanghai'),
        ALTER COLUMN updated_at SET DEFAULT (NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Shanghai');
        """,

        # auto_case_audit table
        """
        ALTER TABLE auto_case_audit
        ALTER COLUMN created_at SET DEFAULT (NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Shanghai'),
        ALTER COLUMN updated_at SET DEFAULT (NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Shanghai');
        """,

        # auto_test_audit table
        """
        ALTER TABLE auto_test_audit
        ALTER COLUMN created_at SET DEFAULT (NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Shanghai'),
        ALTER COLUMN updated_at SET DEFAULT (NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Shanghai');
        """
    ]

    try:
        with engine.connect() as conn:
            for sql in sql_statements:
                logger.info(f"Executing: {sql.strip()[:100]}...")
                conn.execute(text(sql))
                conn.commit()

        logger.info("✓ Successfully updated all timestamp column defaults to China timezone (UTC+8)")
        return True

    except Exception as e:
        logger.error(f"✗ Failed to update timezone defaults: {e}")
        return False
    finally:
        engine.dispose()


if __name__ == "__main__":
    print("\n" + "="*60)
    print("Timezone Migration Script")
    print("="*60)
    print("\nThis script will update all timestamp columns to use")
    print("China timezone (UTC+8) as the default value.\n")

    response = input("Do you want to proceed? (yes/no): ").strip().lower()

    if response == 'yes':
        success = fix_timezone()
        if success:
            print("\n✓ Migration completed successfully!")
        else:
            print("\n✗ Migration failed. Check logs for details.")
            sys.exit(1)
    else:
        print("\nMigration cancelled.")
        sys.exit(0)
