#!/usr/bin/env python3
"""
Migration script to convert existing UTC timestamps to local timezone (Asia/Shanghai)

This script will:
1. Set the PostgreSQL session timezone to Asia/Shanghai
2. Update all timestamp columns in all tables to display in local time
3. Future inserts/updates will automatically use local time due to handler.py configuration

Note: PostgreSQL TIMESTAMP WITH TIME ZONE stores times in UTC internally
but displays them according to the session timezone setting.
"""

import os
import sys
from datetime import datetime
from sqlalchemy import text, inspect

# Add project root to Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.database.handler import get_db_engine
from src.common.logger import logger


def convert_timestamps_to_local():
    """
    Convert all existing timestamps to local timezone by setting PostgreSQL session timezone.

    Note: TIMESTAMP WITH TIME ZONE columns store UTC internally but display according
    to the session timezone. We're setting the default timezone so all new connections
    use local time.
    """
    engine = get_db_engine()

    with engine.connect() as conn:
        try:
            logger.info("=" * 80)
            logger.info("Starting timestamp timezone migration")
            logger.info("=" * 80)

            # Check current timezone setting
            result = conn.execute(text("SHOW timezone"))
            current_tz = result.scalar()
            logger.info(f"Current PostgreSQL timezone: {current_tz}")

            # Check if we need to update database default timezone
            if current_tz != 'Asia/Shanghai':
                logger.info(f"\nUpdating PostgreSQL database default timezone to Asia/Shanghai...")

                # Option 1: Set for current session (already done via handler.py)
                conn.execute(text("SET timezone = 'Asia/Shanghai'"))
                logger.info("✓ Session timezone set to Asia/Shanghai")

                # Option 2: Update postgresql.conf or set at database level (requires superuser)
                # This is optional and requires database admin privileges
                try:
                    conn.execute(text("ALTER DATABASE postgres SET timezone = 'Asia/Shanghai'"))
                    logger.info("✓ Database default timezone updated to Asia/Shanghai")
                except Exception as e:
                    logger.warning(f"⚠ Could not set database default timezone (requires superuser): {e}")
                    logger.warning("  This is okay - handler.py will set timezone for each connection")

                conn.commit()
            else:
                logger.info("✓ Database is already configured to use Asia/Shanghai timezone")

            # Verify the change
            result = conn.execute(text("SHOW timezone"))
            new_tz = result.scalar()
            logger.info(f"\nVerified PostgreSQL timezone: {new_tz}")

            # Get all tables with timestamp columns
            inspector = inspect(engine)
            tables_with_timestamps = []

            for table_name in inspector.get_table_names():
                columns = inspector.get_columns(table_name)
                timestamp_cols = [
                    col['name'] for col in columns
                    if 'timestamp' in str(col['type']).lower() or col['name'] in ['created_at', 'updated_at', 'begin_time', 'end_time']
                ]
                if timestamp_cols:
                    tables_with_timestamps.append((table_name, timestamp_cols))

            logger.info(f"\nFound {len(tables_with_timestamps)} tables with timestamp columns:")
            for table_name, cols in tables_with_timestamps:
                logger.info(f"  - {table_name}: {', '.join(cols)}")

            # Sample current timestamps from each table
            logger.info("\n" + "=" * 80)
            logger.info("Sample timestamp values (now displayed in Asia/Shanghai timezone):")
            logger.info("=" * 80)

            for table_name, timestamp_cols in tables_with_timestamps:
                try:
                    sample_query = text(f"SELECT {', '.join(timestamp_cols)} FROM {table_name} LIMIT 1")
                    result = conn.execute(sample_query)
                    row = result.fetchone()

                    if row:
                        logger.info(f"\n{table_name}:")
                        for col_name, value in zip(timestamp_cols, row):
                            logger.info(f"  {col_name}: {value}")
                    else:
                        logger.info(f"\n{table_name}: (no data)")

                except Exception as e:
                    logger.warning(f"  Could not query {table_name}: {e}")

            logger.info("\n" + "=" * 80)
            logger.info("Migration Summary:")
            logger.info("=" * 80)
            logger.info("✓ PostgreSQL session timezone configured to Asia/Shanghai")
            logger.info("✓ All existing timestamps will now display in local time")
            logger.info("✓ New records will automatically use local time (via handler.py)")
            logger.info("✓ No data modification needed - timestamps stored as UTC internally")
            logger.info("\nNote: TIMESTAMP WITH TIME ZONE columns store UTC internally")
            logger.info("but display according to session timezone setting.")
            logger.info("=" * 80)

        except Exception as e:
            logger.error(f"\n❌ Migration failed: {e}")
            import traceback
            traceback.print_exc()
            return False

    return True


def verify_timezone_configuration():
    """
    Verify that timezone configuration is working correctly for new connections.
    """
    logger.info("\n" + "=" * 80)
    logger.info("Verifying timezone configuration for new connections")
    logger.info("=" * 80)

    # Create a new engine/connection to test
    engine = get_db_engine()

    with engine.connect() as conn:
        # Check timezone
        result = conn.execute(text("SHOW timezone"))
        tz = result.scalar()
        logger.info(f"New connection timezone: {tz}")

        # Test current timestamp
        result = conn.execute(text("SELECT CURRENT_TIMESTAMP as now, NOW() at time zone 'UTC' as utc_now"))
        row = result.fetchone()
        logger.info(f"Current timestamp (local): {row[0]}")
        logger.info(f"Current timestamp (UTC):   {row[1]}")

        if tz == 'Asia/Shanghai' or tz == 'PRC':
            logger.info("\n✅ Timezone configuration verified successfully!")
            return True
        else:
            logger.error(f"\n❌ Timezone configuration failed. Expected 'Asia/Shanghai' or 'PRC', got '{tz}'")
            return False


if __name__ == '__main__':
    print("\n" + "=" * 80)
    print("PostgreSQL Timestamp Timezone Migration")
    print("=" * 80)
    print("\nThis script will configure PostgreSQL to use local timezone (Asia/Shanghai)")
    print("for all timestamp columns. This affects how timestamps are displayed,")
    print("not how they are stored (always UTC internally).")
    print("\n" + "=" * 80 + "\n")

    success = convert_timestamps_to_local()

    if success:
        verify_success = verify_timezone_configuration()
        sys.exit(0 if verify_success else 1)
    else:
        sys.exit(1)
