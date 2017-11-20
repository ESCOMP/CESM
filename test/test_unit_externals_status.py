#!/usr/bin/env python

"""Unit test driver for the manic external status reporting module.

Note: this script assumes the path to the manic package is already in
the python path.

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import unittest

from manic.externals_status import ExternalStatus


class TestStatusObject(unittest.TestCase):
    """Verify that the Status object behaives as expected.
    """

    def test_exists_empty_all(self):
        """If the repository sync-state is empty (doesn't exist), and there is no
        clean state, then it is considered not to exist.

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.EMPTY
        stat.clean_state = ExternalStatus.DEFAULT
        exists = stat.exists()
        self.assertFalse(exists)

        stat.clean_state = ExternalStatus.EMPTY
        exists = stat.exists()
        self.assertFalse(exists)

        stat.clean_state = ExternalStatus.UNKNOWN
        exists = stat.exists()
        self.assertFalse(exists)

        # this state represtens an internal logic error in how the
        # repo status was determined.
        stat.clean_state = ExternalStatus.STATUS_OK
        exists = stat.exists()
        self.assertTrue(exists)

        # this state represtens an internal logic error in how the
        # repo status was determined.
        stat.clean_state = ExternalStatus.DIRTY
        exists = stat.exists()
        self.assertTrue(exists)

    def test_exists_default_all(self):
        """If the repository sync-state is default, then it is considered to exist
        regardless of clean state.

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.DEFAULT
        stat.clean_state = ExternalStatus.DEFAULT
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.EMPTY
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.UNKNOWN
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.STATUS_OK
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.DIRTY
        exists = stat.exists()
        self.assertTrue(exists)

    def test_exists_unknown_all(self):
        """If the repository sync-state is unknown, then it is considered to exist
        regardless of clean state.

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.UNKNOWN
        stat.clean_state = ExternalStatus.DEFAULT
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.EMPTY
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.UNKNOWN
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.STATUS_OK
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.DIRTY
        exists = stat.exists()
        self.assertTrue(exists)

    def test_exists_modified_all(self):
        """If the repository sync-state is modified, then it is considered to exist
        regardless of clean state.

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.MODEL_MODIFIED
        stat.clean_state = ExternalStatus.DEFAULT
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.EMPTY
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.UNKNOWN
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.STATUS_OK
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.DIRTY
        exists = stat.exists()
        self.assertTrue(exists)

    def test_exists_ok_all(self):
        """If the repository sync-state is ok, then it is considered to exist
        regardless of clean state.

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.STATUS_OK
        stat.clean_state = ExternalStatus.DEFAULT
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.EMPTY
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.UNKNOWN
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.STATUS_OK
        exists = stat.exists()
        self.assertTrue(exists)

        stat.clean_state = ExternalStatus.DIRTY
        exists = stat.exists()
        self.assertTrue(exists)

    def test_update_ok_all(self):
        """If the repository in-sync is ok, then it is safe to
        update only if clean state is ok

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.STATUS_OK
        stat.clean_state = ExternalStatus.DEFAULT
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.EMPTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.UNKNOWN
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.STATUS_OK
        safe_to_update = stat.safe_to_update()
        self.assertTrue(safe_to_update)

        stat.clean_state = ExternalStatus.DIRTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

    def test_update_modified_all(self):
        """If the repository in-sync is modified, then it is safe to
        update only if clean state is ok

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.MODEL_MODIFIED
        stat.clean_state = ExternalStatus.DEFAULT
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.EMPTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.UNKNOWN
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.STATUS_OK
        safe_to_update = stat.safe_to_update()
        self.assertTrue(safe_to_update)

        stat.clean_state = ExternalStatus.DIRTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

    def test_update_unknown_all(self):
        """If the repository in-sync is unknown, then it is not safe to
        update, regardless of the clean state.

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.UNKNOWN
        stat.clean_state = ExternalStatus.DEFAULT
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.EMPTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.UNKNOWN
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.STATUS_OK
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.DIRTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

    def test_update_default_all(self):
        """If the repository in-sync is default, then it is not safe to
        update, regardless of the clean state.

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.UNKNOWN
        stat.clean_state = ExternalStatus.DEFAULT
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.EMPTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.UNKNOWN
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.STATUS_OK
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.DIRTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

    def test_update_empty_all(self):
        """If the repository in-sync is empty, then it is not safe to
        update, regardless of the clean state.

        """
        stat = ExternalStatus()
        stat.sync_state = ExternalStatus.UNKNOWN
        stat.clean_state = ExternalStatus.DEFAULT
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.EMPTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.UNKNOWN
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.STATUS_OK
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)

        stat.clean_state = ExternalStatus.DIRTY
        safe_to_update = stat.safe_to_update()
        self.assertFalse(safe_to_update)


if __name__ == '__main__':
    unittest.main()
