#!/usr/bin/env python

"""
Tool to assemble respositories represented in a model-description file.

If loaded as a module (e.g., in a component's buildcpp), it can be used
to check the validity of existing subdirectories and load missing sources.
"""
from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import json
import logging
import os
import os.path
import sys
import xml.etree.ElementTree as ET

# ConfigParser was renamed in python2 to configparser. In python2,
# ConfigParser returns byte strings, str, instead of unicode. We need
# unicode to be compatible with xml and json parser and python3.
try:
    # python2
    from ConfigParser import SafeConfigParser as config_parser
    import ConfigParser

    def config_string_cleaner(text):
        return text.decode('utf-8')
except ImportError:
    # python3
    from configparser import ConfigParser as config_parser

    def config_string_cleaner(text):
        return text

# in python2, xml.etree.ElementTree returns byte strings, str, instead
# of unicode. We need unicode to be compatible with cfg and json
# parser and python3.
if sys.version_info[0] >= 3:
    def UnicodeXMLTreeBuilder():
        return None
else:
    class UnicodeXMLTreeBuilder(ET.XMLTreeBuilder):
        # See this thread:
        # http://www.gossamer-threads.com/lists/python/python/728903
        def _fixtext(self, text):
            return text

try:
    import yaml
except ImportError:
    yaml = None


from .utils import printlog, fatal_error
from .globals import EMPTY_STR, PPRINTER


def read_model_description_file(root_dir, file_name):
    """Given a file name containing a model description, determine the
    format and read it into it's internal representation.

    """
    root_dir = os.path.abspath(root_dir)
    msg = 'In directory : {0}'.format(root_dir)
    logging.info(msg)
    printlog('Processing model description file : {0}'.format(file_name))

    file_path = os.path.join(root_dir, file_name)
    if not os.path.exists(file_name):
        msg = ('ERROR: Model description file, "{0}", does not '
               'exist at {1}'.format(file_name, file_path))
        fatal_error(msg)

    model_description = None
    model_format = None
    with open(file_path, 'r') as filehandle:
        try:
            xml_tree = ET.parse(filehandle, parser=UnicodeXMLTreeBuilder())
            model_description = xml_tree.getroot()
            model_format = 'xml'
        except ET.ParseError:
            # not an xml file.
            pass

    if model_description is None:
        with open(file_path, 'r') as filehandle:
            try:
                json_data = json.loads(filehandle.read())
                model_description = json_data
                model_format = 'json'
            except ValueError:
                # not a json file
                pass

    if model_description is None:
        try:
            config = config_parser()
            config.read(file_path)
            # insert cfg2dict here
            model_description = config
            model_format = 'cfg'
        except ConfigParser.MissingSectionHeaderError:
            # not a cfg file
            pass

    if model_description is None:
        # NOTE(bja, 2017-10) json is a subset of yaml, so valid json
        # file should be readable by yaml. Need to try json first.
        if yaml:
            with open(file_path, 'r') as filehandle:
                try:
                    model_description = yaml.safe_load(filehandle)
                    model_format = 'yaml'
                except yaml.YAMLError as error:
                    print(error)
        else:
            print('YAML not available - can not load YAML file!')

    if model_description is None:
        msg = 'Unknown file format!'
        fatal_error(msg)

    return model_format, model_description


class ModelDescription(dict):
    """Model description that is independent of the user input format. Can
    convert multiple input formats, xml schemas, or dictionaries into
    a consistent represtentation for the rest of the objects.

    """
    # keywords defining the interface into the model description data
    EXTERNALS = 'externals'
    BRANCH = 'branch'
    REPO = 'repo'
    REQUIRED = 'required'
    TAG = 'tag'
    PATH = 'local_path'
    PROTOCOL = 'protocol'
    REPO_URL = 'repo_url'
    NAME = 'name'

    PROTOCOL_EXTERNALS_ONLY = 'externals_only'
    PROTOCOL_GIT = 'git'
    PROTOCOL_SVN = 'svn'
    KNOWN_PRROTOCOLS = [PROTOCOL_GIT, PROTOCOL_SVN, PROTOCOL_EXTERNALS_ONLY]

    # v1 xml keywords
    _V1_TREE_PATH = 'TREE_PATH'
    _V1_ROOT = 'ROOT'
    _V1_TAG = 'TAG'
    _V1_BRANCH = 'BRANCH'
    _V1_REQ_SOURCE = 'REQ_SOURCE'

    _source_schema = {REQUIRED: True,
                      PATH: 'string',
                      EXTERNALS: 'string',
                      REPO: {PROTOCOL: 'string',
                             REPO_URL: 'string',
                             TAG: 'string',
                             BRANCH: 'string',
                             }
                      }

    def __init__(self, model_format, model_data):
        """Convert the xml into a standardized dict that can be used to
        construct the source objects

        """
        dict.__init__(self)
        if model_format == 'xml':
            self._parse_xml(model_data)
        elif model_format == 'cfg':
            self._parse_cfg(model_data)
        elif model_format == 'json':
            self._parse_json(model_data)
        elif model_format == 'yaml':
            self._parse_yaml(model_data)
        else:
            msg = 'Unknown model data format "{0}"'.format(model_format)
            fatal_error(msg)
        self._check_optional()
        self._validate()
        self._check_data()

    def _check_data(self):
        """Check user supplied data is valid where possible.
        """
        for field in self.keys():
            if (self[field][self.REPO][self.PROTOCOL]
                    not in self.KNOWN_PRROTOCOLS):
                msg = 'Unknown repository protocol "{0}" in "{1}".'.format(
                    self[field][self.REPO][self.PROTOCOL], field)
                fatal_error(msg)

            if (self[field][self.REPO][self.PROTOCOL]
                    != self.PROTOCOL_EXTERNALS_ONLY):
                if (self[field][self.REPO][self.TAG] and
                        self[field][self.REPO][self.BRANCH]):
                    msg = ('Model description is over specified! Can not '
                           'have both "tag" and "branch" in repo '
                           'description for "{0}"'.format(field))
                    fatal_error(msg)

                if (not self[field][self.REPO][self.TAG] and
                        not self[field][self.REPO][self.BRANCH]):
                    msg = ('Model description is under specified! Must have '
                           'either "tag" or "branch" in repo '
                           'description for "{0}"'.format(field))
                    fatal_error(msg)

                if not self[field][self.REPO][self.REPO_URL]:
                    msg = ('Model description is under specified! Must have '
                           'either "repo_url" in repo '
                           'description for "{0}"'.format(field))
                    fatal_error(msg)

    def _check_optional(self):
        """Some fields like externals, repo:tag repo:branch are
        (conditionally) optional. We don't want the user to be
        required to enter them in every model description file, but
        still want to validate the input. Check conditions and add
        default values if appropriate.

        """
        for field in self:
            # truely optional
            if self.EXTERNALS not in self[field]:
                self[field][self.EXTERNALS] = EMPTY_STR

            # git and svn repos must tags and branches for validation purposes.
            if self.TAG not in self[field][self.REPO]:
                self[field][self.REPO][self.TAG] = EMPTY_STR
            if self.BRANCH not in self[field][self.REPO]:
                self[field][self.REPO][self.BRANCH] = EMPTY_STR
            if self.REPO_URL not in self[field][self.REPO]:
                self[field][self.REPO][self.REPO_URL] = EMPTY_STR

    def _validate(self):
        """Validate that the parsed model description contains all necessary
        fields.

        """
        def validate_data_struct(schema, data):
            """Compare a data structure against a schema and validate all required
            fields are present.

            """
            is_valid = False
            in_ref = True
            valid = True
            if isinstance(schema, dict) and isinstance(data, dict):
                for k in schema:
                    in_ref = in_ref and (k in data)
                    if in_ref:
                        valid = valid and (
                            validate_data_struct(schema[k], data[k]))
                is_valid = in_ref and valid
            else:
                is_valid = isinstance(data, type(schema))
            if not is_valid:
                printlog("  Unmatched schema and data:")
                if isinstance(schema, dict):
                    for item in schema:
                        printlog("    {0} schema = {1} ({2})".format(
                            item, schema[item], type(schema[item])))
                        printlog("    {0} data = {1} ({2})".format(
                            item, data[item], type(data[item])))
                else:
                    printlog("    schema = {0} ({1})".format(
                        schema, type(schema)))
                    printlog("    data = {0} ({1})".format(data, type(data)))
            return is_valid

        for field in self:
            valid = validate_data_struct(self._source_schema, self[field])
            if not valid:
                PPRINTER.pprint(self._source_schema)
                PPRINTER.pprint(self[field])
                msg = 'ERROR: source for "{0}" did not validate'.format(field)
                fatal_error(msg)

    def _parse_json(self, json_data):
        """Parse a json object, a native dictionary into a model description.
        """
        self.update(json_data)

    def _parse_yaml(self, yaml_data):
        """Parse a yaml object, a native dictionary into a model
        description. Note: yaml seems to only load python binary
        strings, and we expect unicode for compatibility.

        """
        def dict_convert_str(input_dict, convert_to_lower_case=True):
            """Convert a dictionary to use unicode for all strings in key-value
            pairs.

            """
            output_dict = {}
            for key in input_dict:
                ukey = key.strip().decode('utf-8')
                if convert_to_lower_case:
                    ukey = ukey.lower()
                value = input_dict[key]
                if isinstance(value, dict):
                    value = dict_convert_str(value)
                elif isinstance(value, str):
                    value = input_dict[key].strip().decode('utf-8')
                elif isinstance(value, bool):
                    pass
                else:
                    msg = ('Unexpected data type for "{0}" : '
                           '{1} ({2})'.format(key, value, type(value)))
                    fatal_error(msg)
                output_dict[ukey] = value
            return output_dict

        udict = dict_convert_str(yaml_data)
        self.update(udict)

    def _parse_cfg(self, cfg_data):
        """Parse a config_parser object into a model description.
        """
        def list_to_dict(input_list, convert_to_lower_case=True):
            """Convert a list of key-value pairs into a dictionary.
            """
            output_dict = {}
            for item in input_list:
                key = config_string_cleaner(item[0].strip())
                value = config_string_cleaner(item[1].strip())
                if convert_to_lower_case:
                    key = key.lower()
                output_dict[key] = value
            return output_dict

        for section in cfg_data.sections():
            name = config_string_cleaner(section.lower().strip())
            self[name] = {}
            self[name].update(list_to_dict(cfg_data.items(section)))
            self[name][self.REPO] = {}
            for item in self[name].keys():
                if item in self._source_schema:
                    if isinstance(self._source_schema[item], bool):
                        self[name][item] = self.str_to_bool(self[name][item])
                if item in self._source_schema[self.REPO]:
                    self[name][self.REPO][item] = self[name][item]
                    del self[name][item]

    def _parse_xml(self, xml_root):
        """Parse an xml object into a model description.
        """
        xml_root = self._get_xml_config_sourcetree(xml_root)
        version = self.get_xml_schema_version(xml_root)
        major_version = version[0]
        if major_version == '1':
            self._parse_xml_v1(xml_root)
        elif major_version == '2':
            self._parse_xml_v2(xml_root)
        else:
            msg = ('ERROR: unknown xml schema version "{0}"'.format(
                major_version))
            fatal_error(msg)

    def _parse_xml_v1(self, xml_root):
        """Parse the v1 xml schema
        """
        for src in xml_root.findall('./source'):
            source = {}
            source[self.EXTERNALS] = EMPTY_STR
            source[self.REQUIRED] = False
            source[self.PATH] = src.find(self._V1_TREE_PATH).text
            repo = {}
            xml_repo = src.find(self.REPO)
            repo[self.PROTOCOL] = xml_repo.get(self.PROTOCOL)
            repo[self.REPO_URL] = xml_repo.find(self._V1_ROOT).text
            repo[self.TAG] = xml_repo.find(self._V1_TAG)
            if repo[self.TAG] is not None:
                repo[self.TAG] = repo[self.TAG].text
            else:
                del repo[self.TAG]
            repo[self.BRANCH] = xml_repo.find(self._V1_BRANCH)
            if repo[self.BRANCH] is not None:
                repo[self.BRANCH] = repo[self.BRANCH].text
            else:
                del repo[self.BRANCH]
            source[self.REPO] = repo
            name = src.get(self.NAME).lower()
            self[name] = source
            required = xml_root.find(self.REQUIRED)
            if required is not None:
                for comp in required.findall(self._V1_REQ_SOURCE):
                    name = comp.text.lower()
                    self[name][self.REQUIRED] = True

    def _parse_xml_v2(self, xml_root):
        """Parse the xml v2 schema
        """
        for src in xml_root.findall('./source'):
            source = {}
            source[self.PATH] = src.find(self.PATH).text
            repo = {}
            xml_repo = src.find(self.REPO)
            repo[self.PROTOCOL] = xml_repo.get(self.PROTOCOL)
            repo[self.REPO_URL] = xml_repo.find(self.REPO_URL)
            if repo[self.REPO_URL] is not None:
                repo[self.REPO_URL] = repo[self.REPO_URL].text
            else:
                del repo[self.REPO_URL]
            repo[self.TAG] = xml_repo.find(self.TAG)
            if repo[self.TAG] is not None:
                repo[self.TAG] = repo[self.TAG].text
            else:
                del repo[self.TAG]
            repo[self.BRANCH] = xml_repo.find(self.BRANCH)
            if repo[self.BRANCH] is not None:
                repo[self.BRANCH] = repo[self.BRANCH].text
            else:
                del repo[self.BRANCH]
            source[self.REPO] = repo
            source[self.EXTERNALS] = src.find(self.EXTERNALS)
            if source[self.EXTERNALS] is not None:
                source[self.EXTERNALS] = source[self.EXTERNALS].text
            else:
                del source[self.EXTERNALS]
            required = src.get(self.REQUIRED).lower()
            source[self.REQUIRED] = self.str_to_bool(required)
            name = src.get(self.NAME).lower()
            self[name] = source

    @staticmethod
    def str_to_bool(bool_str):
        """Convert a sting representation of as boolean into a true boolean.
        """
        value = None
        if bool_str.lower() == 'true':
            value = True
        elif bool_str.lower() == 'false':
            value = False
        if value is None:
            msg = ('ERROR: invalid boolean string value "{0}". '
                   'Must be "true" or "false"'.format(bool_str))
            fatal_error(msg)
        return value

    @staticmethod
    def _get_xml_config_sourcetree(xml_root):
        """Return the config_sourcetree element with error checking.
        """
        st_str = 'config_sourcetree'
        xml_st = None
        if xml_root.tag == st_str:
            xml_st = xml_root
        else:
            xml_st = xml_root.find('./config_sourcetree')
        if xml_st is None:
            msg = 'ERROR: xml does not contain a "config_sourcetree" element.'
            fatal_error(msg)
        return xml_st

    @staticmethod
    def get_xml_schema_version(xml_st):
        """Get the xml schema version with error checking.
        """
        version = xml_st.get('version', None)
        if not version:
            msg = ('ERROR: xml config_sourcetree element must contain '
                   'a "version" attribute.')
            fatal_error(msg)
        return version.split('.')
