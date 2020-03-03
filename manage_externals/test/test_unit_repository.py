#!/usr/bin/env python

"""Unit test driver for checkout_externals

Note: this script assume the path to the checkout_externals.py module is
already in the python path.

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import unittest

from manic.repository_factory import create_repository
from manic.repository_git import GitRepository
from manic.repository_svn import SvnRepository
from manic.repository import Repository
from manic.externals_description import ExternalsDescription
from manic.global_constants import EMPTY_STR


class TestCreateRepositoryDict(unittest.TestCase):
    """Test the create_repository functionality to ensure it returns the
    propper type of repository and errors for unknown repository
    types.

    """

    def setUp(self):
        """Common data needed for all tests in this class
        """
        self._name = 'test_name'
        self._repo = {ExternalsDescription.PROTOCOL: None,
                      ExternalsDescription.REPO_URL: 'junk_root',
                      ExternalsDescription.TAG: 'junk_tag',
                      ExternalsDescription.BRANCH: EMPTY_STR,
                      ExternalsDescription.HASH: EMPTY_STR,
                      ExternalsDescription.SPARSE: EMPTY_STR, }

    def test_create_repo_git(self):
        """Verify that several possible names for the 'git' protocol
        create git repository objects.

        """
        protocols = ['git', 'GIT', 'Git', ]
        for protocol in protocols:
            self._repo[ExternalsDescription.PROTOCOL] = protocol
            repo = create_repository(self._name, self._repo)
            self.assertIsInstance(repo, GitRepository)

    def test_create_repo_svn(self):
        """Verify that several possible names for the 'svn' protocol
        create svn repository objects.
        """
        protocols = ['svn', 'SVN', 'Svn', ]
        for protocol in protocols:
            self._repo[ExternalsDescription.PROTOCOL] = protocol
            repo = create_repository(self._name, self._repo)
            self.assertIsInstance(repo, SvnRepository)

    def test_create_repo_externals_only(self):
        """Verify that an externals only repo returns None.
        """
        protocols = ['externals_only', ]
        for protocol in protocols:
            self._repo[ExternalsDescription.PROTOCOL] = protocol
            repo = create_repository(self._name, self._repo)
            self.assertEqual(None, repo)

    def test_create_repo_unsupported(self):
        """Verify that an unsupported protocol generates a runtime error.
        """
        protocols = ['not_a_supported_protocol', ]
        for protocol in protocols:
            self._repo[ExternalsDescription.PROTOCOL] = protocol
            with self.assertRaises(RuntimeError):
                create_repository(self._name, self._repo)


class TestRepository(unittest.TestCase):
    """Test the externals description processing used to create the Repository
    base class shared by protocol specific repository classes.

    """

    def test_tag(self):
        """Test creation of a repository object with a tag
        """
        name = 'test_repo'
        protocol = 'test_protocol'
        url = 'test_url'
        tag = 'test_tag'
        repo_info = {ExternalsDescription.PROTOCOL: protocol,
                     ExternalsDescription.REPO_URL: url,
                     ExternalsDescription.TAG: tag,
                     ExternalsDescription.BRANCH: EMPTY_STR,
                     ExternalsDescription.HASH: EMPTY_STR,
                     ExternalsDescription.SPARSE: EMPTY_STR, }
        repo = Repository(name, repo_info)
        print(repo.__dict__)
        self.assertEqual(repo.tag(), tag)
        self.assertEqual(repo.url(), url)

    def test_branch(self):
        """Test creation of a repository object with a branch
        """
        name = 'test_repo'
        protocol = 'test_protocol'
        url = 'test_url'
        branch = 'test_branch'
        repo_info = {ExternalsDescription.PROTOCOL: protocol,
                     ExternalsDescription.REPO_URL: url,
                     ExternalsDescription.BRANCH: branch,
                     ExternalsDescription.TAG: EMPTY_STR,
                     ExternalsDescription.HASH: EMPTY_STR,
                     ExternalsDescription.SPARSE: EMPTY_STR, }
        repo = Repository(name, repo_info)
        print(repo.__dict__)
        self.assertEqual(repo.branch(), branch)
        self.assertEqual(repo.url(), url)

    def test_hash(self):
        """Test creation of a repository object with a hash
        """
        name = 'test_repo'
        protocol = 'test_protocol'
        url = 'test_url'
        ref = 'deadc0de'
        sparse = EMPTY_STR
        repo_info = {ExternalsDescription.PROTOCOL: protocol,
                     ExternalsDescription.REPO_URL: url,
                     ExternalsDescription.BRANCH: EMPTY_STR,
                     ExternalsDescription.TAG: EMPTY_STR,
                     ExternalsDescription.HASH: ref,
                     ExternalsDescription.SPARSE: sparse, }
        repo = Repository(name, repo_info)
        print(repo.__dict__)
        self.assertEqual(repo.hash(), ref)
        self.assertEqual(repo.url(), url)

    def test_tag_branch(self):
        """Test creation of a repository object with a tag and branch raises a
        runtimer error.

        """
        name = 'test_repo'
        protocol = 'test_protocol'
        url = 'test_url'
        branch = 'test_branch'
        tag = 'test_tag'
        ref = EMPTY_STR
        sparse = EMPTY_STR
        repo_info = {ExternalsDescription.PROTOCOL: protocol,
                     ExternalsDescription.REPO_URL: url,
                     ExternalsDescription.BRANCH: branch,
                     ExternalsDescription.TAG: tag,
                     ExternalsDescription.HASH: ref,
                     ExternalsDescription.SPARSE: sparse, }
        with self.assertRaises(RuntimeError):
            Repository(name, repo_info)

    def test_tag_branch_hash(self):
        """Test creation of a repository object with a tag, branch and hash raises a
        runtimer error.

        """
        name = 'test_repo'
        protocol = 'test_protocol'
        url = 'test_url'
        branch = 'test_branch'
        tag = 'test_tag'
        ref = 'deadc0de'
        sparse = EMPTY_STR
        repo_info = {ExternalsDescription.PROTOCOL: protocol,
                     ExternalsDescription.REPO_URL: url,
                     ExternalsDescription.BRANCH: branch,
                     ExternalsDescription.TAG: tag,
                     ExternalsDescription.HASH: ref,
                     ExternalsDescription.SPARSE: sparse, }
        with self.assertRaises(RuntimeError):
            Repository(name, repo_info)

    def test_no_tag_no_branch(self):
        """Test creation of a repository object without a tag or branch raises a
        runtimer error.

        """
        name = 'test_repo'
        protocol = 'test_protocol'
        url = 'test_url'
        branch = EMPTY_STR
        tag = EMPTY_STR
        ref = EMPTY_STR
        sparse = EMPTY_STR
        repo_info = {ExternalsDescription.PROTOCOL: protocol,
                     ExternalsDescription.REPO_URL: url,
                     ExternalsDescription.BRANCH: branch,
                     ExternalsDescription.TAG: tag,
                     ExternalsDescription.HASH: ref,
                     ExternalsDescription.SPARSE: sparse, }
        with self.assertRaises(RuntimeError):
            Repository(name, repo_info)


if __name__ == '__main__':
    unittest.main()
