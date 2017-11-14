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
import xml.etree.ElementTree as ET

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

try:
    import yaml
except ImportError:
    yaml = None


from manic.model_description import ModelDescription
from manic.globals import EMPTY_STR

# in python2, xml.etree.ElementTree returns byte strings, str, instead
# of unicode. We need unicode to be compatible with cfg and json
# parser and python3.
if sys.version_info[0] >= 3:
    # pylint: disable=invalid-name
    def UnicodeXMLTreeBuilder():
        return None
    # pylint: enable=invalid-name
else:
    class UnicodeXMLTreeBuilder(ET.XMLTreeBuilder):
        # See this thread:
        # http://www.gossamer-threads.com/lists/python/python/728903
        def _fixtext(self, text):
            return text


class TestXMLSchemaVersion(unittest.TestCase):
    """Test that schema identification for sourcetree xml returns the
correct results.

    """

    def setUp(self):
        """Reusable xml string
        """
        self._xml_sourcetree = string.Template(
            """
            <config_sourcetree version="$version">
            </config_sourcetree>
            """)

    def test_schema_version_valid(self):
        """Test that schema identification returns the correct version for a
        valid tag.

        """
        version_str = '2.1.3'
        xml_str = self._xml_sourcetree.substitute(version=version_str)
        xml_root = ET.XML(xml_str, parser=UnicodeXMLTreeBuilder())
        received = ModelDescription.get_xml_schema_version(
            xml_root)
        expected_version = version_str.split('.')
        self.assertEqual(expected_version, received)

    def test_schema_version_missing(self):
        """Test that config_sourcetree xml without a version string raises
        a runtime error.

        """
        xml_str = '<config_sourcetree >comp1</config_sourcetree>'
        xml_root = ET.XML(xml_str, parser=UnicodeXMLTreeBuilder())
        with self.assertRaises(RuntimeError):
            ModelDescription.get_xml_schema_version(xml_root)


class TestModelDescritionXMLv1(unittest.TestCase):
    """Test that parsing an xml version 1 produces a correct dictionary
    for the model description.
    """

    def setUp(self):
        """Setup reusable xml strings for tests.
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
        self._setup_comp1()
        self._setup_comp2()

    def _setup_comp1(self):
        """Reusable setup of component one
        """
        self._comp1_name = 'comp1'
        self._comp1_path = 'path/to/comp1'
        self._comp1_protocol = 'svn'
        self._comp1_url = '/local/clone/of/comp1'
        self._comp1_tag = 'a_nice_tag_v1'
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
        self._comp2_name = 'comp2'
        self._comp2_path = 'path/to/comp2'
        self._comp2_protocol = 'git'
        self._comp2_url = '/local/clone/of/comp2'
        self._comp2_branch = 'a_very_nice_branch'
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
        xml_root = ET.XML(xml_str, parser=UnicodeXMLTreeBuilder())
        model = ModelDescription('xml', xml_root)
        print(model)
        self._check_comp1(model)

    def test_one_branch(self):
        """Test that a component source with a branch is correctly parsed
        """
        xml_str = self._xml_sourcetree.substitute(
            source=self._comp2_source, required=self._comp2_required)
        xml_root = ET.XML(xml_str, parser=UnicodeXMLTreeBuilder())
        model = ModelDescription('xml', xml_root)
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
        xml_root = ET.XML(xml_str, parser=UnicodeXMLTreeBuilder())
        model = ModelDescription('xml', xml_root)
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
        self._xml_sourcetree = string.Template("""<config_sourcetree version="2.0.0">
$source
</config_sourcetree>""")
        self._xml_source = string.Template("""    <source name='$name' required='$required'>
        <local_path>$path</local_path> $repo
        $externals
    </source>""")

        self._xml_repo_tag = string.Template("""
        <repo protocol='$protocol'>
            <repo_url>$url</repo_url>
            <tag>$tag</tag>
        </repo>""")

        self._xml_repo_branch = string.Template("""
        <repo protocol='$protocol'>
            <repo_url>$url</repo_url>
            <branch>$branch</branch>
        </repo>""")

        self._xml_externals = string.Template(
            """<externals>$name</externals>""")
        self._setup_comp1()
        self._setup_comp2()

    def _setup_comp1(self):
        """Boiler plate construction of xml string for componet 1
        """
        self._comp1_name = 'comp1'
        self._comp1_path = 'path/to/comp1'
        self._comp1_protocol = 'svn'
        self._comp1_url = '/local/clone/of/comp1'
        self._comp1_tag = 'a_nice_tag_v1'
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
        self._comp2_name = 'comp2'
        self._comp2_path = 'path/to/comp2'
        self._comp2_protocol = 'git'
        self._comp2_url = '/local/clone/of/comp2'
        self._comp2_branch = 'a_very_nice_branch'
        self._comp2_is_required = False
        self._comp2_externals_name = 'comp2.xml'
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
        xml_root = ET.XML(xml_str, parser=UnicodeXMLTreeBuilder())
        model = ModelDescription('xml', xml_root)
        print(model)
        self._check_comp1(model)

    def test_one_branch_externals(self):
        """Test that a component source with a branch is correctly parsed.
        """
        xml_str = self._xml_sourcetree.substitute(source=self._comp2_source)
        xml_root = ET.XML(xml_str, parser=UnicodeXMLTreeBuilder())
        model = ModelDescription('xml', xml_root)
        print(model)
        self._check_comp2(model)

    def test_two_sources(self):
        """Test that multiple component sources are correctly parsed.
        """
        src_str = "{0}\n{1}".format(self._comp1_source, self._comp2_source)
        xml_str = self._xml_sourcetree.substitute(source=src_str)
        print(xml_str)
        xml_root = ET.XML(xml_str, parser=UnicodeXMLTreeBuilder())
        model = ModelDescription('xml', xml_root)
        print(model)
        self._check_comp1(model)
        self._check_comp2(model)

    def test_invalid(self):
        """Test that an invalid xml string raises a runtime exception.
        """
        xml_str = """<source name="comp1" required="False">
<repo protocol='git'><url>/path</url></repo>
</source>"""
        print(xml_str)
        xml_root = ET.XML(xml_str, parser=UnicodeXMLTreeBuilder())
        with self.assertRaises(RuntimeError):
            ModelDescription('xml', xml_root)


class TestModelDescritionConfig(unittest.TestCase):
    """Test that parsing config/ini fileproduces a correct dictionary
    for the model description.

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
        self.assertEqual(comp1[ModelDescription.PATH], self._comp1_path)
        self.assertTrue(comp1[ModelDescription.REQUIRED])
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
        self.assertFalse(comp2[ModelDescription.REQUIRED])
        repo = comp2[ModelDescription.REPO]
        self.assertEqual(repo[ModelDescription.PROTOCOL],
                         self._comp2_protocol)
        self.assertEqual(repo[ModelDescription.REPO_URL], self._comp2_url)
        self.assertEqual(repo[ModelDescription.BRANCH], self._comp2_branch)
        self.assertEqual(self._comp2_externals,
                         comp2[ModelDescription.EXTERNALS])

    def test_one_tag_required(self):
        """Test that a component source with a tag is correctly parsed.
        """
        config = config_parser()
        self._setup_comp1(config)
        model = ModelDescription('cfg', config)
        print(model)
        self._check_comp1(model)

    def test_one_branch_externals(self):
        """Test that a component source with a branch is correctly parsed.
        """
        config = config_parser()
        self._setup_comp2(config)
        model = ModelDescription('cfg', config)
        print(model)
        self._check_comp2(model)

    def test_two_sources(self):
        """Test that multiple component sources are correctly parsed.
        """
        config = config_parser()
        self._setup_comp1(config)
        self._setup_comp2(config)
        model = ModelDescription('cfg', config)
        print(model)
        self._check_comp1(model)
        self._check_comp2(model)


class TestModelDescritionYAML(unittest.TestCase):
    """Test that parsing yaml file produces a correct dictionary
    for the model description.

    """

    def setUp(self):
        """Boiler plate construction of string containing xml for multiple components.
        """
        self._yaml_template_tag = string.Template('''
$name:
    required: $required
    local_path: $path
    repo:
        protocol: $protocol
        repo_url: $url
        tag: $tag
        ''')

        self._yaml_template_branch = string.Template('''
$name:
    required: $required
    local_path: $path
    repo:
        protocol: $protocol
        repo_url: $url
        branch: $branch
    externals: $externals
        ''')
        self._setup_comp1()
        self._setup_comp2()

    def _setup_comp1(self):
        """Boiler plate construction of xml string for componet 1
        """
        self._comp1_name = 'comp1'
        self._comp1_path = 'path/to/comp1'
        self._comp1_protocol = 'svn'
        self._comp1_url = 'https://svn.somewhere.com/path/of/comp1'
        self._comp1_tag = 'a_nice_tag_v1'
        self._comp1_branch = ''
        self._comp1_is_required = 'True'
        self._comp1_externals = ''

        self._comp1_str = self._yaml_template_tag.substitute(
            name=self._comp1_name, path=self._comp1_path,
            protocol=self._comp1_protocol, url=self._comp1_url,
            tag=self._comp1_tag, required=self._comp1_is_required)

    def _setup_comp2(self):
        """Boiler plate construction of xml string for componet 2
        """
        self._comp2_name = 'comp2'
        self._comp2_path = 'path/to/comp2'
        self._comp2_protocol = 'git'
        self._comp2_url = '/local/clone/of/comp2'
        self._comp2_tag = ''
        self._comp2_branch = 'a_very_nice_branch'
        self._comp2_is_required = 'False'
        self._comp2_externals = 'path/to/comp2.cfg'

        self._comp2_str = self._yaml_template_branch.substitute(
            name=self._comp2_name, path=self._comp2_path,
            protocol=self._comp2_protocol, url=self._comp2_url,
            branch=self._comp2_branch, externals=self._comp2_externals,
            required=self._comp2_is_required)

    def _check_comp1(self, model):
        """Test that component one was constructed correctly.
        """
        self.assertTrue(self._comp1_name in model)
        comp1 = model[self._comp1_name]
        self.assertEqual(comp1[ModelDescription.PATH], self._comp1_path)
        self.assertTrue(comp1[ModelDescription.REQUIRED])
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
        self.assertFalse(comp2[ModelDescription.REQUIRED])
        repo = comp2[ModelDescription.REPO]
        self.assertEqual(repo[ModelDescription.PROTOCOL],
                         self._comp2_protocol)
        self.assertEqual(repo[ModelDescription.REPO_URL], self._comp2_url)
        self.assertEqual(repo[ModelDescription.BRANCH], self._comp2_branch)
        self.assertEqual(self._comp2_externals,
                         comp2[ModelDescription.EXTERNALS])

    def test_one_tag_required(self):
        """Test that a component source with a tag is correctly parsed.
        """
        model_description = yaml.safe_load(self._comp1_str)
        model = ModelDescription('yaml', model_description)
        print(model)
        self._check_comp1(model)

    def test_one_branch_externals(self):
        """Test that a component source with a branch is correctly parsed.
        """
        model_description = yaml.safe_load(self._comp2_str)
        model = ModelDescription('yaml', model_description)
        print(model)
        self._check_comp2(model)

    def test_two_sources(self):
        """Test that multiple component sources are correctly parsed.
        """
        model_str = "{0}\n{1}".format(self._comp2_str, self._comp1_str)
        model_description = yaml.safe_load(model_str)
        model = ModelDescription('yaml', model_description)
        print(model)
        self._check_comp1(model)
        self._check_comp2(model)


if __name__ == '__main__':
    unittest.main()
