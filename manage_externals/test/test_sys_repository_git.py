#!/usr/bin/env python

"""Tests of some of the functionality in repository_git.py that actually
interacts with git repositories.

We're calling these "system" tests because we expect them to be a lot
slower than most of the unit tests.

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import os
import shutil
import tempfile
import unittest

from manic.repository_git import GitRepository
from manic.externals_description import ExternalsDescription
from manic.externals_description import ExternalsDescriptionDict
from manic.utils import execute_subprocess

# NOTE(wjs, 2018-04-09) I find a mix of camel case and underscores to be
# more readable for unit test names, so I'm disabling pylint's naming
# convention check
# pylint: disable=C0103

# Allow access to protected members
# pylint: disable=W0212


class GitTestCase(unittest.TestCase):
    """Adds some git-specific unit test functionality on top of TestCase"""

    def assertIsHash(self, maybe_hash):
        """Assert that the string given by maybe_hash really does look
        like a git hash.
        """

        # Ensure it is non-empty
        self.assertTrue(maybe_hash, msg="maybe_hash is empty")

        # Ensure it has a single string
        self.assertEqual(1, len(maybe_hash.split()),
                         msg="maybe_hash has multiple strings: {}".format(maybe_hash))

        # Ensure that the only characters in the string are ones allowed
        # in hashes
        allowed_chars_set = set('0123456789abcdef')
        self.assertTrue(set(maybe_hash) <= allowed_chars_set,
                        msg="maybe_hash has non-hash characters: {}".format(maybe_hash))


class TestGitTestCase(GitTestCase):
    """Tests GitTestCase"""

    def test_assertIsHash_true(self):
        """Ensure that assertIsHash passes for something that looks
        like a hash"""
        self.assertIsHash('abc123')

    def test_assertIsHash_empty(self):
        """Ensure that assertIsHash raises an AssertionError for an
        empty string"""
        with self.assertRaises(AssertionError):
            self.assertIsHash('')

    def test_assertIsHash_multipleStrings(self):
        """Ensure that assertIsHash raises an AssertionError when
        given multiple strings"""
        with self.assertRaises(AssertionError):
            self.assertIsHash('abc123 def456')

    def test_assertIsHash_badChar(self):
        """Ensure that assertIsHash raises an AssertionError when given a
        string that has a character that doesn't belong in a hash
        """
        with self.assertRaises(AssertionError):
            self.assertIsHash('abc123g')


class TestGitRepositoryGitCommands(GitTestCase):
    """Test some git commands in RepositoryGit

    It's silly that we need to create a repository in order to test
    these git commands. Much or all of the git functionality that is
    currently in repository_git.py should eventually be moved to a
    separate module that is solely responsible for wrapping git
    commands; that would allow us to test it independently of this
    repository class.
    """

    # ========================================================================
    # Test helper functions
    # ========================================================================

    def setUp(self):
        # directory we want to return to after the test system and
        # checkout_externals are done cd'ing all over the place.
        self._return_dir = os.getcwd()

        self._tmpdir = tempfile.mkdtemp()
        os.chdir(self._tmpdir)

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
                    ExternalsDescription.EXTERNALS: '',
                    ExternalsDescription.REPO: rdata,
                },
                }
        model = ExternalsDescriptionDict(data)
        repo = model[self._name][ExternalsDescription.REPO]
        self._repo = GitRepository('test', repo)

    def tearDown(self):
        # return to our common starting point
        os.chdir(self._return_dir)

        shutil.rmtree(self._tmpdir, ignore_errors=True)

    @staticmethod
    def make_git_repo():
        """Turn the current directory into an empty git repository"""
        execute_subprocess(['git', 'init'])

    @staticmethod
    def add_git_commit():
        """Add a git commit in the current directory"""
        with open('README', 'a') as myfile:
            myfile.write('more info')
        execute_subprocess(['git', 'add', 'README'])
        execute_subprocess(['git', 'commit', '-m', 'my commit message'])

    @staticmethod
    def checkout_git_branch(branchname):
        """Checkout a new branch in the current directory"""
        execute_subprocess(['git', 'checkout', '-b', branchname])

    @staticmethod
    def make_git_tag(tagname):
        """Make a lightweight tag at the current commit"""
        execute_subprocess(['git', 'tag', '-m', 'making a tag', tagname])

    @staticmethod
    def checkout_ref(refname):
        """Checkout the given refname in the current directory"""
        execute_subprocess(['git', 'checkout', refname])

    # ========================================================================
    # Begin actual tests
    # ========================================================================

    def test_currentHash_returnsHash(self):
        """Ensure that the _git_current_hash function returns a hash"""
        self.make_git_repo()
        self.add_git_commit()
        hash_found, myhash = self._repo._git_current_hash()
        self.assertTrue(hash_found)
        self.assertIsHash(myhash)

    def test_currentHash_outsideGitRepo(self):
        """Ensure that the _git_current_hash function returns False when
        outside a git repository"""
        hash_found, myhash = self._repo._git_current_hash()
        self.assertFalse(hash_found)
        self.assertEqual('', myhash)

    def test_currentBranch_onBranch(self):
        """Ensure that the _git_current_branch function returns the name
        of the branch"""
        self.make_git_repo()
        self.add_git_commit()
        self.checkout_git_branch('foo')
        branch_found, mybranch = self._repo._git_current_branch()
        self.assertTrue(branch_found)
        self.assertEqual('foo', mybranch)

    def test_currentBranch_notOnBranch(self):
        """Ensure that the _git_current_branch function returns False
        when not on a branch"""
        self.make_git_repo()
        self.add_git_commit()
        self.make_git_tag('mytag')
        self.checkout_ref('mytag')
        branch_found, mybranch = self._repo._git_current_branch()
        self.assertFalse(branch_found)
        self.assertEqual('', mybranch)

    def test_currentBranch_outsideGitRepo(self):
        """Ensure that the _git_current_branch function returns False
        when outside a git repository"""
        branch_found, mybranch = self._repo._git_current_branch()
        self.assertFalse(branch_found)
        self.assertEqual('', mybranch)

    def test_currentTag_onTag(self):
        """Ensure that the _git_current_tag function returns the name of
        the tag"""
        self.make_git_repo()
        self.add_git_commit()
        self.make_git_tag('some_tag')
        tag_found, mytag = self._repo._git_current_tag()
        self.assertTrue(tag_found)
        self.assertEqual('some_tag', mytag)

    def test_currentTag_notOnTag(self):
        """Ensure tha the _git_current_tag function returns False when
        not on a tag"""
        self.make_git_repo()
        self.add_git_commit()
        self.make_git_tag('some_tag')
        self.add_git_commit()
        tag_found, mytag = self._repo._git_current_tag()
        self.assertFalse(tag_found)
        self.assertEqual('', mytag)

    def test_currentTag_outsideGitRepo(self):
        """Ensure that the _git_current_tag function returns False when
        outside a git repository"""
        tag_found, mytag = self._repo._git_current_tag()
        self.assertFalse(tag_found)
        self.assertEqual('', mytag)


if __name__ == '__main__':
    unittest.main()
