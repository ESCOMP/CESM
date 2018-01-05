#!/usr/bin/env python

"""Unit test driver for checkout_externals

Note: this script assume the path to the checkout_externals.py module is
already in the python path.

"""
# pylint: disable=too-many-lines,protected-access

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import os
import shutil
import string
import unittest

from manic.repository_git import GitRepository
from manic.externals_status import ExternalStatus
from manic.externals_description import ExternalsDescription
from manic.externals_description import ExternalsDescriptionDict
from manic.global_constants import EMPTY_STR

# pylint: disable=C0103
GIT_BRANCH_OUTPUT_DETACHED_BRANCH_v1_8 = '''
* (detached from origin/feature2) 36418b4 Work on feature2
  master                          9b75494 [origin/master] Initialize repository.
'''
# pylint: enable=C0103


GIT_BRANCH_OUTPUT_DETACHED_BRANCH = '''
* (HEAD detached at origin/feature-2) 36418b4 Work on feature-2
  feature-2                           36418b4 [origin/feature-2] Work on feature-2
  feature3                           36418b4 Work on feature-2
  master                             9b75494 [origin/master] Initialize repository.
'''

GIT_BRANCH_OUTPUT_DETACHED_HASH = '''
* (HEAD detached at 36418b4) 36418b4 Work on feature-2
  feature-2                   36418b4 [origin/feature-2] Work on feature-2
  feature3                   36418b4 Work on feature-2
  master                     9b75494 [origin/master] Initialize repository.
'''

GIT_BRANCH_OUTPUT_DETACHED_TAG = '''
* (HEAD detached at tag1) 9b75494 Initialize repository.
  feature-2                36418b4 [origin/feature-2] Work on feature-2
  feature3                36418b4 Work on feature-2
  master                  9b75494 [origin/master] Initialize repository.
'''

GIT_BRANCH_OUTPUT_UNTRACKED_BRANCH = '''
  feature-2 36418b4 [origin/feature-2] Work on feature-2
* feature3 36418b4 Work on feature-2
  master   9b75494 [origin/master] Initialize repository.
'''

GIT_BRANCH_OUTPUT_TRACKING_BRANCH = '''
* feature-2 36418b4 [origin/feature-2] Work on feature-2
  feature3 36418b4 Work on feature-2
  master   9b75494 [origin/master] Initialize repository.
'''

# NOTE(bja, 2017-11) order is important here. origin should be a
# subset of other to trap errors on processing remotes!
GIT_REMOTE_OUTPUT_ORIGIN_UPSTREAM = '''
upstream	/path/to/other/repo (fetch)
upstream	/path/to/other/repo (push)
other	/path/to/local/repo2 (fetch)
other	/path/to/local/repo2 (push)
origin	/path/to/local/repo (fetch)
origin	/path/to/local/repo (push)
'''


class TestGitRepositoryCurrentRefBranch(unittest.TestCase):
    """test the current_ref_from_branch_command on a git repository
    """

    def setUp(self):
        self._name = 'component'
        rdata = {ExternalsDescription.PROTOCOL: 'git',
                 ExternalsDescription.REPO_URL:
                 '/path/to/local/repo',
                 ExternalsDescription.TAG:
                 'tag1',
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
        git_output = GIT_BRANCH_OUTPUT_DETACHED_TAG
        expected = self._repo.tag()
        result = self._repo._current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)

    def test_ref_detached_hash(self):
        """Test that we can identify ref is detached from a hash

        """
        git_output = GIT_BRANCH_OUTPUT_DETACHED_HASH
        expected = '36418b4'
        result = self._repo._current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)

    def test_ref_detached_branch(self):
        """Test that we can identify ref is detached from a remote branch

        """
        git_output = GIT_BRANCH_OUTPUT_DETACHED_BRANCH
        expected = 'origin/feature-2'
        result = self._repo._current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)

    def test_ref_detached_branch_v1_8(self):
        """Test that we can identify ref is detached from a remote branch

        """
        git_output = GIT_BRANCH_OUTPUT_DETACHED_BRANCH_v1_8
        expected = 'origin/feature2'
        result = self._repo._current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)

    def test_ref_tracking_branch(self):
        """Test that we correctly identify we are on a tracking branch
        """
        git_output = GIT_BRANCH_OUTPUT_TRACKING_BRANCH
        expected = 'origin/feature-2'
        result = self._repo._current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)

    def test_ref_untracked_branch(self):
        """Test that we correctly identify we are on an untracked branch
        """
        git_output = GIT_BRANCH_OUTPUT_UNTRACKED_BRANCH
        expected = 'feature3'
        result = self._repo._current_ref_from_branch_command(
            git_output)
        self.assertEqual(result, expected)

    def test_ref_none(self):
        """Test that we can handle an empty string for output, e.g. not an git
        repo.

        """
        git_output = EMPTY_STR
        received = self._repo._current_ref_from_branch_command(
            git_output)
        self.assertEqual(received, EMPTY_STR)


class TestGitRepositoryCheckSync(unittest.TestCase):
    """Test whether the GitRepository _check_sync_logic functionality is
    correct.

    Note: there are a lot of combinations of state:

    - external description - tag, branch

    - working copy
      - doesn't exist (not checked out)
      - exists, no git info - incorrect protocol, e.g. svn, or tarball?
      - exists, git info
        - as expected:
        - different from expected:
           - detached tag,
           - detached hash,
           - detached branch (compare remote and branch),
           - tracking branch (compare remote and branch),
             - same remote
             - different remote
           - untracked branch

    Test list:
      - doesn't exist
      - exists no git info

      - num_external * (working copy expected + num_working copy different)
      - total tests = 16

    """

    # NOTE(bja, 2017-11) pylint complains about long method names, but
    # it is hard to differentiate tests without making them more
    # cryptic. Also complains about too many public methods, but it
    # doesn't really make sense to break this up.
    # pylint: disable=invalid-name,too-many-public-methods

    TMP_FAKE_DIR = 'fake'
    TMP_FAKE_GIT_DIR = os.path.join(TMP_FAKE_DIR, '.git')

    def setUp(self):
        """Setup reusable git repository object
        """
        self._name = 'component'
        rdata = {ExternalsDescription.PROTOCOL: 'git',
                 ExternalsDescription.REPO_URL:
                 '/path/to/local/repo',
                 ExternalsDescription.TAG: 'tag1',
                 ExternalsDescription.BRANCH: EMPTY_STR
                 }

        data = {self._name:
                {
                    ExternalsDescription.REQUIRED: False,
                    ExternalsDescription.PATH: self.TMP_FAKE_DIR,
                    ExternalsDescription.EXTERNALS: EMPTY_STR,
                    ExternalsDescription.REPO: rdata,
                },
                }

        model = ExternalsDescriptionDict(data)
        repo = model[self._name][ExternalsDescription.REPO]
        self._repo = GitRepository('test', repo)
        self._create_tmp_git_dir()

    def tearDown(self):
        """Cleanup tmp stuff on the file system
        """
        self._remove_tmp_git_dir()

    def _create_tmp_git_dir(self):
        """Create a temporary fake git directory for testing purposes.
        """
        if not os.path.exists(self.TMP_FAKE_GIT_DIR):
            os.makedirs(self.TMP_FAKE_GIT_DIR)

    def _remove_tmp_git_dir(self):
        """Remove the temporary fake git directory
        """
        if os.path.exists(self.TMP_FAKE_DIR):
            shutil.rmtree(self.TMP_FAKE_DIR)

    #
    # mock methods replacing git system calls
    #
    @staticmethod
    def _git_branch_empty():
        """Return an empty info string. Simulates git info failing.
        """
        return EMPTY_STR

    @staticmethod
    def _git_branch_detached_tag():
        """Return an info sting that is a checkouted tag
        """
        return GIT_BRANCH_OUTPUT_DETACHED_TAG

    @staticmethod
    def _git_branch_detached_hash():
        """Return an info string that is a checkout hash
        """
        return GIT_BRANCH_OUTPUT_DETACHED_HASH

    @staticmethod
    def _git_branch_detached_branch():
        """Return an info string that is a checkout hash
        """
        return GIT_BRANCH_OUTPUT_DETACHED_BRANCH

    @staticmethod
    def _git_branch_untracked_branch():
        """Return an info string that is a checkout branch
        """
        return GIT_BRANCH_OUTPUT_UNTRACKED_BRANCH

    @staticmethod
    def _git_branch_tracked_branch():
        """Return an info string that is a checkout branch
        """
        return GIT_BRANCH_OUTPUT_TRACKING_BRANCH

    @staticmethod
    def _git_remote_origin_upstream():
        """Return an info string that is a checkout hash
        """
        return GIT_REMOTE_OUTPUT_ORIGIN_UPSTREAM

    @staticmethod
    def _git_remote_none():
        """Return an info string that is a checkout hash
        """
        return EMPTY_STR

    # ----------------------------------------------------------------
    #
    # Tests where working copy doesn't exist or is invalid
    #
    # ----------------------------------------------------------------
    def test_sync_dir_not_exist(self):
        """Test that a directory that doesn't exist returns an error status

        Note: the Repository classes should be prevented from ever
        working on an empty directory by the _Source object.

        """
        stat = ExternalStatus()
        self._repo._check_sync(stat, 'invalid_directory_name')
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_ERROR)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_dir_exist_no_git_info(self):
        """Test that an empty info string returns an unknown status
        """
        stat = ExternalStatus()
        # Now we over-ride the _git_branch method on the repo to return
        # a known value without requiring access to git.
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._git_branch_vv = self._git_branch_empty
        self._repo._check_sync(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.UNKNOWN)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    # ----------------------------------------------------------------
    #
    # Tests where external description specifies a tag
    #
    # Perturbations of working dir state: on detached
    # {tag|branch|hash}, tracking branch, untracked branch.
    #
    # ----------------------------------------------------------------
    def test_sync_tag_on_detached_tag(self):
        """Test expect tag on detached tag --> status ok

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = ''
        self._repo._tag = 'tag1'
        self._repo._git_branch_vv = self._git_branch_detached_tag
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_OK)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_tag_on_diff_tag(self):
        """Test expect tag on diff tag --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = ''
        self._repo._tag = 'tag2'
        self._repo._git_branch_vv = self._git_branch_detached_tag
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_tag_on_detached_hash(self):
        """Test expect tag on detached hash --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = ''
        self._repo._tag = 'tag1'
        self._repo._git_branch_vv = self._git_branch_detached_hash
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_tag_on_detached_branch(self):
        """Test expect tag on detached branch --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = ''
        self._repo._tag = 'tag1'
        self._repo._git_branch_vv = self._git_branch_detached_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_tag_on_tracking_branch(self):
        """Test expect tag on tracking branch --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = ''
        self._repo._tag = 'tag1'
        self._repo._git_branch_vv = self._git_branch_tracked_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_tag_on_untracked_branch(self):
        """Test expect tag on untracked branch --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = ''
        self._repo._tag = 'tag1'
        self._repo._git_branch_vv = self._git_branch_untracked_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    # ----------------------------------------------------------------
    #
    # Tests where external description specifies a branch
    #
    # Perturbations of working dir state: on detached
    # {tag|branch|hash}, tracking branch, untracked branch.
    #
    # ----------------------------------------------------------------
    def test_sync_branch_on_detached_branch_same_remote(self):
        """Test expect branch on detached branch with same remote --> status ok

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._git_branch_vv = self._git_branch_detached_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_OK)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_detached_branch_diff_remote(self):
        """Test expect branch on detached branch, different remote --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._url = '/path/to/other/repo'
        self._repo._git_branch_vv = self._git_branch_detached_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_detached_branch_diff_remote2(self):
        """Test expect branch on detached branch, different remote --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._url = '/path/to/local/repo2'
        self._repo._git_branch_vv = self._git_branch_detached_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_diff_branch(self):
        """Test expect branch on diff branch --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'nice_new_feature'
        self._repo._tag = ''
        self._repo._git_branch_vv = self._git_branch_detached_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_detached_hash(self):
        """Test expect branch on detached hash --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._git_branch_vv = self._git_branch_detached_hash
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_detached_tag(self):
        """Test expect branch on detached tag --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._git_branch_vv = self._git_branch_detached_tag
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_tracking_branch_same_remote(self):
        """Test expect branch on tracking branch with same remote --> status ok

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._git_branch_vv = self._git_branch_tracked_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_OK)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_tracking_branch_diff_remote(self):
        """Test expect branch on tracking branch with different remote-->
        status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._url = '/path/to/other/repo'
        self._repo._git_branch_vv = self._git_branch_tracked_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_untracked_branch(self):
        """Test expect branch on untracked branch --> status modified

        NOTE(bja, 2017-11) the externals description url is always a
        remote repository. A local untracked branch only exists
        locally, therefore it is always a modified state, even if this
        is what the user wants.

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._git_branch_vv = self._git_branch_untracked_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_unknown_remote(self):
        """Test expect branch, but remote is unknown --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._url = '/path/to/unknown/repo'
        self._repo._git_branch_vv = self._git_branch_untracked_branch
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_untracked_local(self):
        """Test expect branch, on untracked branch in local repo --> status ok

        Setting the externals description to '.' indicates that the
        user only want's to consider the current local repo state
        without fetching from remotes. This is required to preserve
        the current branch of a repository during an update.

        NOTE(bja, 2017-11) the externals description is always a
        remote repository. A local untracked branch only exists
        locally, therefore it is always a modified state, even if this
        is what the user wants.

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature3'
        self._repo._tag = ''
        self._repo._git_branch_vv = self._git_branch_untracked_branch
        self._repo._url = '.'
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_OK)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)


class TestGitRegExp(unittest.TestCase):
    """Test that the regular expressions in the GitRepository class
    capture intended strings

    """

    def setUp(self):
        """Common constans
        """
        self._detached_git_v2_tmpl = string.Template(
            '* (HEAD detached at $ref) 36418b4 Work on feature-2')

        self._detached_git_v1_tmpl = string.Template(
            '* (detached from $ref) 36418b4 Work on feature-2')

        self._tracking_tmpl = string.Template(
            '* feature-2 36418b4 [$ref] Work on feature-2')

    #
    # RE_DETACHED
    #
    def test_re_detached_alphnum(self):
        """Test re correctly matches alphnumeric (basic debugging)
        """
        value = 'feature2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)
        input_str = self._detached_git_v1_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_detached_underscore(self):
        """Test re matches with underscore
        """
        value = 'feature_2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)
        input_str = self._detached_git_v1_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_detached_hyphen(self):
        """Test re matches -
        """
        value = 'feature-2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)
        input_str = self._detached_git_v1_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_detached_period(self):
        """Test re matches .
        """
        value = 'feature.2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)
        input_str = self._detached_git_v1_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_detached_slash(self):
        """Test re matches /
        """
        value = 'feature/2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)
        input_str = self._detached_git_v1_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    #
    # RE_TRACKING
    #
    def test_re_tracking_alphnum(self):
        """Test re matches alphanumeric for basic debugging
        """
        value = 'feature2'
        input_str = self._tracking_tmpl.substitute(ref=value)
        match = GitRepository.RE_TRACKING.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_tracking_underscore(self):
        """Test re matches _
        """
        value = 'feature_2'
        input_str = self._tracking_tmpl.substitute(ref=value)
        match = GitRepository.RE_TRACKING.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_tracking_hyphen(self):
        """Test re matches -
        """
        value = 'feature-2'
        input_str = self._tracking_tmpl.substitute(ref=value)
        match = GitRepository.RE_TRACKING.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_tracking_period(self):
        """Test re match .
        """
        value = 'feature.2'
        input_str = self._tracking_tmpl.substitute(ref=value)
        match = GitRepository.RE_TRACKING.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_tracking_slash(self):
        """Test re matches /
        """
        value = 'feature/2'
        input_str = self._tracking_tmpl.substitute(ref=value)
        match = GitRepository.RE_TRACKING.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)


class TestGitStatusPorcelain(unittest.TestCase):
    """Test parsing of output from git status --porcelain=v1 -z
    """
    # pylint: disable=C0103
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
        is_dirty = GitRepository._status_v1z_is_dirty(git_output)
        self.assertTrue(is_dirty)

    def test_porcelain_status_clean(self):
        """Verify that git status output is considered clean when there are no
        listed files.

        """
        git_output = self.GIT_STATUS_PORCELAIN_CLEAN
        is_dirty = GitRepository._status_v1z_is_dirty(git_output)
        self.assertFalse(is_dirty)


class TestGitCreateRemoteName(unittest.TestCase):
    """Test the create_remote_name method on the GitRepository class
    """

    def setUp(self):
        """Common infrastructure for testing _create_remote_name
        """
        self._rdata = {ExternalsDescription.PROTOCOL: 'git',
                       ExternalsDescription.REPO_URL:
                       'empty',
                       ExternalsDescription.TAG:
                       'very_useful_tag',
                       ExternalsDescription.BRANCH: EMPTY_STR, }
        self._repo = GitRepository('test', self._rdata)

    def test_remote_git_proto(self):
        """Test remote with git protocol
        """
        self._repo._url = 'git@git.github.com:very_nice_org/useful_repo'
        remote_name = self._repo._create_remote_name()
        self.assertEqual(remote_name, 'very_nice_org_useful_repo')

    def test_remote_https_proto(self):
        """Test remote with git protocol
        """
        self._repo._url = 'https://www.github.com/very_nice_org/useful_repo'
        remote_name = self._repo._create_remote_name()
        self.assertEqual(remote_name, 'very_nice_org_useful_repo')

    def test_remote_local_abs(self):
        """Test remote with git protocol
        """
        self._repo._url = '/path/to/local/repositories/useful_repo'
        remote_name = self._repo._create_remote_name()
        self.assertEqual(remote_name, 'repositories_useful_repo')

    def test_remote_local_rel(self):
        """Test remote with git protocol
        """
        os.environ['TEST_VAR'] = '/my/path/to/repos'
        self._repo._url = '${TEST_VAR}/../../useful_repo'
        remote_name = self._repo._create_remote_name()
        self.assertEqual(remote_name, 'path_useful_repo')
        del os.environ['TEST_VAR']


class TestVerifyTag(unittest.TestCase):
    """Test logic verifying that a tag exists and is unique

    """

    def setUp(self):
        """Setup reusable git repository object
        """
        self._name = 'component'
        rdata = {ExternalsDescription.PROTOCOL: 'git',
                 ExternalsDescription.REPO_URL:
                 '/path/to/local/repo',
                 ExternalsDescription.TAG: 'tag1',
                 ExternalsDescription.BRANCH: EMPTY_STR
                 }

        data = {self._name:
                {
                    ExternalsDescription.REQUIRED: False,
                    ExternalsDescription.PATH: 'tmp',
                    ExternalsDescription.EXTERNALS: EMPTY_STR,
                    ExternalsDescription.REPO: rdata,
                },
                }

        model = ExternalsDescriptionDict(data)
        repo = model[self._name][ExternalsDescription.REPO]
        self._repo = GitRepository('test', repo)

    @staticmethod
    def _shell_true(url, remote=None):
        _ = url
        _ = remote
        return 0

    @staticmethod
    def _shell_false(url, remote=None):
        _ = url
        _ = remote
        return 1

    def test_tag_not_tag_branch_commit(self):
        """Verify a non-tag returns false
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._shell_false
        self._repo._tag = 'something'
        remote_name = 'origin'
        received, _ = self._repo._is_unique_tag(self._repo._tag, remote_name)
        self.assertFalse(received)

    def test_tag_not_tag(self):
        """Verify a non-tag, untracked remote returns false
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_true
        self._repo._git_lsremote_branch = self._shell_true
        self._repo._git_revparse_commit = self._shell_false
        self._repo._tag = 'tag1'
        remote_name = 'origin'
        received, _ = self._repo._is_unique_tag(self._repo._tag, remote_name)
        self.assertFalse(received)

    def test_tag_indeterminant(self):
        """Verify an indeterminant tag/branch returns false
        """
        self._repo._git_showref_tag = self._shell_true
        self._repo._git_showref_branch = self._shell_true
        self._repo._git_lsremote_branch = self._shell_true
        self._repo._git_revparse_commit = self._shell_true
        self._repo._tag = 'something'
        remote_name = 'origin'
        received, _ = self._repo._is_unique_tag(self._repo._tag, remote_name)
        self.assertFalse(received)

    def test_tag_is_unique(self):
        """Verify a unique tag match returns true
        """
        self._repo._git_showref_tag = self._shell_true
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._shell_true
        self._repo._tag = 'tag1'
        remote_name = 'origin'
        received, _ = self._repo._is_unique_tag(self._repo._tag, remote_name)
        self.assertTrue(received)

    def test_tag_is_commit(self):
        """Verify a commit hash
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._shell_true
        self._repo._tag = '97ebc0e0'
        remote_name = 'origin'
        received, _ = self._repo._is_unique_tag(self._repo._tag, remote_name)
        self.assertTrue(received)


class TestValidRef(unittest.TestCase):
    """Test logic verifying that a reference is a valid tag, branch or sha1

    """

    def setUp(self):
        """Setup reusable git repository object
        """
        self._name = 'component'
        rdata = {ExternalsDescription.PROTOCOL: 'git',
                 ExternalsDescription.REPO_URL:
                 '/path/to/local/repo',
                 ExternalsDescription.TAG: 'tag1',
                 ExternalsDescription.BRANCH: EMPTY_STR
                 }

        data = {self._name:
                {
                    ExternalsDescription.REQUIRED: False,
                    ExternalsDescription.PATH: 'tmp',
                    ExternalsDescription.EXTERNALS: EMPTY_STR,
                    ExternalsDescription.REPO: rdata,
                },
                }

        model = ExternalsDescriptionDict(data)
        repo = model[self._name][ExternalsDescription.REPO]
        self._repo = GitRepository('test', repo)

    @staticmethod
    def _shell_true(url, remote=None):
        _ = url
        _ = remote
        return 0

    @staticmethod
    def _shell_false(url, remote=None):
        _ = url
        _ = remote
        return 1

    def test_valid_ref_is_invalid(self):
        """Verify an invalid reference raises an exception
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._shell_false
        self._repo._tag = 'invalid_ref'
        with self.assertRaises(RuntimeError):
            self._repo._check_for_valid_ref(self._repo._tag)

    def test_valid_tag(self):
        """Verify a valid tag return true
        """
        self._repo._git_showref_tag = self._shell_true
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._shell_true
        self._repo._tag = 'tag1'
        received = self._repo._check_for_valid_ref(self._repo._tag)
        self.assertTrue(received)

    def test_valid_branch(self):
        """Verify a valid tag return true
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_true
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._shell_true
        self._repo._tag = 'tag1'
        received = self._repo._check_for_valid_ref(self._repo._tag)
        self.assertTrue(received)

    def test_valid_hash(self):
        """Verify a valid tag return true
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._shell_true
        self._repo._tag = '56cc0b5394'
        received = self._repo._check_for_valid_ref(self._repo._tag)
        self.assertTrue(received)


if __name__ == '__main__':
    unittest.main()
