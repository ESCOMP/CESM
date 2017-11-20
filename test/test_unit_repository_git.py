#!/usr/bin/env python

"""Unit test driver for checkout_externals

Note: this script assume the path to the checkout_externals.py module is
already in the python path.

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import os
import shutil
import unittest

from manic.repository_git import GitRepository
from manic.externals_status import ExternalStatus
from manic.externals_description import ExternalsDescription
from manic.externals_description import ExternalsDescriptionDict
from manic.global_constants import EMPTY_STR


class TestGitRepositoryCurrentRefBranch(unittest.TestCase):
    """test the current_ref_from_branch_command on a git repository
    """
    GIT_BRANCH_OUTPUT_DETACHED_TAG = '''
* (HEAD detached at rtm1_0_26)
  a_feature_branch
  master
'''
    GIT_BRANCH_OUTPUT_BRANCH = '''
* great_new_feature_branch
  a_feature_branch
  master
'''
    GIT_BRANCH_OUTPUT_HASH = '''
* (HEAD detached at 0246874c)
  a_feature_branch
  master
'''

    def setUp(self):
        self._name = 'component'
        rdata = {ExternalsDescription.PROTOCOL: 'git',
                 ExternalsDescription.REPO_URL:
                 'git@git.github.com:ncar/rtm',
                 ExternalsDescription.TAG:
                 'rtm1_0_26',
                 ExternalsDescription.BRANCH: EMPTY_STR
                 }

        data = {self._name:
                {
                    ExternalsDescription.REQUIRED: False,
                    ExternalsDescription.PATH: 'junk',
                    ExternalsDescription.EXTERNALS: EMPTY_STR,
                    ExternalsDescription.REPO: rdata,
                },
                }

        model = ExternalsDescriptionDict(data)
        repo = model[self._name][ExternalsDescription.REPO]
        self._repo = GitRepository('test', repo)

    def test_ref_detached_from_tag(self):
        """Test that we correctly identify that the ref is detached from a tag
        """
        git_output = self.GIT_BRANCH_OUTPUT_DETACHED_TAG
        expected = self._repo.tag()
        result = self._repo.current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)

    def test_ref_branch(self):
        """Test that we correctly identify we are on a branch
        """
        git_output = self.GIT_BRANCH_OUTPUT_BRANCH
        expected = 'great_new_feature_branch'
        result = self._repo.current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)

    def test_ref_detached_hash(self):
        """Test that we can handle an empty string for output, e.g. not an git
        repo.

        """
        git_output = self.GIT_BRANCH_OUTPUT_HASH
        expected = '0246874c'
        result = self._repo.current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)

    def test_ref_none(self):
        """Test that we can handle an empty string for output, e.g. not an git
        repo.

        """
        git_output = EMPTY_STR
        expected = EMPTY_STR
        result = self._repo.current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)


class TestGitRepositoryCheckSync(unittest.TestCase):
    """Test whether the GitRepository git_check_sync functionality is
    correct.

    """
    TMP_GIT_DIR = 'fake/.git'

    def setUp(self):
        """Setup reusable git repository object
        """
        self._name = 'component'
        rdata = {ExternalsDescription.PROTOCOL: 'git',
                 ExternalsDescription.REPO_URL:
                 'git@git.github.com:ncar/rtm',
                 ExternalsDescription.TAG:
                 'rtm1_0_26',
                 ExternalsDescription.BRANCH: EMPTY_STR
                 }

        data = {self._name:
                {
                    ExternalsDescription.REQUIRED: False,
                    ExternalsDescription.PATH: 'fake',
                    ExternalsDescription.EXTERNALS: '',
                    ExternalsDescription.REPO: rdata,
                },
                }

        model = ExternalsDescriptionDict(data)
        repo = model[self._name][ExternalsDescription.REPO]
        self._repo = GitRepository('test', repo)
        self.create_tmp_git_dir()

    def tearDown(self):
        """Cleanup tmp stuff on the file system
        """
        self.remove_tmp_git_dir()

    def create_tmp_git_dir(self):
        """Create a temporary fake git directory for testing purposes.
        """
        if not os.path.exists(self.TMP_GIT_DIR):
            os.makedirs(self.TMP_GIT_DIR)

    def remove_tmp_git_dir(self):
        """Remove the temporary fake git directory
        """
        if os.path.exists(self.TMP_GIT_DIR):
            shutil.rmtree(self.TMP_GIT_DIR)

    @staticmethod
    def _git_branch_empty():
        """Return an empty info string. Simulates svn info failing.
        """
        return ''

    @staticmethod
    def _git_branch_synced():
        """Return an info sting that is synced with the setUp data
        """
        git_output = '''
* (HEAD detached at rtm1_0_26)
  a_feature_branch
  master
'''
        return git_output

    @staticmethod
    def _git_branch_modified():
        """Return and info string that is modified from the setUp data
        """
        git_output = '''
* great_new_feature_branch
  a_feature_branch
  master
'''
        return git_output

    def test_repo_dir_not_exist(self):
        """Test that a directory that doesn't exist returns an error status

        Note: the Repository classes should be prevented from ever
        working on an empty directory by the _Source object.

        """
        stat = ExternalStatus()
        self._repo.git_check_sync(stat, 'junk')
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_ERROR)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_repo_dir_exist_no_git_info(self):
        """Test that an empty info string returns an unknown status
        """
        stat = ExternalStatus()
        # Now we over-ride the _git_branch method on the repo to return
        # a known value without requiring access to git.
        self._repo.git_branch = self._git_branch_empty
        self._repo.git_check_sync(stat, 'fake')
        self.assertEqual(stat.sync_state, ExternalStatus.UNKNOWN)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_repo_dir_synced(self):
        """Test that a valid info string that is synced to the repo in the
        externals description returns an ok status.

        """
        stat = ExternalStatus()
        # Now we over-ride the _git_branch method on the repo to return
        # a known value without requiring access to svn.
        self._repo.git_branch = self._git_branch_synced
        self._repo.git_check_sync(stat, 'fake')
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_OK)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_repo_dir_modified(self):
        """Test that a valid svn info string that is out of sync with the
        externals description returns a modified status.

        """
        stat = ExternalStatus()
        # Now we over-ride the _svn_info method on the repo to return
        # a known value without requiring access to svn.
        self._repo.git_branch = self._git_branch_modified
        self._repo.git_check_sync(stat, 'fake')
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)


class TestGitStatusPorcelain(unittest.TestCase):
    """Test parsing of output from git status --porcelain=v1 -z
    """
    GIT_STATUS_PORCELAIN_V1_ALL = (
        r' D INSTALL\0MM Makefile\0M README.md\0R  cmakelists.txt\0'
        r'CMakeLists.txt\0D  commit-message-template.txt\0A  stuff.txt\0'
        r'?? junk.txt')

    GIT_STATUS_PORCELAIN_CLEAN = r''

    def test_porcelain_status_dirty(self):
        """Verify that git status output is considered dirty when there are
        listed files.

        """
        git_output = self.GIT_STATUS_PORCELAIN_V1_ALL
        is_dirty = GitRepository.git_status_v1z_is_dirty(
            git_output)
        self.assertTrue(is_dirty)

    def test_porcelain_status_clean(self):
        """Verify that git status output is considered clean when there are no
        listed files.

        """
        git_output = self.GIT_STATUS_PORCELAIN_CLEAN
        is_dirty = GitRepository.git_status_v1z_is_dirty(
            git_output)
        self.assertFalse(is_dirty)


if __name__ == '__main__':
    unittest.main()
