#!/usr/bin/env python

"""Unit test driver for checkout_externals

Note: this script assume the path to the checkout_externals.py module is
already in the python path.

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import os
import os.path
import unittest

try:
    # python2
    from ConfigParser import SafeConfigParser as config_parser

    def config_string_cleaner(text):
        """convert strings into unicode
        """
        return text.decode('utf-8')
except ImportError:
    # python3
    from configparser import ConfigParser as config_parser

    def config_string_cleaner(text):
        """Python3 already uses unicode strings, so just return the string
        without modification.

        """
        return text

from manic.externals_description import DESCRIPTION_SECTION, VERSION_ITEM
from manic.externals_description import ExternalsDescription
from manic.externals_description import ExternalsDescriptionConfigV1
from manic.externals_description import get_cfg_schema_version

from manic.globals import EMPTY_STR


class TestCfgSchemaVersion(unittest.TestCase):
    """Test that schema identification for the externals description
    returns the correct results.

    """

    def setUp(self):
        """Reusable config object
        """
        self._config = config_parser()
        self._config.add_section('section1')
        self._config.set('section1', 'keword', 'value')

        self._config.add_section(DESCRIPTION_SECTION)

    def test_schema_version_valid(self):
        """Test that schema identification returns the correct version for a
        valid tag.

        """
        version_str = '2.1.3'
        self._config.set(DESCRIPTION_SECTION, VERSION_ITEM, version_str)
        major, minor, patch = get_cfg_schema_version(self._config)
        expected_major = 2
        expected_minor = 1
        expected_patch = 3
        self.assertEqual(expected_major, major)
        self.assertEqual(expected_minor, minor)
        self.assertEqual(expected_patch, patch)

    def test_schema_section_missing(self):
        """Test that an error is returned if the schema section is missing
        from the input file.

        """
        self._config.remove_section(DESCRIPTION_SECTION)
        with self.assertRaises(RuntimeError):
            get_cfg_schema_version(self._config)

    def test_schema_version_missing(self):
        """Test that a externals description file without a version raises a
        runtime error.

        """
        # Note: the default setup method shouldn't include a version
        # keyword, but remove it just to be future proof....
        self._config.remove_option(DESCRIPTION_SECTION, VERSION_ITEM)
        with self.assertRaises(RuntimeError):
            get_cfg_schema_version(self._config)


class TestModelDescritionConfigV1(unittest.TestCase):
    """Test that parsing config/ini fileproduces a correct dictionary
    for the externals description.

    """

    def setUp(self):
        """Boiler plate construction of string containing xml for multiple components.
        """
        self._comp1_name = 'comp1'
        self._comp1_path = 'path/to/comp1'
        self._comp1_protocol = 'svn'
        self._comp1_url = 'https://svn.somewhere.com/path/of/comp1'
        self._comp1_tag = 'a_nice_tag_v1'
        self._comp1_branch = ''
        self._comp1_is_required = 'True'
        self._comp1_externals = ''

        self._comp2_name = 'comp2'
        self._comp2_path = 'path/to/comp2'
        self._comp2_protocol = 'git'
        self._comp2_url = '/local/clone/of/comp2'
        self._comp2_tag = ''
        self._comp2_branch = 'a_very_nice_branch'
        self._comp2_is_required = 'False'
        self._comp2_externals = 'path/to/comp2.cfg'

    def _setup_comp1(self, config):
        """Boiler plate construction of xml string for componet 1
        """
        config.add_section(self._comp1_name)
        config.set(self._comp1_name, 'local_path', self._comp1_path)
        config.set(self._comp1_name, 'protocol', self._comp1_protocol)
        config.set(self._comp1_name, 'repo_url', self._comp1_url)
        config.set(self._comp1_name, 'tag', self._comp1_tag)
        config.set(self._comp1_name, 'required', self._comp1_is_required)

    def _setup_comp2(self, config):
        """Boiler plate construction of xml string for componet 2
        """
        config.add_section(self._comp2_name)
        config.set(self._comp2_name, 'local_path', self._comp2_path)
        config.set(self._comp2_name, 'protocol', self._comp2_protocol)
        config.set(self._comp2_name, 'repo_url', self._comp2_url)
        config.set(self._comp2_name, 'branch', self._comp2_branch)
        config.set(self._comp2_name, 'required', self._comp2_is_required)
        config.set(self._comp2_name, 'externals', self._comp2_externals)

    def _check_comp1(self, model):
        """Test that component one was constructed correctly.
        """
        self.assertTrue(self._comp1_name in model)
        comp1 = model[self._comp1_name]
        self.assertEqual(comp1[ExternalsDescription.PATH], self._comp1_path)
        self.assertTrue(comp1[ExternalsDescription.REQUIRED])
        repo = comp1[ExternalsDescription.REPO]
        self.assertEqual(repo[ExternalsDescription.PROTOCOL],
                         self._comp1_protocol)
        self.assertEqual(repo[ExternalsDescription.REPO_URL], self._comp1_url)
        self.assertEqual(repo[ExternalsDescription.TAG], self._comp1_tag)
        self.assertEqual(EMPTY_STR, comp1[ExternalsDescription.EXTERNALS])

    def _check_comp2(self, model):
        """Test that component two was constucted correctly.
        """
        self.assertTrue(self._comp2_name in model)
        comp2 = model[self._comp2_name]
        self.assertEqual(comp2[ExternalsDescription.PATH], self._comp2_path)
        self.assertFalse(comp2[ExternalsDescription.REQUIRED])
        repo = comp2[ExternalsDescription.REPO]
        self.assertEqual(repo[ExternalsDescription.PROTOCOL],
                         self._comp2_protocol)
        self.assertEqual(repo[ExternalsDescription.REPO_URL], self._comp2_url)
        self.assertEqual(repo[ExternalsDescription.BRANCH], self._comp2_branch)
        self.assertEqual(self._comp2_externals,
                         comp2[ExternalsDescription.EXTERNALS])

    def test_one_tag_required(self):
        """Test that a component source with a tag is correctly parsed.
        """
        config = config_parser()
        self._setup_comp1(config)
        model = ExternalsDescriptionConfigV1(config)
        print(model)
        self._check_comp1(model)

    def test_one_branch_externals(self):
        """Test that a component source with a branch is correctly parsed.
        """
        config = config_parser()
        self._setup_comp2(config)
        model = ExternalsDescriptionConfigV1(config)
        print(model)
        self._check_comp2(model)

    def test_two_sources(self):
        """Test that multiple component sources are correctly parsed.
        """
        config = config_parser()
        self._setup_comp1(config)
        self._setup_comp2(config)
        model = ExternalsDescriptionConfigV1(config)
        print(model)
        self._check_comp1(model)
        self._check_comp2(model)


class TestCheckURL(unittest.TestCase):
    """Crude url checking to determine if a url is local or remote.

    Remote should be unmodified.

    Local, should perform user and variable expansion.

    """

    def test_url_remote_git(self):
        """verify that a remote git url is unmodified.
        """
        field = 'test'
        url = 'git@somewhere'
        received = ExternalsDescription.check_url(url, field)
        self.assertEqual(received, url)

    def test_url_remote_ssh(self):
        """verify that a remote ssh url is unmodified.
        """
        field = 'test'
        url = 'ssh://user@somewhere'
        received = ExternalsDescription.check_url(url, field)
        self.assertEqual(received, url)

    def test_url_remote_http(self):
        """verify that a remote http url is unmodified.
        """
        field = 'test'
        url = 'http://somewhere'
        received = ExternalsDescription.check_url(url, field)
        self.assertEqual(received, url)

    def test_url_remote_https(self):
        """verify that a remote https url is unmodified.
        """
        field = 'test'
        url = 'https://somewhere'
        received = ExternalsDescription.check_url(url, field)
        self.assertEqual(received, url)

    def test_url_local_user1(self):
        """verify that a local path with '~/path/to/repo' gets expanded to an
        absolute path.

        NOTE(bja, 2017-11) we can't test for something like:
        '~user/path/to/repo' because the user has to be in the local
        machine password directory and we don't know a user name that
        is valid on every system....?

        """
        field = 'test'
        url = '~/path/to/repo'
        received = ExternalsDescription.check_url(url, field)
        print(received)
        self.assertTrue(os.path.isabs(received))

    def test_url_local_expand_curly(self):
        """verify that a local path with '${HOME}' gets expanded to an absolute path.
        """
        field = 'test'
        url = '${HOME}/path/to/repo'
        received = ExternalsDescription.check_url(url, field)
        self.assertTrue(os.path.isabs(received))

    def test_url_local_expand_var(self):
        """verify that a local path with '$HOME' gets expanded to an absolute path.
        """
        field = 'test'
        url = '$HOME/path/to/repo'
        received = ExternalsDescription.check_url(url, field)
        self.assertTrue(os.path.isabs(received))

    def test_url_local_env_missing(self):
        """verify that a local path with env var that is missing gets left as-is

        """
        field = 'test'
        url = '$TMP_VAR/path/to/repo'
        received = ExternalsDescription.check_url(url, field)
        print(received)
        self.assertEqual(received, url)

    def test_url_local_expand_env(self):
        """verify that a local path with another env var gets expanded to an
        absolute path.

        """
        field = 'test'
        os.environ['TMP_VAR'] = '/some/absolute'
        url = '$TMP_VAR/path/to/repo'
        received = ExternalsDescription.check_url(url, field)
        del os.environ['TMP_VAR']
        print(received)
        self.assertTrue(os.path.isabs(received))


if __name__ == '__main__':
    unittest.main()
