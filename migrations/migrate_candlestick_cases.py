#!/usr/bin/env python
"""
Migration script to convert test cases 10, 11, 12 to 2-table design.
Migrates candlestick test cases from api_actions table to parameters JSONB column.
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


def migrate_case_10():
    """
    Migrate Case 10: Get Candlestick Data
    This case has a single step in api_actions table.
    """
    parameters = {
        "steps": [
            {
                "order": 1,
                "description": "Get candlestick data from exchange API",
                "path": "/exchange/v1/public/get-candlestick",
                "method": "GET",
                "request": {
                    "params": {
                        "instrument_name": "{{@instrument}}",
                        "timeframe": "{{@timeframe}}"
                    },
                    "headers": {
                        "Content-Type": "application/json"
                    },
                    "body": None
                },
                "validations": {
                    "expectedStatusCode": 200,
                    "notNull": [
                        "$.code",
                        "$.result",
                        "$.result.data",
                        "$.result.instrument_name",
                        "$.result.interval"
                    ],
                    "body": {
                        "code": 0,
                        "method": "public/get-candlestick",
                        "result": {
                            "instrument_name": "{{@instrument}}",
                            "interval": "{{@timeframe}}"
                        }
                    }
                },
                "outputs": [
                    {
                        "variable_name": "data_count",
                        "source": "response_body",
                        "json_path": "result.data"
                    },
                    {
                        "variable_name": "first_candle",
                        "source": "response_body",
                        "json_path": "result.data[0]"
                    }
                ]
            }
        ]
    }
    return parameters


def migrate_case_11():
    """
    Migrate Case 11: Get Candlestick Data - Negative Tests
    This case tests error conditions with invalid/missing parameters.
    """
    parameters = {
        "steps": [
            {
                "order": 1,
                "description": "Get candlestick data with invalid/missing parameters",
                "path": "/exchange/v1/public/get-candlestick",
                "method": "GET",
                "request": {
                    "params": {
                        "instrument_name": "{{@instrument}}",
                        "timeframe": "{{@timeframe}}"
                    },
                    "headers": {
                        "Content-Type": "application/json"
                    },
                    "body": None
                },
                "validations": {
                    "expectedStatusCode": 400,
                    "notNull": ["$.code"]
                },
                "outputs": None
            }
        ]
    }
    return parameters


def migrate_case_12():
    """
    Migrate Case 12: Get Candlestick Data - Edge Cases
    This case tests edge cases like minimum timeframe, long timeframe, etc.
    """
    parameters = {
        "steps": [
            {
                "order": 1,
                "description": "Get candlestick data - edge case scenarios",
                "path": "/exchange/v1/public/get-candlestick",
                "method": "GET",
                "request": {
                    "params": {
                        "instrument_name": "{{@instrument}}",
                        "timeframe": "{{@timeframe}}"
                    },
                    "headers": {
                        "Content-Type": "application/json"
                    },
                    "body": None
                },
                "validations": {
                    "expectedStatusCode": 200,
                    "notNull": [
                        "$.code",
                        "$.result"
                    ]
                },
                "outputs": None
            }
        ]
    }
    return parameters


def main():
    """Main migration function."""
    logger.info("Starting migration of candlestick test cases to 2-table design...")

    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        # Migration map
        migrations = {
            10: migrate_case_10(),
            11: migrate_case_11(),
            12: migrate_case_12()
        }

        for case_id, parameters in migrations.items():
            logger.info(f"Migrating case {case_id}...")

            # Update the parameters column
            session.execute(
                text("""
                    UPDATE api_auto_cases
                    SET parameters = :params
                    WHERE id = :case_id
                """),
                {"params": json.dumps(parameters), "case_id": case_id}
            )

            logger.info(f"  ✓ Case {case_id} migrated successfully with {len(parameters['steps'])} step(s)")

        # Commit all changes
        session.commit()
        logger.info("✅ All migrations completed successfully!")

        # Verify the migration
        logger.info("\nVerifying migration...")
        result = session.execute(text("""
            SELECT id, name,
                   CASE WHEN parameters IS NULL THEN 'NULL'
                        WHEN parameters = 'null'::jsonb THEN 'null'
                        ELSE 'HAS_DATA' END as params_status,
                   jsonb_array_length(parameters->'steps') as step_count
            FROM api_auto_cases
            WHERE id IN (10, 11, 12)
            ORDER BY id
        """)).fetchall()

        logger.info("\nMigration verification:")
        for row in result:
            logger.info(f"  Case {row[0]}: {row[1]}")
            logger.info(f"    Parameters: {row[2]}, Steps: {row[3]}")

        logger.info("\n✅ Migration verification complete!")

    except Exception as e:
        session.rollback()
        logger.error(f"❌ Migration failed: {e}")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    main()
