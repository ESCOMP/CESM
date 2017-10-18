#!/usr/bin/env python

"""Unit test driver for checkout_model

Note: this script assume the path to the checkout_model.py module is
already in the python path.

"""

from __future__ import print_function

import string
import unittest
import xml.etree.ElementTree as etree

import checkout_model

from checkout_model import ModelDescription, EMPTY_STR


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


if __name__ == '__main__':
    unittest.main()
