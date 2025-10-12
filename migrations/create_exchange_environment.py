#!/usr/bin/env python
"""
Create a new test environment for the cryptocurrency exchange API.
This environment should be used for candlestick data tests.
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
    """Create exchange environment."""
    logger.info("Creating cryptocurrency exchange environment...")

    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        # Check if exchange environment already exists
        result = session.execute(text("""
            SELECT id FROM test_environments WHERE name = 'exchange'
        """)).fetchone()

        if result:
            logger.info("Exchange environment already exists, updating it...")
            session.execute(text("""
                UPDATE test_environments
                SET base_url = 'https://api.crypto.com',
                    is_active = true
                WHERE name = 'exchange'
            """))
        else:
            logger.info("Creating new exchange environment...")
            session.execute(text("""
                INSERT INTO test_environments (name, base_url, is_active)
                VALUES ('exchange', 'https://api.crypto.com', true)
            """))

        session.commit()
        logger.info("✅ Exchange environment created/updated successfully!")

        # Show all environments
        result = session.execute(text("""
            SELECT id, name, base_url, is_active
            FROM test_environments
            ORDER BY id
        """)).fetchall()

        logger.info("\nAll Test Environments:")
        for row in result:
            active = '✓' if row[3] else '✗'
            logger.info(f"  [{active}] ID {row[0]}: {row[1]}")
            logger.info(f"      Base URL: {row[2]}")

        logger.info("\n✅ Complete! You can now run candlestick tests with:")
        logger.info("    python run.py --env exchange")

    except Exception as e:
        session.rollback()
        logger.error(f"❌ Failed to create environment: {e}")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    main()
