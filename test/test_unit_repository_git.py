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

# In the following git branch output, note the distinction between
# "detached at" vs. "detached from": At least with recent versions of
# git, "detached at" means your HEAD is still at the same hash as the
# given reference; "detached from" means that your HEAD has moved past
# the hash corresponding to the given reference (branch or tag). (Ben
# Andre says that earlier versions of git, such as 1.8, did not
# distinguish between these situations, instead calling everything
# "detached from".)

GIT_BRANCH_OUTPUT_DETACHED_BRANCH = '''
* (HEAD detached at origin/feature-2) 36418b4 Work on feature-2
  feature-2                           36418b4 [origin/feature-2] Work on feature-2
  feature3                           36418b4 Work on feature-2
  master                             9b75494 [origin/master] Initialize repository.
'''

GIT_BRANCH_OUTPUT_DETACHED_FROM_BRANCH = '''
* (HEAD detached from origin/feature2) 36418b4 Work on feature2
  master                               9b75494 [origin/master] Initialize repository.
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

GIT_BRANCH_OUTPUT_DETACHED_FROM_TAG = '''
* (HEAD detached from tag1) 9b75494 Initialize repository.
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

GIT_BRANCH_OUTPUT_TRACKING_BRANCH_AHEAD_BEHIND = '''
* master 408a8920 [origin/master: ahead 3, behind 2] more junk
  feature3 36418b4 Work on feature-2
'''

GIT_BRANCH_OUTPUT_TRACKING_BRANCH_AHEAD = '''
* master 408a8920 [origin/master: ahead 3] more junk
  feature3 36418b4 Work on feature-2
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

    #
    # mock methods replacing git system calls
    #
    @staticmethod
    def _git_branch_vv(output):
        """Return a function that takes the place of
        repo._git_branch_vv, which returns the given output.
        """
        def my_git_branch_vv():
            return output
        return my_git_branch_vv

    # ------------------------------------------------------------------------
    # Begin tests
    #
    # See above for distinction between "detached at" vs. "detached from"
    # ------------------------------------------------------------------------

    def test_ref_detached_tag(self):
        """Test that we correctly identify that the ref is detached at a tag
        """
        self._repo._git_branch_vv = self._git_branch_vv(
            GIT_BRANCH_OUTPUT_DETACHED_TAG)
        expected = self._repo.tag()
        result = self._repo._current_ref()
        self.assertEqual(result, expected)

    def test_ref_detached_from_tag(self):
        """Test that we correctly identify that the ref is detached FROM a tag

        In this case, the best we can do is to list the hash we're on
        """
        self._repo._git_branch_vv = self._git_branch_vv(
            GIT_BRANCH_OUTPUT_DETACHED_FROM_TAG)
        expected = '9b75494'
        result = self._repo._current_ref()
        self.assertEqual(result, expected)

    def test_ref_detached_hash(self):
        """Test that we can identify ref is detached at a hash

        """
        self._repo._git_branch_vv = self._git_branch_vv(
            GIT_BRANCH_OUTPUT_DETACHED_HASH)
        expected = '36418b4'
        result = self._repo._current_ref()
        self.assertEqual(result, expected)

    def test_ref_detached_branch(self):
        """Test that we can identify ref is detached at a remote branch

        """
        self._repo._git_branch_vv = self._git_branch_vv(
            GIT_BRANCH_OUTPUT_DETACHED_BRANCH)
        expected = 'origin/feature-2'
        result = self._repo._current_ref()
        self.assertEqual(result, expected)

    def test_ref_detached_from_branch(self):
        """Test that we can identify ref is detached FROM a remote branch

        In this case, the best we can do is to list the hash we're on
        """
        self._repo._git_branch_vv = self._git_branch_vv(
            GIT_BRANCH_OUTPUT_DETACHED_FROM_BRANCH)
        expected = '36418b4'
        result = self._repo._current_ref()
        self.assertEqual(result, expected)

    def test_ref_tracking_branch(self):
        """Test that we correctly identify we are on a tracking branch
        """
        self._repo._git_branch_vv = self._git_branch_vv(
            GIT_BRANCH_OUTPUT_TRACKING_BRANCH)
        expected = 'origin/feature-2'
        result = self._repo._current_ref()
        self.assertEqual(result, expected)

    def test_ref_tracking_branch_ahead(self):
        """Test that we correctly identify we are on a tracking branch that is
        ahead or behind the remote branch.

        """
        self._repo._git_branch_vv = self._git_branch_vv(
            GIT_BRANCH_OUTPUT_TRACKING_BRANCH_AHEAD)
        expected = 'origin/master'
        result = self._repo._current_ref()
        self.assertEqual(result, expected)

    def test_ref_tracking_branch_ahead_behind(self):  # pylint: disable=C0103
        """Test that we correctly identify we are on a tracking branch that is
        ahead or behind the remote branch.

        """
        self._repo._git_branch_vv = self._git_branch_vv(
            GIT_BRANCH_OUTPUT_TRACKING_BRANCH_AHEAD_BEHIND)
        expected = 'origin/master'
        result = self._repo._current_ref()
        self.assertEqual(result, expected)

    def test_ref_untracked_branch(self):
        """Test that we correctly identify we are on an untracked branch
        """
        self._repo._git_branch_vv = self._git_branch_vv(
            GIT_BRANCH_OUTPUT_UNTRACKED_BRANCH)
        expected = 'feature3'
        result = self._repo._current_ref()
        self.assertEqual(result, expected)

    def test_ref_none(self):
        """Test that we can handle an empty string for output, e.g. not an git
        repo.

        """
        self._repo._git_branch_vv = self._git_branch_vv(
            EMPTY_STR)
        received = self._repo._current_ref()
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
        # The unit tests here don't care about the result of
        # _git_branch_vv, but we replace it here so that we don't need
        # to worry about calling a possibly slow and possibly
        # error-producing command:
        self._repo._git_branch_vv = self._git_branch_empty
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
    def _git_remote_origin_upstream():
        """Return an info string that is a checkout hash
        """
        return GIT_REMOTE_OUTPUT_ORIGIN_UPSTREAM

    @staticmethod
    def _git_remote_none():
        """Return an info string that is a checkout hash
        """
        return EMPTY_STR

    @staticmethod
    def _git_log_hash(myhash):
        """Return a function that takes the place of repo._git_log_hash,
        which returns the given hash
        """
        def my_git_log_hash():
            return myhash
        return my_git_log_hash

    def _git_revparse_commit(self, expected_ref, mystatus, myhash):
        """Return a function that takes the place of
        repo._git_revparse_commit, which returns a tuple:
        (mystatus, myhash).

        Expects the passed-in ref to equal expected_ref

        status = 0 implies success, non-zero implies failure
        """
        def my_git_revparse_commit(ref):
            self.assertEqual(expected_ref, ref)
            return mystatus, myhash
        return my_git_revparse_commit

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
        """Test that a non-existent git repo returns an unknown status
        """
        stat = ExternalStatus()
        # Now we over-ride the _git_remote_verbose method on the repo to return
        # a known value without requiring access to git.
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._tag = 'tag1'
        self._repo._git_log_hash = self._git_log_hash('')
        self._repo._git_revparse_commit = self._git_revparse_commit('tag1', 1, '')
        self._repo._check_sync(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.UNKNOWN)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    # ------------------------------------------------------------------------
    #
    # Tests where version in configuration file is not a valid reference
    #
    # ------------------------------------------------------------------------

    def test_sync_invalid_reference(self):
        """Test that an invalid reference returns out-of-sync
        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._tag = 'tag1'
        self._repo._git_log_hash = self._git_log_hash('abc123')
        self._repo._git_revparse_commit = self._git_revparse_commit('tag1', 1, '')
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    # ----------------------------------------------------------------
    #
    # Tests where external description specifies a tag
    #
    # ----------------------------------------------------------------
    def test_sync_tag_on_same_hash(self):
        """Test expect tag on same hash --> status ok

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._tag = 'tag1'
        self._repo._git_log_hash = self._git_log_hash('abc123')
        self._repo._git_revparse_commit = self._git_revparse_commit('tag1', 0, 'abc123')
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_OK)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_tag_on_different_hash(self):
        """Test expect tag on a different hash --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._tag = 'tag1'
        self._repo._git_log_hash = self._git_log_hash('def456')
        self._repo._git_revparse_commit = self._git_revparse_commit('tag1', 0, 'abc123')
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    # ----------------------------------------------------------------
    #
    # Tests where external description specifies a hash
    #
    # ----------------------------------------------------------------
    def test_sync_hash_on_same_hash(self):
        """Test expect hash on same hash --> status ok

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._tag = ''
        self._repo._hash = 'abc'
        self._repo._git_log_hash = self._git_log_hash('abc123')
        self._repo._git_revparse_commit = self._git_revparse_commit('abc', 0, 'abc123')
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_OK)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_hash_on_different_hash(self):
        """Test expect hash on a different hash --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._tag = ''
        self._repo._hash = 'abc'
        self._repo._git_log_hash = self._git_log_hash('def456')
        self._repo._git_revparse_commit = self._git_revparse_commit('abc', 0, 'abc123')
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    # ----------------------------------------------------------------
    #
    # Tests where external description specifies a branch
    #
    # ----------------------------------------------------------------
    def test_sync_branch_on_same_hash(self):
        """Test expect branch on same hash --> status ok

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._git_log_hash = self._git_log_hash('abc123')
        self._repo._git_revparse_commit = (
            self._git_revparse_commit('origin/feature-2', 0, 'abc123'))
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_OK)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_diff_hash(self):
        """Test expect branch on diff hash --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._git_log_hash = self._git_log_hash('abc123')
        self._repo._git_revparse_commit = (
            self._git_revparse_commit('origin/feature-2', 0, 'def456'))
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_diff_remote(self):
        """Test _determine_remote_name with a different remote

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._url = '/path/to/other/repo'
        self._repo._git_log_hash = self._git_log_hash('abc123')
        self._repo._git_revparse_commit = (
            self._git_revparse_commit('upstream/feature-2', 0, 'def456'))
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        # The test passes if _git_revparse_commit is called with the
        # expected argument

    def test_sync_branch_diff_remote2(self):
        """Test _determine_remote_name with a different remote

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._url = '/path/to/local/repo2'
        self._repo._git_log_hash = self._git_log_hash('abc123')
        self._repo._git_revparse_commit = (
            self._git_revparse_commit('other/feature-2', 0, 'def789'))
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        # The test passes if _git_revparse_commit is called with the
        # expected argument

    def test_sync_branch_on_unknown_remote(self):
        """Test expect branch, but remote is unknown --> status modified

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature-2'
        self._repo._tag = ''
        self._repo._url = '/path/to/unknown/repo'
        self._repo._git_log_hash = self._git_log_hash('abc123')
        self._repo._git_revparse_commit = (
            self._git_revparse_commit('unknown_remote/feature-2', 1, ''))
        self._repo._check_sync_logic(stat, self.TMP_FAKE_DIR)
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_sync_branch_on_untracked_local(self):
        """Test expect branch, on untracked branch in local repo --> status ok

        Setting the externals description to '.' indicates that the
        user only wants to consider the current local repo state
        without fetching from remotes. This is required to preserve
        the current branch of a repository during an update.

        """
        stat = ExternalStatus()
        self._repo._git_remote_verbose = self._git_remote_origin_upstream
        self._repo._branch = 'feature3'
        self._repo._tag = ''
        self._repo._url = '.'
        self._repo._git_log_hash = self._git_log_hash('abc123')
        self._repo._git_revparse_commit = (
            self._git_revparse_commit('feature3', 0, 'abc123'))
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

        self._tracking_tmpl = string.Template(
            '* feature-2 36418b4 [$ref] Work on feature-2')

    #
    # RE_DETACHED_AT
    #
    def test_re_detached_alphnum(self):
        """Test re correctly matches alphnumeric (basic debugging)
        """
        value = 'feature2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED_AT.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_detached_underscore(self):
        """Test re matches with underscore
        """
        value = 'feature_2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED_AT.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_detached_hyphen(self):
        """Test re matches -
        """
        value = 'feature-2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED_AT.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_detached_period(self):
        """Test re matches .
        """
        value = 'feature.2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED_AT.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), value)

    def test_re_detached_slash(self):
        """Test re matches /
        """
        value = 'feature/2'
        input_str = self._detached_git_v2_tmpl.substitute(ref=value)
        match = GitRepository.RE_DETACHED_AT.search(input_str)
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

    def test_re_tracking_colon(self):
        """Test re rejects names with colons because they are invalid for git
        tag and branch names

        """
        value = 'feature:2'
        input_str = self._tracking_tmpl.substitute(ref=value)
        match = GitRepository.RE_TRACKING.search(input_str)
        self.assertIsNone(match)

    def test_re_tracking_ahead(self):
        """Test re matches correctly with the ': ahead' syntax from git
        """
        value = 'feature-2: ahead 3'
        input_str = self._tracking_tmpl.substitute(ref=value)
        match = GitRepository.RE_TRACKING.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), 'feature-2')

    def test_re_tracking_ahead_behind(self):
        """Test re matches correctly with the ': ahead 3, behind 2' syntax
        from git

        """
        value = 'feature-2: ahead 3, behind 2'
        input_str = self._tracking_tmpl.substitute(ref=value)
        match = GitRepository.RE_TRACKING.search(input_str)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), 'feature-2')


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
                       ExternalsDescription.BRANCH: EMPTY_STR,
                       ExternalsDescription.HASH: EMPTY_STR, }
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

    @staticmethod
    def _mock_function_true(ref):
        _ = ref
        return (TestValidRef._shell_true, '97ebc0e0deadc0de')

    @staticmethod
    def _mock_function_false(ref):
        _ = ref
        return (TestValidRef._shell_false, '97ebc0e0deadc0de')

    def test_tag_not_tag_branch_commit(self):
        """Verify a non-tag returns false
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._mock_function_false
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
        self._repo._git_revparse_commit = self._mock_function_false
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
        self._repo._git_revparse_commit = self._mock_function_true
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
        self._repo._git_revparse_commit = self._mock_function_true
        self._repo._tag = 'tag1'
        remote_name = 'origin'
        received, _ = self._repo._is_unique_tag(self._repo._tag, remote_name)
        self.assertTrue(received)

    def test_tag_is_not_hash(self):
        """Verify a commit hash is not classified as a tag
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._mock_function_true
        self._repo._tag = '97ebc0e0'
        remote_name = 'origin'
        received, _ = self._repo._is_unique_tag(self._repo._tag, remote_name)
        self.assertFalse(received)

    def test_hash_is_commit(self):
        """Verify a commit hash is not classified as a tag
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._mock_function_true
        self._repo._tag = '97ebc0e0'
        remote_name = 'origin'
        received, _ = self._repo._is_unique_tag(self._repo._tag, remote_name)
        self.assertFalse(received)


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

    @staticmethod
    def _mock_function_false(ref):
        _ = ref
        return (TestValidRef._shell_false, '')

    @staticmethod
    def _mock_function_true(ref):
        _ = ref
        return (TestValidRef._shell_true, '')

    def test_valid_ref_is_invalid(self):
        """Verify an invalid reference raises an exception
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._mock_function_false
        self._repo._tag = 'invalid_ref'
        with self.assertRaises(RuntimeError):
            self._repo._check_for_valid_ref(self._repo._tag)

    def test_valid_tag(self):
        """Verify a valid tag return true
        """
        self._repo._git_showref_tag = self._shell_true
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._mock_function_true
        self._repo._tag = 'tag1'
        received = self._repo._check_for_valid_ref(self._repo._tag)
        self.assertTrue(received)

    def test_valid_branch(self):
        """Verify a valid tag return true
        """
        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_true
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = self._mock_function_true
        self._repo._tag = 'tag1'
        received = self._repo._check_for_valid_ref(self._repo._tag)
        self.assertTrue(received)

    def test_valid_hash(self):
        """Verify a valid hash return true
        """
        def _mock_revparse_commit(ref):
            _ = ref
            return (0, '56cc0b539426eb26810af9e')

        self._repo._git_showref_tag = self._shell_false
        self._repo._git_showref_branch = self._shell_false
        self._repo._git_lsremote_branch = self._shell_false
        self._repo._git_revparse_commit = _mock_revparse_commit
        self._repo._hash = '56cc0b5394'
        received = self._repo._check_for_valid_ref(self._repo._hash)
        self.assertTrue(received)


if __name__ == '__main__':
    unittest.main()
