#!/usr/bin/env python

"""Unit test driver for checkout_externals

Note: this script assume the path to the checkout_externals.py module is
already in the python path.

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import string
import sys
import unittest

try:
    # python2
    from ConfigParser import SafeConfigParser as config_parser

    def config_string_cleaner(text):
        return text.decode('utf-8')
except ImportError:
    # python3
    from configparser import ConfigParser as config_parser

    def config_string_cleaner(text):
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


if __name__ == '__main__':
    unittest.main()
