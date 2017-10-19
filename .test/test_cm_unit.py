#!/usr/bin/env python

"""Unit test driver for checkout_model

Note: this script assume the path to the checkout_model.py module is
already in the python path.

"""

from __future__ import print_function

import string
import os
import shutil
import unittest
import xml.etree.ElementTree as etree

import checkout_model

from checkout_model import ModelDescription, Status, EMPTY_STR


class TestCreateRepositoryDict(unittest.TestCase):
    """Test the create_repository functionality to ensure it returns the
    propper type of repository and errors for unknown repository
    types.

    """

    def setUp(self):
        """Common data needed for all tests in this class
        """
        self._name = u'test_name'
        self._repo = {ModelDescription.PROTOCOL: None,
                      ModelDescription.REPO_URL: u'junk_root',
                      ModelDescription.TAG: u'junk_tag',
                      ModelDescription.BRANCH: EMPTY_STR, }

    def test_create_repo_git(self):
        """Verify that several possible names for the 'git' protocol
        create git repository objects.

        """
        protocols = [u'git', u'GIT', u'Git', ]
        for protocol in protocols:
            self._repo[ModelDescription.PROTOCOL] = protocol
            repo = checkout_model.create_repository(self._name, self._repo)
            self.assertIsInstance(repo, checkout_model.GitRepository)

    def test_create_repo_svn(self):
        """Verify that several possible names for the u'svn' protocol
        create svn repository objects.
        """
        protocols = [u'svn', u'SVN', u'Svn', ]
        for protocol in protocols:
            self._repo[ModelDescription.PROTOCOL] = protocol
            repo = checkout_model.create_repository(self._name, self._repo)
            self.assertIsInstance(repo, checkout_model.SvnRepository)

    def test_create_repo_externals_only(self):
        """Verify that an externals only repo returns None.
        """
        protocols = [u'externals_only', ]
        for protocol in protocols:
            self._repo[ModelDescription.PROTOCOL] = protocol
            repo = checkout_model.create_repository(self._name, self._repo)
            self.assertEqual(None, repo)

    def test_create_repo_unsupported(self):
        """Verify that an unsupported protocol generates a runtime error.
        """
        protocols = [u'not_a_supported_protocol', ]
        for protocol in protocols:
            self._repo[ModelDescription.PROTOCOL] = protocol
            with self.assertRaises(RuntimeError):
                checkout_model.create_repository(self._name, self._repo)


class TestRepository(unittest.TestCase):
    """Test the xml processing used to create the Repository base class
    shared by protocol specific repository classes.

    """

    def test_tag(self):
        """Test creation of a repository object with a tag
        """
        name = u'test_repo'
        protocol = u'test_protocol'
        url = u'test_url'
        tag = u'test_tag'
        repo_info = {ModelDescription.PROTOCOL: protocol,
                     ModelDescription.REPO_URL: url,
                     ModelDescription.TAG: tag,
                     ModelDescription.BRANCH: EMPTY_STR, }
        repo = checkout_model.Repository(name, repo_info)
        print(repo.__dict__)
        self.assertEqual(repo.tag(), tag)
        self.assertEqual(repo.url(), url)

    def test_branch(self):
        """Test creation of a repository object with a branch
        """
        name = u'test_repo'
        protocol = u'test_protocol'
        url = u'test_url'
        branch = u'test_branch'
        repo_info = {ModelDescription.PROTOCOL: protocol,
                     ModelDescription.REPO_URL: url,
                     ModelDescription.BRANCH: branch,
                     ModelDescription.TAG: EMPTY_STR, }
        repo = checkout_model.Repository(name, repo_info)
        print(repo.__dict__)
        self.assertEqual(repo.branch(), branch)
        self.assertEqual(repo.url(), url)

    def test_tag_branch(self):
        """Test creation of a repository object with a tag and branch raises a
        runtimer error.

        """
        name = u'test_repo'
        protocol = u'test_protocol'
        url = u'test_url'
        branch = u'test_branch'
        tag = u'test_tag'
        repo_info = {ModelDescription.PROTOCOL: protocol,
                     ModelDescription.REPO_URL: url,
                     ModelDescription.BRANCH: branch,
                     ModelDescription.TAG: tag, }
        with self.assertRaises(RuntimeError):
            checkout_model.Repository(name, repo_info)

    def test_no_tag_no_branch(self):
        """Test creation of a repository object without a tag or branch raises a
        runtimer error.

        """
        name = u'test_repo'
        protocol = u'test_protocol'
        url = u'test_url'
        branch = EMPTY_STR
        tag = EMPTY_STR
        repo_info = {ModelDescription.PROTOCOL: protocol,
                     ModelDescription.REPO_URL: url,
                     ModelDescription.BRANCH: branch,
                     ModelDescription.TAG: tag, }
        with self.assertRaises(RuntimeError):
            checkout_model.Repository(name, repo_info)


class TestXMLSchemaVersion(unittest.TestCase):
    """Test that schema identification for sourcetree xml returns the
correct results.

    """

    def setUp(self):
        """Reusable xml string
        """
        self._xml_sourcetree = string.Template(
            u"""
            <config_sourcetree version="$version">
            </config_sourcetree>
            """)

    def test_schema_version_valid(self):
        """Test that schema identification returns the correct version for a
        valid tag.

        """
        version_str = '2.1.3'
        xml_str = self._xml_sourcetree.substitute(version=version_str)
        xml_root = etree.fromstring(xml_str)
        received = ModelDescription.get_xml_schema_version(
            xml_root)
        expected_version = version_str.split('.')
        self.assertEqual(expected_version, received)

    def test_schema_version_missing(self):
        """Test that config_sourcetree xml without a version string raises
        a runtime error.

        """
        xml_str = u'<config_sourcetree >comp1</config_sourcetree>'
        xml_root = etree.fromstring(xml_str)
        with self.assertRaises(RuntimeError):
            ModelDescription.get_xml_schema_version(xml_root)


class TestModelDescritionXMLv1(unittest.TestCase):
    """Test that parsing an xml version 1 produces a correct dictionary
    for the model description.
    """

    def setUp(self):
        """Setup reusable xml strings for tests.
        """
        self._xml_sourcetree = string.Template(u"""<config_sourcetree version="1.0.0">
$source
$required
</config_sourcetree>""")
        self._xml_source = string.Template(u"""    <source name='$name'>
        <TREE_PATH>$path</TREE_PATH> $repo
    </source>""")

        self._xml_repo_tag = string.Template(u"""
        <repo protocol='$protocol'>
            <ROOT>$url</ROOT>
            <TAG>$tag</TAG>
        </repo>""")

        self._xml_repo_branch = string.Template(u"""
        <repo protocol='$protocol'>
            <ROOT>$url</ROOT>
            <BRANCH>$branch</BRANCH>
        </repo>""")
        self._xml_required = string.Template(u"""    <required>
$req
    </required>""")
        self._xml_req_source = string.Template(
            u"""        <REQ_SOURCE>$name</REQ_SOURCE>""")
        self._setup_comp1()
        self._setup_comp2()

    def _setup_comp1(self):
        """Reusable setup of component one
        """
        self._comp1_name = u'comp1'
        self._comp1_path = u'path/to/comp1'
        self._comp1_protocol = u'proto1'
        self._comp1_url = u'/local/clone/of/comp1'
        self._comp1_tag = u'a_nice_tag_v1'
        self._comp1_is_required = True
        repo = self._xml_repo_tag.substitute(protocol=self._comp1_protocol,
                                             url=self._comp1_url,
                                             tag=self._comp1_tag)
        self._comp1_source = self._xml_source.substitute(name=self._comp1_name,
                                                         path=self._comp1_path,
                                                         repo=repo)
        req_src = self._xml_req_source.substitute(name=self._comp1_name)
        self._comp1_required = self._xml_required.substitute(req=req_src)

    def _setup_comp2(self):
        """Reusable setup of componet two
        """
        self._comp2_name = u'comp2'
        self._comp2_path = u'path/to/comp2'
        self._comp2_protocol = u'proto2'
        self._comp2_url = u'/local/clone/of/comp2'
        self._comp2_branch = u'a_very_nice_branch'
        self._comp2_is_required = False
        repo = self._xml_repo_branch.substitute(protocol=self._comp2_protocol,
                                                url=self._comp2_url,
                                                branch=self._comp2_branch)
        self._comp2_source = self._xml_source.substitute(name=self._comp2_name,
                                                         path=self._comp2_path,
                                                         repo=repo)
        self._comp2_required = ''

    def _check_comp1(self, model):
        """Test that component one was correctly built.
        """
        self.assertTrue(self._comp1_name in model)
        comp1 = model[self._comp1_name]
        self.assertEqual(comp1[ModelDescription.PATH], self._comp1_path)
        self.assertEqual(comp1[ModelDescription.REQUIRED],
                         self._comp1_is_required)
        repo = comp1[ModelDescription.REPO]
        self.assertEqual(repo[ModelDescription.PROTOCOL],
                         self._comp1_protocol)
        self.assertEqual(repo[ModelDescription.REPO_URL], self._comp1_url)
        self.assertEqual(repo[ModelDescription.TAG], self._comp1_tag)

    def _check_comp2(self, model):
        """Test that component two was correctly constructed.
        """
        self.assertTrue(self._comp2_name in model)
        comp2 = model[self._comp2_name]
        self.assertEqual(comp2[ModelDescription.PATH], self._comp2_path)
        self.assertEqual(comp2[ModelDescription.REQUIRED],
                         self._comp2_is_required)
        repo = comp2[ModelDescription.REPO]
        self.assertEqual(repo[ModelDescription.PROTOCOL],
                         self._comp2_protocol)
        self.assertEqual(repo[ModelDescription.REPO_URL], self._comp2_url)
        self.assertEqual(repo[ModelDescription.BRANCH], self._comp2_branch)

    def test_one_tag(self):
        """Test that a component source with a tag is correctly parsed.
        """
        xml_str = self._xml_sourcetree.substitute(
            source=self._comp1_source, required=self._comp1_required)
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        model = ModelDescription(u'xml', xml_root)
        print(model)
        self._check_comp1(model)

    def test_one_branch(self):
        """Test that a component source with a branch is correctly parsed
        """
        xml_str = self._xml_sourcetree.substitute(
            source=self._comp2_source, required=self._comp2_required)
        xml_root = etree.fromstring(xml_str)
        model = ModelDescription(u'xml', xml_root)
        print(model)
        self._check_comp2(model)

    def test_two(self):
        """Test that two component sources are correctly parsed
        """
        src_str = "{0}\n{1}".format(self._comp1_source, self._comp2_source)
        req_str = self._comp1_required
        xml_str = self._xml_sourcetree.substitute(source=src_str,
                                                  required=req_str)
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        model = ModelDescription(u'xml', xml_root)
        print(model)
        self._check_comp1(model)
        self._check_comp2(model)


class TestModelDescritionXMLv2(unittest.TestCase):
    """Test that parsing an xml version 2 produces a correct dictionary
    for the model description.

    """

    def setUp(self):
        """Boiler plate construction of string containing xml for multiple components.
        """
        self._xml_sourcetree = string.Template(u"""<config_sourcetree version="2.0.0">
$source
</config_sourcetree>""")
        self._xml_source = string.Template(u"""    <source name='$name' required='$required'>
        <path>$path</path> $repo
        $externals
    </source>""")

        self._xml_repo_tag = string.Template(u"""
        <repo protocol='$protocol'>
            <repo_url>$url</repo_url>
            <tag>$tag</tag>
        </repo>""")

        self._xml_repo_branch = string.Template(u"""
        <repo protocol='$protocol'>
            <repo_url>$url</repo_url>
            <branch>$branch</branch>
        </repo>""")

        self._xml_externals = string.Template(
            u"""<externals>$name</externals>""")
        self._setup_comp1()
        self._setup_comp2()

    def _setup_comp1(self):
        """Boiler plate construction of xml string for componet 1
        """
        self._comp1_name = u'comp1'
        self._comp1_path = u'path/to/comp1'
        self._comp1_protocol = u'proto1'
        self._comp1_url = u'/local/clone/of/comp1'
        self._comp1_tag = u'a_nice_tag_v1'
        self._comp1_is_required = True
        self._comp1_externals = ''
        repo = self._xml_repo_tag.substitute(protocol=self._comp1_protocol,
                                             url=self._comp1_url,
                                             tag=self._comp1_tag)
        self._comp1_source = self._xml_source.substitute(
            name=self._comp1_name, path=self._comp1_path,
            repo=repo, required=self._comp1_is_required,
            externals=self._comp1_externals)

    def _setup_comp2(self):
        """Boiler plate construction of xml string for componet 2
        """
        self._comp2_name = u'comp2'
        self._comp2_path = u'path/to/comp2'
        self._comp2_protocol = u'proto2'
        self._comp2_url = u'/local/clone/of/comp2'
        self._comp2_branch = u'a_very_nice_branch'
        self._comp2_is_required = False
        self._comp2_externals_name = u'comp2.xml'
        self._comp2_externals = self._xml_externals.substitute(
            name=self._comp2_externals_name)
        repo = self._xml_repo_branch.substitute(protocol=self._comp2_protocol,
                                                url=self._comp2_url,
                                                branch=self._comp2_branch)
        self._comp2_source = self._xml_source.substitute(
            name=self._comp2_name, path=self._comp2_path,
            repo=repo, required=self._comp2_is_required,
            externals=self._comp2_externals)

    def _check_comp1(self, model):
        """Test that component one was constructed correctly.
        """
        self.assertTrue(self._comp1_name in model)
        comp1 = model[self._comp1_name]
        self.assertEqual(comp1[ModelDescription.PATH], self._comp1_path)
        self.assertEqual(comp1[ModelDescription.REQUIRED],
                         self._comp1_is_required)
        repo = comp1[ModelDescription.REPO]
        self.assertEqual(repo[ModelDescription.PROTOCOL],
                         self._comp1_protocol)
        self.assertEqual(repo[ModelDescription.REPO_URL], self._comp1_url)
        self.assertEqual(repo[ModelDescription.TAG], self._comp1_tag)
        self.assertEqual(EMPTY_STR, comp1[ModelDescription.EXTERNALS])

    def _check_comp2(self, model):
        """Test that component two was constucted correctly.
        """
        self.assertTrue(self._comp2_name in model)
        comp2 = model[self._comp2_name]
        self.assertEqual(comp2[ModelDescription.PATH], self._comp2_path)
        self.assertEqual(comp2[ModelDescription.REQUIRED],
                         self._comp2_is_required)
        repo = comp2[ModelDescription.REPO]
        self.assertEqual(repo[ModelDescription.PROTOCOL],
                         self._comp2_protocol)
        self.assertEqual(repo[ModelDescription.REPO_URL], self._comp2_url)
        self.assertEqual(repo[ModelDescription.BRANCH], self._comp2_branch)
        self.assertEqual(self._comp2_externals_name,
                         comp2[ModelDescription.EXTERNALS])

    def test_one_tag_required(self):
        """Test that a component source with a tag is correctly parsed.
        """
        xml_str = self._xml_sourcetree.substitute(source=self._comp1_source)
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        model = ModelDescription(u'xml', xml_root)
        print(model)
        self._check_comp1(model)

    def test_one_branch_externals(self):
        """Test that a component source with a branch is correctly parsed.
        """
        xml_str = self._xml_sourcetree.substitute(source=self._comp2_source)
        xml_root = etree.fromstring(xml_str)
        model = ModelDescription(u'xml', xml_root)
        print(model)
        self._check_comp2(model)

    def test_two_sources(self):
        """Test that multiple component sources are correctly parsed.
        """
        src_str = "{0}\n{1}".format(self._comp1_source, self._comp2_source)
        xml_str = self._xml_sourcetree.substitute(source=src_str)
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        model = ModelDescription(u'xml', xml_root)
        print(model)
        self._check_comp1(model)
        self._check_comp2(model)

    @unittest.skip("Haven't figured out how to make this fail yet.")
    def test_invalid(self):
        """Test that an invalid xml string raises a runtime exception.
        """
        xml_str = """<source name="comp1" required="False">
<repo protocol='git'><url>/path</url></repo>
</source>"""
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        with self.assertRaises(RuntimeError):
            ModelDescription(u'xml', xml_root)

SVN_INFO_MOSART = u"""Path: components/mosart
Working Copy Root Path: /Users/andreb/projects/ncar/git-conversion/clm-dev-experimental/components/mosart
URL: https://svn-ccsm-models.cgd.ucar.edu/mosart/trunk_tags/mosart1_0_26
Relative URL: ^/mosart/trunk_tags/mosart1_0_26
Repository Root: https://svn-ccsm-models.cgd.ucar.edu
Repository UUID: fe37f545-8307-0410-aea5-b40df96820b5
Revision: 86711
Node Kind: directory
Schedule: normal
Last Changed Author: erik
Last Changed Rev: 86031
Last Changed Date: 2017-07-07 12:28:10 -0600 (Fri, 07 Jul 2017)
"""
SVN_INFO_CISM = u"""
Path: components/cism
Working Copy Root Path: /Users/andreb/projects/ncar/git-conversion/clm-dev-experimental/components/cism
URL: https://svn-ccsm-models.cgd.ucar.edu/glc/trunk_tags/cism2_1_37
Relative URL: ^/glc/trunk_tags/cism2_1_37
Repository Root: https://svn-ccsm-models.cgd.ucar.edu
Repository UUID: fe37f545-8307-0410-aea5-b40df96820b5
Revision: 86711
Node Kind: directory
Schedule: normal
Last Changed Author: sacks
Last Changed Rev: 85704
Last Changed Date: 2017-06-15 05:59:28 -0600 (Thu, 15 Jun 2017)
"""

class TestSvnRepositoryCheckURL(unittest.TestCase):
    """
    """

    def setUp(self):
        """Setup reusable svn repository object
        """
        self._name = u'component'
        rdata = {checkout_model.ModelDescription.PROTOCOL: u'svn',
                 checkout_model.ModelDescription.REPO_URL:
                     u'https://svn-ccsm-models.cgd.ucar.edu/',
                 checkout_model.ModelDescription.TAG:
                     u'mosart/trunk_tags/mosart1_0_26',
                 checkout_model.ModelDescription.BRANCH: u''
        }

        data = {self._name:
                {
                    checkout_model.ModelDescription.REQUIRED: False,
                    checkout_model.ModelDescription.PATH: u'junk',
                    checkout_model.ModelDescription.EXTERNALS: u'',
                    checkout_model.ModelDescription.REPO: rdata,
                },
        }

        model = checkout_model.ModelDescription(u'json', data)
        repo = model[self._name][checkout_model.ModelDescription.REPO]
        self._repo = checkout_model.SvnRepository(u'test', repo)

    def test_check_url_same(self):
        """Test that we correctly identify that the correct URL.
        """
        svn_output = SVN_INFO_MOSART
        expected_url = self._repo._url
        result = self._repo.svn_check_url(svn_output, expected_url)
        self.assertEqual(result, Status.OK)

    def test_check_url_different(self):
        """Test that we correctly reject an incorrect URL.
        """
        svn_output = SVN_INFO_CISM
        expected_url = self._repo._url
        result = self._repo.svn_check_url(svn_output, expected_url)
        self.assertEqual(result, Status.MODIFIED)

    def test_check_url_none(self):
        """Test that we can handle an empty string for output, e.g. not an svn
        repo.

        """
        svn_output = EMPTY_STR
        expected_url = self._repo._url
        result = self._repo.svn_check_url(svn_output, expected_url)
        self.assertEqual(result, Status.UNKNOWN)


class TestSvnRepositoryCheckSync(unittest.TestCase):
    """Test whether the SvnRepository svn_check_sync functionality is
    correct.

    """
    def setUp(self):
        """Setup reusable svn repository object
        """
        self._name = "component"
        rdata = {checkout_model.ModelDescription.PROTOCOL: u'svn',
                 checkout_model.ModelDescription.REPO_URL:
                     u'https://svn-ccsm-models.cgd.ucar.edu/',
                 checkout_model.ModelDescription.TAG:
                     u'mosart/trunk_tags/mosart1_0_26',
                 checkout_model.ModelDescription.BRANCH: EMPTY_STR
        }

        data = {self._name:
                {
                    checkout_model.ModelDescription.REQUIRED: False,
                    checkout_model.ModelDescription.PATH: u'junk',
                    checkout_model.ModelDescription.EXTERNALS: EMPTY_STR,
                    checkout_model.ModelDescription.REPO: rdata,
                },
        }

        model = checkout_model.ModelDescription('json', data)
        repo = model[self._name][checkout_model.ModelDescription.REPO]
        self._repo = checkout_model.SvnRepository('test', repo)

    @staticmethod
    def _svn_info_empty(repo_dir):
        """Return an empty info string. Simulates svn info failing.
        """
        return ''

    @staticmethod
    def _svn_info_synced(repo_dir):
        """Return an info sting that is synced with the setUp data
        """
        return SVN_INFO_MOSART

    @staticmethod
    def _svn_info_modified(repo_dir):
        """Return and info string that is modified from the setUp data
        """
        return SVN_INFO_CISM

    def test_repo_dir_not_exist(self):
        """Test that a directory that doesn't exist returns an empty status
        """
        stat = Status()
        self._repo.svn_check_sync(stat, u'junk')
        self.assertEqual(stat.sync_state, Status.EMPTY)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, Status.DEFAULT)

    def test_repo_dir_exist_no_svn_info(self):
        """Test that an empty info string returns an unknown status
        """
        stat = Status()
        # Now we over-ride the _svn_info method on the repo to return
        # a known value without requiring access to svn.
        self._repo._svn_info = self._svn_info_empty
        self._repo.svn_check_sync(stat, u'.')
        self.assertEqual(stat.sync_state, Status.UNKNOWN)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, Status.DEFAULT)

    def test_repo_dir_synced(self):
        """Test that a valid info string that is synced to the repo in the
        model description returns an ok status.

        """
        stat = Status()
        # Now we over-ride the _svn_info method on the repo to return
        # a known value without requiring access to svn.
        self._repo._svn_info = self._svn_info_synced
        self._repo.svn_check_sync(stat, u'.')
        self.assertEqual(stat.sync_state, Status.OK)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, Status.DEFAULT)

    def test_repo_dir_modified(self):
        """Test that a valid svn info string that is out of sync with the
        model description returns a modified status.

        """
        stat = Status()
        # Now we over-ride the _svn_info method on the repo to return
        # a known value without requiring access to svn.
        self._repo._svn_info = self._svn_info_modified
        self._repo.svn_check_sync(stat, u'.')
        self.assertEqual(stat.sync_state, Status.MODIFIED)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, Status.DEFAULT)


class TestGitRepositoryCurrentRefBranch(unittest.TestCase):
    """test the current_ref_from_branch_command on a git repository
    """
    GIT_BRANCH_OUTPUT_DETACHED_TAG = u'''
* (HEAD detached at rtm1_0_26)
  a_feature_branch
  master
'''
    GIT_BRANCH_OUTPUT_BRANCH = u'''
* great_new_feature_branch
  a_feature_branch
  master
'''
    GIT_BRANCH_OUTPUT_HASH = u'''
* (HEAD detached at 0246874c)
  a_feature_branch
  master
'''

    def setUp(self):
        self._name = u'component'
        rdata = {checkout_model.ModelDescription.PROTOCOL: u'git',
                 checkout_model.ModelDescription.REPO_URL:
                     u'git@git.github.com:ncar/rtm',
                 checkout_model.ModelDescription.TAG:
                     u'rtm1_0_26',
                 checkout_model.ModelDescription.BRANCH: EMPTY_STR
        }

        data = {self._name:
                {
                    checkout_model.ModelDescription.REQUIRED: False,
                    checkout_model.ModelDescription.PATH: u'junk',
                    checkout_model.ModelDescription.EXTERNALS: EMPTY_STR,
                    checkout_model.ModelDescription.REPO: rdata,
                },
        }

        model = checkout_model.ModelDescription('json', data)
        repo = model[self._name][checkout_model.ModelDescription.REPO]
        self._repo = checkout_model.GitRepository('test', repo)

    def test_ref_detached_from_tag(self):
        """Test that we correctly identify that the ref is detached from a tag
        """
        git_output = self.GIT_BRANCH_OUTPUT_DETACHED_TAG
        expected = self._repo._tag
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
        expected = u'0246874c'
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
    TMP_GIT_DIR = u'fake/.git'

    def setUp(self):
        """Setup reusable git repository object
        """
        self._name = u'component'
        rdata = {checkout_model.ModelDescription.PROTOCOL: u'git',
                 checkout_model.ModelDescription.REPO_URL:
                     u'git@git.github.com:ncar/rtm',
                 checkout_model.ModelDescription.TAG:
                     u'rtm1_0_26',
                 checkout_model.ModelDescription.BRANCH: EMPTY_STR
        }

        data = {self._name:
                {
                    checkout_model.ModelDescription.REQUIRED: False,
                    checkout_model.ModelDescription.PATH: u'fake',
                    checkout_model.ModelDescription.EXTERNALS: u'',
                    checkout_model.ModelDescription.REPO: rdata,
                },
        }

        model = checkout_model.ModelDescription(u'json', data)
        repo = model[self._name][checkout_model.ModelDescription.REPO]
        self._repo = checkout_model.GitRepository(u'test', repo)
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
        git_output = u'''
* (HEAD detached at rtm1_0_26)
  a_feature_branch
  master
'''
        return git_output

    @staticmethod
    def _git_branch_modified():
        """Return and info string that is modified from the setUp data
        """
        git_output = u'''
* great_new_feature_branch
  a_feature_branch
  master
'''
        return git_output

    def test_repo_dir_not_exist(self):
        """Test that a directory that doesn't exist returns an empty status
        """
        stat = Status()
        self._repo.git_check_sync(stat, u'junk')
        self.assertEqual(stat.sync_state, Status.EMPTY)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, Status.DEFAULT)

    def test_repo_dir_exist_no_git_info(self):
        """Test that an empty info string returns an unknown status
        """
        stat = Status()
        # Now we over-ride the _git_branch method on the repo to return
        # a known value without requiring access to git.
        self._repo._git_branch = self._git_branch_empty
        self._repo.git_check_sync(stat, u'fake')
        self.assertEqual(stat.sync_state, Status.UNKNOWN)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, Status.DEFAULT)

    def test_repo_dir_synced(self):
        """Test that a valid info string that is synced to the repo in the
        model description returns an ok status.

        """
        stat = Status()
        # Now we over-ride the _git_branch method on the repo to return
        # a known value without requiring access to svn.
        self._repo._git_branch = self._git_branch_synced
        self._repo.git_check_sync(stat, u'fake')
        self.assertEqual(stat.sync_state, Status.OK)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, Status.DEFAULT)

    def test_repo_dir_modified(self):
        """Test that a valid svn info string that is out of sync with the
        model description returns a modified status.

        """
        stat = Status()
        # Now we over-ride the _svn_info method on the repo to return
        # a known value without requiring access to svn.
        self._repo._git_branch = self._git_branch_modified
        self._repo.git_check_sync(stat, u'fake')
        self.assertEqual(stat.sync_state, Status.MODIFIED)
        # check_sync should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, Status.DEFAULT)

if __name__ == '__main__':
    unittest.main()
