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


class TestCheckoutModel_create_repository(unittest.TestCase):
    """Test the create_repository functionality to ensure it returns the
    propper type of repository and errors for unknown repository
    types.

    """
    def setUp(self):
        """
        """
        self._xml_protocol = string.Template(
            """
            <repo protocol="$protocol">
            <root>junk_root</root>
            <tag>junk_tag</tag>
            </repo>
            """)

    def test_create_repo_git(self):
        """
        """
        name = 'test_name'
        protocol = 'git'
        xml = etree.fromstring(self._xml_protocol.substitute(protocol=protocol))
        repo = checkout_model.create_repository(name, xml)
        self.assertIsInstance(repo, checkout_model._GitRepository)

    def test_create_repo_git_upper(self):
        """
        """
        name = 'test_name'
        protocol = 'GIT'
        xml = etree.fromstring(self._xml_protocol.substitute(protocol=protocol))
        repo = checkout_model.create_repository(name, xml)
        self.assertIsInstance(repo, checkout_model._GitRepository)

    def test_create_repo_svn(self):
        """
        """
        name = 'test_name'
        protocol = 'svn'
        xml = etree.fromstring(self._xml_protocol.substitute(protocol=protocol))
        repo = checkout_model.create_repository(name, xml)
        self.assertIsInstance(repo, checkout_model._SvnRepository)

    def test_create_repo_svn_upper(self):
        """
        """
        name = 'test_name'
        protocol = 'svn'
        xml = etree.fromstring(self._xml_protocol.substitute(protocol=protocol))
        repo = checkout_model.create_repository(name, xml)
        self.assertIsInstance(repo, checkout_model._SvnRepository)


class TestCheckoutModel_Repository_XML(unittest.TestCase):
    """Test the xml processing used to create the _Repository base class
    shared by protocol specific repository classes.

    """
    def setUp(self):
        self._repo_tag = string.Template(
            """
            <repo protocol="$protocol">
            <root>$root</root>
            <tag>$tag</tag>
            </repo>
            """)

        self._repo_branch = string.Template(
            """
            <repo protocol="$protocol">
            <root>$root</root>
            <branch>$branch</branch>
            </repo>
            """)

    def tearDown(self):
        pass

    def test_tag(self):
        name = 'test_repo'
        protocol = 'test_protocol'
        root = 'test_root'
        tag = 'test_tag'
        xml_str = self._repo_tag.substitute(
            protocol=protocol, root=root, tag=tag)
        xml = etree.fromstring(xml_str)
        repo = checkout_model._Repository(name, xml)
        print(repo.__dict__)
        self.assertEqual(repo._tag, tag)
        self.assertEqual(repo._url, root)

    def test_branch(self):
        name = 'test_repo'
        protocol = 'test_protocol'
        root = 'test_root'
        tag = 'test_tag'
        xml_str = self._repo_tag.substitute(
            protocol=protocol, root=root, tag=tag)
        xml = etree.fromstring(xml_str)
        repo = checkout_model._Repository(name, xml)
        print(repo.__dict__)
        self.assertEqual(repo._tag, tag)
        self.assertEqual(repo._url, root)


if __name__ == '__main__':
    unittest.main()
