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


class TestCheckoutModel_create_repository_dict(unittest.TestCase):
    """Test the create_repository functionality to ensure it returns the
    propper type of repository and errors for unknown repository
    types.

    """

    def setUp(self):
        """Common data needed for all tests in this class
        """
        self._name = 'test_name'
        self._repo = {'protocol': None,
                      'url': 'junk_root',
                      'tag': 'junk_tag',
                      'branch': None, }

    def tearDown(self):
        pass

    def test_create_repo_git(self):
        """Verify that several possible names for the 'git' protocol
        create git repository objects.

        """
        protocols = ['git', 'GIT', 'Git', ]
        for protocol in protocols:
            self._repo['protocol'] = protocol
            repo = checkout_model.create_repository(self._name, self._repo)
            self.assertIsInstance(repo, checkout_model._GitRepository)

    def test_create_repo_svn(self):
        """Verify that several possible names for the 'svn' protocol
        create svn repository objects.
        """
        protocols = ['svn', 'SVN', 'Svn', ]
        for protocol in protocols:
            self._repo['protocol'] = protocol
            repo = checkout_model.create_repository(self._name, self._repo)
            self.assertIsInstance(repo, checkout_model._SvnRepository)

    def test_create_repo_externals_only(self):
        """Verify that an externals only repo returns None.
        """
        protocols = ['externals_only', ]
        for protocol in protocols:
            self._repo['protocol'] = protocol
            repo = checkout_model.create_repository(self._name, self._repo)
            self.assertEqual(None, repo)

    def test_create_repo_unsupported(self):
        """Verify that an unsupported protocol generates a runtime error.
        """
        protocols = ['not_a_supported_protocol', ]
        for protocol in protocols:
            self._repo['protocol'] = protocol
            with self.assertRaises(RuntimeError):
                checkout_model.create_repository(self._name, self._repo)


class TestCheckoutModel_Repository(unittest.TestCase):
    """Test the xml processing used to create the _Repository base class
    shared by protocol specific repository classes.

    """

    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_tag(self):
        name = 'test_repo'
        protocol = 'test_protocol'
        url = 'test_url'
        tag = 'test_tag'
        repo_info = {'protocol': protocol,
                     'url': url,
                     'tag': tag,
                     'branch': None, }
        repo = checkout_model._Repository(name, repo_info)
        print(repo.__dict__)
        self.assertEqual(repo._tag, tag)
        self.assertEqual(repo._url, url)

    def test_branch(self):
        name = 'test_repo'
        protocol = 'test_protocol'
        url = 'test_url'
        branch = 'test_branch'
        repo_info = {'protocol': protocol,
                     'url': url,
                     'branch': branch,
                     'tag': None, }
        repo = checkout_model._Repository(name, repo_info)
        print(repo.__dict__)
        self.assertEqual(repo._branch, branch)
        self.assertEqual(repo._url, url)


class TestCheckoutModel_xml_schema_version(unittest.TestCase):
    """Test the xml v1 schema processing used to create the dictionaries
    passed into the various source and repo classes.

    """

    def setUp(self):
        self._xml_sourcetree = string.Template(
            """
            <config_sourcetree version="$version">
            </config_sourcetree>
            """)

    def tearDown(self):
        pass

    def test_get_xml_schema_version_valid(self):
        """
        """
        version_str = '2.1.3'
        xml_str = self._xml_sourcetree.substitute(version=version_str)
        xml_root = etree.fromstring(xml_str)
        received = checkout_model.ModelDescription._get_xml_schema_version(
            xml_root)
        expected_version = version_str.split('.')
        self.assertEqual(expected_version, received)

    def test_get_xml_schema_version_not_sourcetree(self):
        """
        """
        xml_str = "<config_sourcetree >foo</config_sourcetree>"
        xml_root = etree.fromstring(xml_str)
        with self.assertRaises(RuntimeError):
            checkout_model.ModelDescription._get_xml_schema_version(xml_root)


class TestCheckoutModel_ModelDescrition_XMLv1(unittest.TestCase):
    """
    """

    def setUp(self):
        """
        """
        self._xml_sourcetree = string.Template("""<config_sourcetree version="1.0.0">
$source
$required
</config_sourcetree>""")
        self._xml_source = string.Template("""    <source name='$name'>
        <TREE_PATH>$path</TREE_PATH> $repo
    </source>""")

        self._xml_repo_tag = string.Template("""
        <repo protocol='$protocol'>
            <ROOT>$url</ROOT>
            <TAG>$tag</TAG>
        </repo>""")

        self._xml_repo_branch = string.Template("""
        <repo protocol='$protocol'>
            <ROOT>$url</ROOT>
            <BRANCH>$branch</BRANCH>
        </repo>""")
        self._xml_required = string.Template("""    <required>
$req
    </required>""")
        self._xml_req_source = string.Template(
            """        <REQ_SOURCE>$name</REQ_SOURCE>""")
        self._setup_foo()
        self._setup_bar()

    def _setup_foo(self):
        self._foo_name = 'foo'
        self._foo_path = 'path/to/foo'
        self._foo_protocol = 'proto1'
        self._foo_url = '/local/clone/of/foo'
        self._foo_tag = 'a_nice_tag_v1'
        self._foo_is_required = True
        repo = self._xml_repo_tag.substitute(protocol=self._foo_protocol,
                                             url=self._foo_url,
                                             tag=self._foo_tag)
        self._foo_source = self._xml_source.substitute(name=self._foo_name,
                                                       path=self._foo_path,
                                                       repo=repo)
        req_src = self._xml_req_source.substitute(name=self._foo_name)
        self._foo_required = self._xml_required.substitute(req=req_src)

    def _setup_bar(self):
        self._bar_name = 'bar'
        self._bar_path = 'path/to/bar'
        self._bar_protocol = 'proto2'
        self._bar_url = '/local/clone/of/bar'
        self._bar_branch = 'a_very_nice_branch'
        self._bar_is_required = False
        repo = self._xml_repo_branch.substitute(protocol=self._bar_protocol,
                                                url=self._bar_url,
                                                branch=self._bar_branch)
        self._bar_source = self._xml_source.substitute(name=self._bar_name,
                                                       path=self._bar_path,
                                                       repo=repo)
        self._bar_required = ''

    def tearDown(self):
        """
        """
        pass

    def _check_foo(self, model):
        self.assertTrue(self._foo_name in model)
        foo = model[self._foo_name]
        self.assertEqual(foo['path'], self._foo_path)
        self.assertEqual(foo['required'], self._foo_is_required)
        repo = foo['repo']
        self.assertEqual(repo['protocol'], self._foo_protocol)
        self.assertEqual(repo['url'], self._foo_url)
        self.assertEqual(repo['tag'], self._foo_tag)

    def _check_bar(self, model):
        self.assertTrue(self._bar_name in model)
        bar = model[self._bar_name]
        self.assertEqual(bar['path'], self._bar_path)
        self.assertEqual(bar['required'], self._bar_is_required)
        repo = bar['repo']
        self.assertEqual(repo['protocol'], self._bar_protocol)
        self.assertEqual(repo['url'], self._bar_url)
        self.assertEqual(repo['branch'], self._bar_branch)

    def test_one_tag(self):
        """
        """
        xml_str = self._xml_sourcetree.substitute(source=self._foo_source,
                                                  required=self._foo_required)
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        model = checkout_model.ModelDescription(xml_root)
        print(model)
        self._check_foo(model)

    def test_one_branch(self):
        """
        """
        xml_str = self._xml_sourcetree.substitute(source=self._bar_source,
                                                  required=self._bar_required)
        xml_root = etree.fromstring(xml_str)
        model = checkout_model.ModelDescription(xml_root)
        print(model)
        self._check_bar(model)

    def test_two(self):
        """
        """
        src_str = "{0}\n{1}".format(self._foo_source, self._bar_source)
        req_str = self._foo_required
        xml_str = self._xml_sourcetree.substitute(source=src_str,
                                                  required=req_str)
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        model = checkout_model.ModelDescription(xml_root)
        print(model)
        self._check_foo(model)
        self._check_bar(model)


class TestCheckoutModel_ModelDescrition_XMLv2(unittest.TestCase):
    """
    """

    def setUp(self):
        """
        """
        self._xml_sourcetree = string.Template("""<config_sourcetree version="2.0.0">
$source
</config_sourcetree>""")
        self._xml_source = string.Template("""    <source name='$name' required='$required'>
        <path>$path</path> $repo
        $externals
    </source>""")

        self._xml_repo_tag = string.Template("""
        <repo protocol='$protocol'>
            <url>$url</url>
            <tag>$tag</tag>
        </repo>""")

        self._xml_repo_branch = string.Template("""
        <repo protocol='$protocol'>
            <url>$url</url>
            <branch>$branch</branch>
        </repo>""")

        self._xml_externals = string.Template(
            """<externals>$name</externals>""")
        self._setup_foo()
        self._setup_bar()

    def _setup_foo(self):
        self._foo_name = 'foo'
        self._foo_path = 'path/to/foo'
        self._foo_protocol = 'proto1'
        self._foo_url = '/local/clone/of/foo'
        self._foo_tag = 'a_nice_tag_v1'
        self._foo_is_required = True
        self._foo_externals = ''
        repo = self._xml_repo_tag.substitute(protocol=self._foo_protocol,
                                             url=self._foo_url,
                                             tag=self._foo_tag)
        self._foo_source = self._xml_source.substitute(name=self._foo_name,
                                                       path=self._foo_path,
                                                       repo=repo,
                                                       required=self._foo_is_required,
                                                       externals=self._foo_externals)

    def _setup_bar(self):
        self._bar_name = 'bar'
        self._bar_path = 'path/to/bar'
        self._bar_protocol = 'proto2'
        self._bar_url = '/local/clone/of/bar'
        self._bar_branch = 'a_very_nice_branch'
        self._bar_is_required = False
        self._bar_externals_name = 'bar.xml'
        self._bar_externals = self._xml_externals.substitute(
            name=self._bar_externals_name)
        repo = self._xml_repo_branch.substitute(protocol=self._bar_protocol,
                                                url=self._bar_url,
                                                branch=self._bar_branch)
        self._bar_source = self._xml_source.substitute(name=self._bar_name,
                                                       path=self._bar_path,
                                                       repo=repo,
                                                       required=self._bar_is_required,
                                                       externals=self._bar_externals)

    def tearDown(self):
        """
        """
        pass

    def _check_foo(self, model):
        self.assertTrue(self._foo_name in model)
        foo = model[self._foo_name]
        self.assertEqual(foo['path'], self._foo_path)
        self.assertEqual(foo['required'], self._foo_is_required)
        repo = foo['repo']
        self.assertEqual(repo['protocol'], self._foo_protocol)
        self.assertEqual(repo['url'], self._foo_url)
        self.assertEqual(repo['tag'], self._foo_tag)
        self.assertEqual('', foo['externals'])

    def _check_bar(self, model):
        self.assertTrue(self._bar_name in model)
        bar = model[self._bar_name]
        self.assertEqual(bar['path'], self._bar_path)
        self.assertEqual(bar['required'], self._bar_is_required)
        repo = bar['repo']
        self.assertEqual(repo['protocol'], self._bar_protocol)
        self.assertEqual(repo['url'], self._bar_url)
        self.assertEqual(repo['branch'], self._bar_branch)
        self.assertEqual(self._bar_externals_name, bar['externals'])

    def test_one_tag_required(self):
        """
        """
        xml_str = self._xml_sourcetree.substitute(source=self._foo_source)
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        model = checkout_model.ModelDescription(xml_root)
        print(model)
        self._check_foo(model)

    def test_one_branch_externals(self):
        """
        """
        xml_str = self._xml_sourcetree.substitute(source=self._bar_source)
        xml_root = etree.fromstring(xml_str)
        model = checkout_model.ModelDescription(xml_root)
        print(model)
        self._check_bar(model)

    def test_two_sources(self):
        """
        """
        src_str = "{0}\n{1}".format(self._foo_source, self._bar_source)
        xml_str = self._xml_sourcetree.substitute(source=src_str)
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        model = checkout_model.ModelDescription(xml_root)
        print(model)
        self._check_foo(model)
        self._check_bar(model)

    @unittest.skip("Haven't figured out how to make this fail yet.")
    def test_invalid(self):
        """
        """
        xml_str = """<source name="foo" required="False">
<repo protocol='git'><url>/path</url></repo>
</source>"""
        print(xml_str)
        xml_root = etree.fromstring(xml_str)
        with self.assertRaises(RuntimeError):
            checkout_model.ModelDescription(xml_root)


if __name__ == '__main__':
    unittest.main()
