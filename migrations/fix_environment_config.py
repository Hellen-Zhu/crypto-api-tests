#!/usr/bin/env python
"""
Fix environment configuration:
1. Delete exchange environment
2. Update UAT base_url to https://uat-api.3ona.co
3. Update candlestick data sets to use UAT environment
"""

import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from core.db_handler import get_db_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text
from core.logger_config import logger


def main():
    """Fix environment configuration."""
    logger.info("Fixing environment configuration...")

    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        # 1. Delete exchange environment
        logger.info("Step 1: Deleting exchange environment...")
        session.execute(text("""
            DELETE FROM test_environments
            WHERE name = 'exchange'
        """))
        logger.info("  ✓ Exchange environment deleted")

        # 2. Update UAT base_url
        logger.info("\nStep 2: Updating UAT base_url...")
        session.execute(text("""
            UPDATE test_environments
            SET base_url = 'https://uat-api.3ona.co'
            WHERE name = 'uat'
        """))
        logger.info("  ✓ UAT base_url updated to: https://uat-api.3ona.co")

        # 3. Update candlestick data sets to use UAT environment
        logger.info("\nStep 3: Updating candlestick data sets to use UAT environment...")
        session.execute(text("""
            UPDATE case_data_sets
            SET environments = ARRAY['uat', 'dev']
            WHERE case_id IN (10, 11, 12)
        """))
        logger.info("  ✓ Candlestick data sets now configured for UAT and DEV environments")

        # Commit all changes
        session.commit()
        logger.info("\n✅ All configuration changes committed successfully!")

        # Verify changes
        logger.info("\nVerifying changes...")

        # Check environments
        result = session.execute(text("""
            SELECT id, name, base_url, is_active
            FROM test_environments
            ORDER BY id
        """)).fetchall()

        logger.info("\nTest Environments:")
        for row in result:
            active = '✓' if row[3] else '✗'
            logger.info(f"  [{active}] ID {row[0]}: {row[1]}")
            logger.info(f"      Base URL: {row[2]}")

        # Check a few data sets
        result2 = session.execute(text("""
            SELECT cds.id, cds.data_set_name, cds.environments, ac.name as case_name
            FROM case_data_sets cds
            JOIN api_auto_cases ac ON ac.id = cds.case_id
            WHERE cds.case_id IN (10, 11, 12)
            ORDER BY cds.case_id, cds.id
            LIMIT 3
        """)).fetchall()

        logger.info("\nSample Candlestick Data Sets (showing first 3):")
        for row in result2:
            logger.info(f"  DataSet {row[0]}: {row[1]}")
            logger.info(f"    Environments: {row[2]}")
            logger.info(f"    Case: {row[3]}")

        logger.info("\n✅ Configuration verification complete!")
        logger.info("\nYou can now run all tests with:")
        logger.info("    python run.py")

    except Exception as e:
        session.rollback()
        logger.error(f"❌ Configuration fix failed: {e}")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    main()
