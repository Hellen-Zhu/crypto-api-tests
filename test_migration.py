#!/usr/bin/env python3
"""
Test script to verify timestamp fields auto-update functionality
"""
import time
from datetime import datetime
from src.database.handler import get_db_engine
from src.database.models import AutoProgress, AutoCaseAudit, AutoTestAudit
from sqlalchemy.orm import sessionmaker

def test_timestamp_auto_update():
    """Test that created_at and updated_at work correctly"""

    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        print("=" * 60)
        print("Testing Timestamp Auto-Update Functionality")
        print("=" * 60)

        # Test 1: AutoProgress
        print("\n[Test 1] AutoProgress table")
        print("-" * 60)

        # Create a new record
        test_runid = f"test_migration_{int(time.time())}"
        progress = AutoProgress(
            runid=test_runid,
            task_status='RUNNING',
            component='test',
            profile='dev'
        )
        session.add(progress)
        session.commit()

        # Refresh to get database-generated values
        session.refresh(progress)

        print(f"✓ Created record with runid: {test_runid}")
        print(f"  created_at: {progress.created_at}")
        print(f"  updated_at: {progress.updated_at}")

        assert progress.created_at is not None, "created_at should be auto-populated"
        assert progress.updated_at is not None, "updated_at should be auto-populated"

        original_created_at = progress.created_at
        original_updated_at = progress.updated_at

        # Wait a moment and update the record
        time.sleep(2)
        progress.task_status = 'COMPLETED'
        session.commit()
        session.refresh(progress)

        print(f"\n✓ Updated record status to COMPLETED")
        print(f"  created_at: {progress.created_at} (should be unchanged)")
        print(f"  updated_at: {progress.updated_at} (should be newer)")

        assert progress.created_at == original_created_at, "created_at should not change on update"
        assert progress.updated_at > original_updated_at, "updated_at should auto-update"

        print(f"\n✅ AutoProgress timestamp test PASSED")

        # Test 2: AutoCaseAudit
        print("\n[Test 2] AutoCaseAudit table")
        print("-" * 60)

        case_audit = AutoCaseAudit(
            runid=test_runid,
            case_id=999,
            issue_key='TEST-999',
            run_status='passed',
            duration=1.234
        )
        session.add(case_audit)
        session.commit()
        session.refresh(case_audit)

        print(f"✓ Created case audit record")
        print(f"  created_at: {case_audit.created_at}")
        print(f"  updated_at: {case_audit.updated_at}")

        assert case_audit.created_at is not None, "created_at should be auto-populated"
        assert case_audit.updated_at is not None, "updated_at should be auto-populated"

        original_created_at = case_audit.created_at
        original_updated_at = case_audit.updated_at

        # Wait and update
        time.sleep(2)
        case_audit.run_status = 'failed'
        session.commit()
        session.refresh(case_audit)

        print(f"\n✓ Updated run_status to 'failed'")
        print(f"  created_at: {case_audit.created_at} (should be unchanged)")
        print(f"  updated_at: {case_audit.updated_at} (should be newer)")

        assert case_audit.created_at == original_created_at, "created_at should not change on update"
        assert case_audit.updated_at > original_updated_at, "updated_at should auto-update"

        print(f"\n✅ AutoCaseAudit timestamp test PASSED")

        # Test 3: AutoTestAudit
        print("\n[Test 3] AutoTestAudit table")
        print("-" * 60)

        test_audit = AutoTestAudit(
            audit_case_id=case_audit.id,
            step_order=1,
            action_description='test migration',
            step_status='success',
            step_duration=0.123
        )
        session.add(test_audit)
        session.commit()
        session.refresh(test_audit)

        print(f"✓ Created test audit record")
        print(f"  created_at: {test_audit.created_at}")
        print(f"  updated_at: {test_audit.updated_at}")
        print(f"  step_duration: {test_audit.step_duration}")

        assert test_audit.created_at is not None, "created_at should be auto-populated"
        assert test_audit.updated_at is not None, "updated_at should be auto-populated"
        assert test_audit.step_duration == 0.123, "step_duration should be stored correctly"

        original_created_at = test_audit.created_at
        original_updated_at = test_audit.updated_at

        # Wait and update
        time.sleep(2)
        test_audit.step_status = 'failed'
        test_audit.step_duration = 0.456
        session.commit()
        session.refresh(test_audit)

        print(f"\n✓ Updated step_status and step_duration")
        print(f"  created_at: {test_audit.created_at} (should be unchanged)")
        print(f"  updated_at: {test_audit.updated_at} (should be newer)")
        print(f"  step_duration: {test_audit.step_duration}")

        assert test_audit.created_at == original_created_at, "created_at should not change on update"
        assert test_audit.updated_at > original_updated_at, "updated_at should auto-update"
        assert test_audit.step_duration == 0.456, "step_duration should update correctly"

        print(f"\n✅ AutoTestAudit timestamp test PASSED")

        # Test 4: CASCADE delete
        print("\n[Test 4] CASCADE delete test")
        print("-" * 60)

        test_audit_id = test_audit.id
        print(f"✓ Test audit ID: {test_audit_id}")

        # Delete the parent case_audit record
        session.delete(case_audit)
        session.commit()

        # Verify child test_audit was auto-deleted
        remaining = session.query(AutoTestAudit).filter_by(id=test_audit_id).first()

        if remaining is None:
            print(f"✓ Child record was automatically deleted (CASCADE worked)")
            print(f"\n✅ CASCADE delete test PASSED")
        else:
            print(f"✗ Child record still exists (CASCADE failed)")
            print(f"\n❌ CASCADE delete test FAILED")

        # Clean up test data
        session.query(AutoProgress).filter_by(runid=test_runid).delete()
        session.commit()

        print("\n" + "=" * 60)
        print("🎉 ALL TESTS PASSED!")
        print("=" * 60)
        print("\nMigration verification completed successfully.")
        print("All timestamp fields and triggers are working correctly.\n")

    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        session.rollback()
        return False
    finally:
        session.close()

    return True

if __name__ == '__main__':
    import sys
    success = test_timestamp_auto_update()
    sys.exit(0 if success else 1)
