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
import shutil
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
from manic.externals_description import ExternalsDescriptionDict
from manic.externals_description import ExternalsDescriptionConfigV1
from manic.externals_description import get_cfg_schema_version
from manic.externals_description import read_externals_description_file
from manic.externals_description import create_externals_description

from manic.global_constants import EMPTY_STR


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

    def test_schema_version_not_int(self):
        """Test that a externals description file a version that doesn't
        decompose to integer major, minor and patch versions raises
        runtime error.

        """
        self._config.set(DESCRIPTION_SECTION, VERSION_ITEM, 'unknown')
        with self.assertRaises(RuntimeError):
            get_cfg_schema_version(self._config)


class TestModelDescritionConfigV1(unittest.TestCase):
    """Test that parsing config/ini fileproduces a correct dictionary
    for the externals description.

    """
    # pylint: disable=R0902

    def setUp(self):
        """Boiler plate construction of string containing xml for multiple components.
        """
        self._comp1_name = 'comp1'
        self._comp1_path = 'path/to/comp1'
        self._comp1_protocol = 'svn'
        self._comp1_url = 'https://svn.somewhere.com/path/of/comp1'
        self._comp1_tag = 'a_nice_tag_v1'
        self._comp1_is_required = 'True'
        self._comp1_externals = ''

        self._comp2_name = 'comp2'
        self._comp2_path = 'path/to/comp2'
        self._comp2_protocol = 'git'
        self._comp2_url = '/local/clone/of/comp2'
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

    @staticmethod
    def _setup_externals_description(config):
        """Add the required exernals description section
        """

        config.add_section(DESCRIPTION_SECTION)
        config.set(DESCRIPTION_SECTION, VERSION_ITEM, '1.0.1')

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
        self._setup_externals_description(config)
        model = ExternalsDescriptionConfigV1(config)
        print(model)
        self._check_comp1(model)

    def test_one_branch_externals(self):
        """Test that a component source with a branch is correctly parsed.
        """
        config = config_parser()
        self._setup_comp2(config)
        self._setup_externals_description(config)
        model = ExternalsDescriptionConfigV1(config)
        print(model)
        self._check_comp2(model)

    def test_two_sources(self):
        """Test that multiple component sources are correctly parsed.
        """
        config = config_parser()
        self._setup_comp1(config)
        self._setup_comp2(config)
        self._setup_externals_description(config)
        model = ExternalsDescriptionConfigV1(config)
        print(model)
        self._check_comp1(model)
        self._check_comp2(model)

    def test_cfg_v1_reject_unknown_item(self):
        """Test that a v1 description object will reject unknown items
        """
        config = config_parser()
        self._setup_comp1(config)
        self._setup_externals_description(config)
        config.set(self._comp1_name, 'junk', 'foobar')
        with self.assertRaises(RuntimeError):
            ExternalsDescriptionConfigV1(config)

    def test_cfg_v1_reject_v2(self):
        """Test that a v1 description object won't try to parse a v2 file.
        """
        config = config_parser()
        self._setup_comp1(config)
        self._setup_externals_description(config)
        config.set(DESCRIPTION_SECTION, VERSION_ITEM, '2.0.1')
        with self.assertRaises(RuntimeError):
            ExternalsDescriptionConfigV1(config)

    def test_cfg_v1_reject_v1_too_new(self):
        """Test that a v1 description object won't try to parse a v2 file.
        """
        config = config_parser()
        self._setup_comp1(config)
        self._setup_externals_description(config)
        config.set(DESCRIPTION_SECTION, VERSION_ITEM, '1.100.0')
        with self.assertRaises(RuntimeError):
            ExternalsDescriptionConfigV1(config)


class TestReadExternalsDescription(unittest.TestCase):
    """Test the application logic of read_externals_description_file
    """
    TMP_FAKE_DIR = 'fake'

    def setUp(self):
        """Setup directory for tests
        """
        if not os.path.exists(self.TMP_FAKE_DIR):
            os.makedirs(self.TMP_FAKE_DIR)

    def tearDown(self):
        """Cleanup tmp stuff on the file system
        """
        if os.path.exists(self.TMP_FAKE_DIR):
            shutil.rmtree(self.TMP_FAKE_DIR)

    def test_no_file_error(self):
        """Test that a runtime error is raised when the file does not exist

        """
        root_dir = os.getcwd()
        filename = 'this-file-should-not-exist'
        with self.assertRaises(RuntimeError):
            read_externals_description_file(root_dir, filename)

    def test_no_dir_error(self):
        """Test that a runtime error is raised when the file does not exist

        """
        root_dir = '/path/to/some/repo'
        filename = 'externals.cfg'
        with self.assertRaises(RuntimeError):
            read_externals_description_file(root_dir, filename)

    def test_no_invalid_error(self):
        """Test that a runtime error is raised when the file format is invalid

        """
        root_dir = os.getcwd()
        filename = 'externals.cfg'
        file_path = os.path.join(root_dir, filename)
        file_path = os.path.abspath(file_path)
        contents = """
<source_tree version='1.0.0'>
invalid file format
</sourc_tree>"""
        with open(file_path, 'w') as fhandle:
            fhandle.write(contents)
        with self.assertRaises(RuntimeError):
            read_externals_description_file(root_dir, filename)
        os.remove(file_path)


class TestCreateExternalsDescription(unittest.TestCase):
    """Test the application logic of creat_externals_description
    """

    def setUp(self):
        """Create config object used as basis for all tests
        """
        self._config = config_parser()
        self.setup_config()

    def setup_config(self):
        """Boiler plate construction of xml string for componet 1
        """
        name = 'test'
        self._config.add_section(name)
        self._config.set(name, ExternalsDescription.PATH, 'externals')
        self._config.set(name, ExternalsDescription.PROTOCOL, 'git')
        self._config.set(name, ExternalsDescription.REPO_URL, '/path/to/repo')
        self._config.set(name, ExternalsDescription.TAG, 'test_tag')
        self._config.set(name, ExternalsDescription.REQUIRED, 'True')

        self._config.add_section(DESCRIPTION_SECTION)
        self._config.set(DESCRIPTION_SECTION, VERSION_ITEM, '1.0.0')

    def test_cfg_v1_ok(self):
        """Test that a correct cfg v1 object is created by create_externals_description

        """
        self._config.set(DESCRIPTION_SECTION, VERSION_ITEM, '1.0.3')
        ext = create_externals_description(self._config, model_format='cfg')
        self.assertIsInstance(ext, ExternalsDescriptionConfigV1)

    def test_cfg_v1_unknown_version(self):
        """Test that a config file with unknown schema version is rejected by
        create_externals_description.

        """
        self._config.set(DESCRIPTION_SECTION, VERSION_ITEM, '100.0.3')
        with self.assertRaises(RuntimeError):
            create_externals_description(self._config, model_format='cfg')

    def test_dict(self):
        """Test that a correct cfg v1 object is created by create_externals_description

        """
        rdata = {ExternalsDescription.PROTOCOL: 'git',
                 ExternalsDescription.REPO_URL: '/path/to/repo',
                 ExternalsDescription.TAG: 'tagv1',
                 }

        desc = {
            'test': {
                ExternalsDescription.REQUIRED: False,
                ExternalsDescription.PATH: '../fake',
                ExternalsDescription.EXTERNALS: EMPTY_STR,
                ExternalsDescription.REPO: rdata, },
        }

        ext = create_externals_description(desc, model_format='dict')
        self.assertIsInstance(ext, ExternalsDescriptionDict)

    def test_cfg_unknown_version(self):
        """Test that a runtime error is raised when an unknown file version is
        received

        """
        self._config.set(DESCRIPTION_SECTION, VERSION_ITEM, '123.456.789')
        with self.assertRaises(RuntimeError):
            create_externals_description(self._config, model_format='cfg')

    def test_cfg_unknown_format(self):
        """Test that a runtime error is raised when an unknown format string is
        received

        """
        with self.assertRaises(RuntimeError):
            create_externals_description(self._config, model_format='unknown')


if __name__ == '__main__':
    unittest.main()
