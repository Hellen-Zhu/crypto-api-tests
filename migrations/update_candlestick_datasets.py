#!/usr/bin/env python
"""
Update data sets for candlestick test cases to add missing variables.
This script adds instrument and timeframe variables to all candlestick test data sets.
"""

import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from core.db_handler import get_db_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text
import json
from core.logger_config import logger


def update_case_10_datasets():
    """
    Update Case 10 data sets with proper instrument and timeframe variables.
    Based on the data set names, extract the correct parameters.
    """
    updates = [
        {
            "id": 7,
            "name": "Valid request - ETH_USD D1",
            "variables": {
                "instrument": "ETH_USD",
                "timeframe": "D1"
            }
        },
        {
            "id": 8,
            "name": "Valid request - BTC_USD H1",
            "variables": {
                "instrument": "BTC_USD",
                "timeframe": "H1"
            }
        },
        {
            "id": 9,
            "name": "Valid request - ETH_USD M5",
            "variables": {
                "instrument": "ETH_USD",
                "timeframe": "M5"
            }
        }
    ]
    return updates


def update_case_11_datasets():
    """
    Update Case 11 data sets - these already have variables but might need adjustment.
    """
    # Case 11 already has the variables set, just verify they match our parameter names
    return []  # No updates needed, they already use 'instrument' and 'timeframe'


def update_case_12_datasets():
    """
    Update Case 12 data sets with proper instrument and timeframe variables.
    """
    updates = [
        {
            "id": 15,
            "name": "Minimum timeframe - M1",
            "variables": {
                "instrument": "BTC_USD",
                "timeframe": "M1"
            }
        },
        {
            "id": 16,
            "name": "Long timeframe - W1",
            "variables": {
                "instrument": "ETH_USD",
                "timeframe": "W1"
            }
        },
        {
            "id": 17,
            "name": "Case sensitivity - lowercase instrument",
            "variables": {
                "instrument": "btc_usd",
                "timeframe": "H1"
            }
        }
    ]
    return updates


def main():
    """Main update function."""
    logger.info("Starting update of candlestick data set variables...")

    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        all_updates = []
        all_updates.extend(update_case_10_datasets())
        all_updates.extend(update_case_11_datasets())
        all_updates.extend(update_case_12_datasets())

        if not all_updates:
            logger.info("No updates needed for case 11")

        for update in all_updates:
            dataset_id = update["id"]
            variables = update["variables"]
            name = update["name"]

            logger.info(f"Updating DataSet {dataset_id}: {name}")
            logger.info(f"  Variables: {json.dumps(variables, indent=4)}")

            session.execute(
                text("""
                    UPDATE case_data_sets
                    SET variables = :vars
                    WHERE id = :dataset_id
                """),
                {"vars": json.dumps(variables), "dataset_id": dataset_id}
            )

            logger.info(f"  ✓ DataSet {dataset_id} updated successfully")

        # Commit all changes
        session.commit()
        logger.info(f"\n✅ All {len(all_updates)} data set updates completed successfully!")

        # Verify the updates
        logger.info("\nVerifying updates...")
        result = session.execute(text("""
            SELECT cds.id, cds.data_set_name, cds.variables, cds.case_id
            FROM case_data_sets cds
            WHERE cds.case_id IN (10, 11, 12)
            ORDER BY cds.case_id, cds.id
        """)).fetchall()

        logger.info("\nData Set Verification:")
        current_case = None
        for row in result:
            if current_case != row[3]:
                current_case = row[3]
                logger.info(f"\nCase {row[3]}:")
            logger.info(f"  DataSet {row[0]}: {row[1]}")
            logger.info(f"    Variables: {json.dumps(row[2], indent=6)}")

        logger.info("\n✅ Verification complete!")

    except Exception as e:
        session.rollback()
        logger.error(f"❌ Update failed: {e}")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    main()
