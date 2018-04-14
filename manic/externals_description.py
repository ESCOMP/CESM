#!/usr/bin/env python

"""Model description

Model description is the representation of the various externals
included in the model. It processes in input data structure, and
converts it into a standard interface that is used by the rest of the
system.

To maintain backward compatibility, externals description files should
follow semantic versioning rules, http://semver.org/



"""
from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import logging
import os
import os.path
import re

# ConfigParser was renamed in python2 to configparser. In python2,
# ConfigParser returns byte strings, str, instead of unicode. We need
# unicode to be compatible with xml and json parser and python3.
try:
    # python2
    from ConfigParser import SafeConfigParser as config_parser
    from ConfigParser import MissingSectionHeaderError
    from ConfigParser import NoSectionError, NoOptionError

    def config_string_cleaner(text):
        """convert strings into unicode
        """
        return text.decode('utf-8')
except ImportError:
    # python3
    from configparser import ConfigParser as config_parser
    from configparser import MissingSectionHeaderError
    from configparser import NoSectionError, NoOptionError

    def config_string_cleaner(text):
        """Python3 already uses unicode strings, so just return the string
        without modification.

        """
        return text

from .utils import printlog, fatal_error, str_to_bool, expand_local_url
from .global_constants import EMPTY_STR, PPRINTER, VERSION_SEPERATOR

#
# Globals
#
DESCRIPTION_SECTION = 'externals_description'
VERSION_ITEM = 'schema_version'


def read_externals_description_file(root_dir, file_name):
    """Given a file name containing a externals description, determine the
    format and read it into it's internal representation.

    """
    root_dir = os.path.abspath(root_dir)
    msg = 'In directory : {0}'.format(root_dir)
    logging.info(msg)
    printlog('Processing externals description file : {0}'.format(file_name))

    file_path = os.path.join(root_dir, file_name)
    if not os.path.exists(file_name):
        msg = ('ERROR: Model description file, "{0}", does not '
               'exist at path:\n    {1}\nDid you run from the root of '
               'the source tree?'.format(file_name, file_path))
        fatal_error(msg)

    externals_description = None
    try:
        config = config_parser()
        config.read(file_path)
        externals_description = config
    except MissingSectionHeaderError:
        # not a cfg file
        pass

    if externals_description is None:
        msg = 'Unknown file format!'
        fatal_error(msg)

    return externals_description


def create_externals_description(
        model_data, model_format='cfg', components=None):
    """Create the a externals description object from the provided data
    """
    externals_description = None
    if model_format == 'dict':
        externals_description = ExternalsDescriptionDict(
            model_data, components=components)
    elif model_format == 'cfg':
        major, _, _ = get_cfg_schema_version(model_data)
        if major == 1:
            externals_description = ExternalsDescriptionConfigV1(
                model_data, components=components)
        else:
            msg = ('Externals description file has unsupported schema '
                   'version "{0}".'.format(major))
            fatal_error(msg)
    else:
        msg = 'Unknown model data format "{0}"'.format(model_format)
        fatal_error(msg)
    return externals_description


def get_cfg_schema_version(model_cfg):
    """Extract the major, minor, patch version of the config file schema

    Params:
    model_cfg - config parser object containing the externas description data

    Returns:
    major = integer major version
    minor = integer minor version
    patch = integer patch version
    """
    semver_str = ''
    try:
        semver_str = model_cfg.get(DESCRIPTION_SECTION, VERSION_ITEM)
    except (NoSectionError, NoOptionError):
        msg = ('externals description file must have the required '
               'section: "{0}" and item "{1}"'.format(DESCRIPTION_SECTION,
                                                      VERSION_ITEM))
        fatal_error(msg)

    # NOTE(bja, 2017-11) Assume we don't care about the
    # build/pre-release metadata for now!
    version_list = re.split(r'[-+]', semver_str)
    version_str = version_list[0]
    version = version_str.split(VERSION_SEPERATOR)
    try:
        major = int(version[0].strip())
        minor = int(version[1].strip())
        patch = int(version[2].strip())
    except ValueError:
        msg = ('Config file schema version must have integer digits for '
               'major, minor and patch versions. '
               'Received "{0}"'.format(version_str))
        fatal_error(msg)
    return major, minor, patch


class ExternalsDescription(dict):
    """Base externals description class that is independent of the user input
    format. Different input formats can all be converted to this
    representation to provide a consistent represtentation for the
    rest of the objects in the system.

    NOTE(bja, 2018-03): do NOT define _schema_major etc at the class
    level in the base class. The nested/recursive nature of externals
    means different schema versions may be present in a single run!

    All inheriting classes must overwrite:
        self._schema_major and self._input_major
        self._schema_minor and self._input_minor
        self._schema_patch and self._input_patch

    where _schema_x is the supported schema, _input_x is the user
    input value.

    """
    # keywords defining the interface into the externals description data
    EXTERNALS = 'externals'
    BRANCH = 'branch'
    REPO = 'repo'
    REQUIRED = 'required'
    TAG = 'tag'
    PATH = 'local_path'
    PROTOCOL = 'protocol'
    REPO_URL = 'repo_url'
    HASH = 'hash'
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
                             HASH: 'string',
                             }
                      }

    def __init__(self):
        """Convert the xml into a standardized dict that can be used to
        construct the source objects

        """
        dict.__init__(self)

        self._schema_major = None
        self._schema_minor = None
        self._schema_patch = None
        self._input_major = None
        self._input_minor = None
        self._input_patch = None

    def _verify_schema_version(self):
        """Use semantic versioning rules to verify we can process this schema.

        """
        known = '{0}.{1}.{2}'.format(self._schema_major,
                                     self._schema_minor,
                                     self._schema_patch)
        received = '{0}.{1}.{2}'.format(self._input_major,
                                        self._input_minor,
                                        self._input_patch)

        if self._input_major != self._schema_major:
            # should never get here, the factory should handle this correctly!
            msg = ('DEV_ERROR: version "{0}" parser received '
                   'version "{1}" input.'.format(known, received))
            fatal_error(msg)

        if self._input_minor > self._schema_minor:
            msg = ('Incompatible schema version:\n'
                   '  User supplied schema version "{0}" is too new."\n'
                   '  Can only process version "{1}" files and '
                   'older.'.format(received, known))
            fatal_error(msg)

        if self._input_patch > self._schema_patch:
            # NOTE(bja, 2018-03) ignoring for now... Not clear what
            # conditions the test is needed.
            pass

    def _check_user_input(self):
        """Run a series of checks to attempt to validate the user input and
        detect errors as soon as possible.

        NOTE(bja, 2018-03) These checks are called *after* the file is
        read. That means the schema check can not occur here.

        Note: the order is important. check_optional will create
        optional with null data. run check_data first to ensure
        required data was provided correctly by the user.

        """
        self._check_data()
        self._check_optional()
        self._validate()

    def _check_data(self):
        """Check user supplied data is valid where possible.
        """
        for ext_name in self.keys():
            if (self[ext_name][self.REPO][self.PROTOCOL]
                    not in self.KNOWN_PRROTOCOLS):
                msg = 'Unknown repository protocol "{0}" in "{1}".'.format(
                    self[ext_name][self.REPO][self.PROTOCOL], ext_name)
                fatal_error(msg)

            if (self[ext_name][self.REPO][self.PROTOCOL] ==
                    self.PROTOCOL_SVN):
                if self.HASH in self[ext_name][self.REPO]:
                    msg = ('In repo description for "{0}". svn repositories '
                           'may not include the "hash" keyword.'.format(
                               ext_name))
                    fatal_error(msg)

            if (self[ext_name][self.REPO][self.PROTOCOL] !=
                    self.PROTOCOL_EXTERNALS_ONLY):
                ref_count = 0
                found_refs = ''
                if self.TAG in self[ext_name][self.REPO]:
                    ref_count += 1
                    found_refs = '"{0} = {1}", {2}'.format(
                        self.TAG, self[ext_name][self.REPO][self.TAG],
                        found_refs)
                if self.BRANCH in self[ext_name][self.REPO]:
                    ref_count += 1
                    found_refs = '"{0} = {1}", {2}'.format(
                        self.BRANCH, self[ext_name][self.REPO][self.BRANCH],
                        found_refs)
                if self.HASH in self[ext_name][self.REPO]:
                    ref_count += 1
                    found_refs = '"{0} = {1}", {2}'.format(
                        self.HASH, self[ext_name][self.REPO][self.HASH],
                        found_refs)

                if ref_count > 1:
                    msg = ('Model description is over specified! Only one of '
                           '"tag", "branch", or "hash" may be specified for '
                           'repo description of "{0}".'.format(ext_name))
                    msg = '{0}\nFound: {1}'.format(msg, found_refs)
                    fatal_error(msg)
                elif ref_count < 1:
                    msg = ('Model description is under specified! One of '
                           '"tag", "branch", or "hash" must be specified for '
                           'repo description of "{0}"'.format(ext_name))
                    fatal_error(msg)

                if self.REPO_URL not in self[ext_name][self.REPO]:
                    msg = ('Model description is under specified! Must have '
                           '"repo_url" in repo '
                           'description for "{0}"'.format(ext_name))
                    fatal_error(msg)

                url = expand_local_url(
                    self[ext_name][self.REPO][self.REPO_URL], ext_name)
                self[ext_name][self.REPO][self.REPO_URL] = url

    def _check_optional(self):
        """Some fields like externals, repo:tag repo:branch are
        (conditionally) optional. We don't want the user to be
        required to enter them in every externals description file, but
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
            if self.HASH not in self[field][self.REPO]:
                self[field][self.REPO][self.HASH] = EMPTY_STR
            if self.REPO_URL not in self[field][self.REPO]:
                self[field][self.REPO][self.REPO_URL] = EMPTY_STR

    def _validate(self):
        """Validate that the parsed externals description contains all necessary
        fields.

        """
        def print_compare_difference(data_a, data_b, loc_a, loc_b):
            """Look through the data structures and print the differences.

            """
            for item in data_a:
                if item in data_b:
                    if not isinstance(data_b[item], type(data_a[item])):
                        printlog("    {item}: {loc} = {val} ({val_type})".format(
                            item=item, loc=loc_a, val=data_a[item],
                            val_type=type(data_a[item])))
                        printlog("    {item}  {loc} = {val} ({val_type})".format(
                            item=' ' * len(item), loc=loc_b, val=data_b[item],
                            val_type=type(data_b[item])))
                else:
                    printlog("    {item}: {loc} = {val} ({val_type})".format(
                        item=item, loc=loc_a, val=data_a[item],
                        val_type=type(data_a[item])))
                    printlog("    {item}  {loc} missing".format(
                        item=' ' * len(item), loc=loc_b))

        def validate_data_struct(schema, data):
            """Compare a data structure against a schema and validate all required
            fields are present.

            """
            is_valid = False
            in_ref = True
            valid = True
            if isinstance(schema, dict) and isinstance(data, dict):
                # Both are dicts, recursively verify that all fields
                # in schema are present in the data.
                for k in schema:
                    in_ref = in_ref and (k in data)
                    if in_ref:
                        valid = valid and (
                            validate_data_struct(schema[k], data[k]))
                is_valid = in_ref and valid
            else:
                # non-recursive structure. verify data and schema have
                # the same type.
                is_valid = isinstance(data, type(schema))

            if not is_valid:
                printlog("  Unmatched schema and input:")
                if isinstance(schema, dict):
                    print_compare_difference(schema, data, 'schema', 'input')
                    print_compare_difference(data, schema, 'input', 'schema')
                else:
                    printlog("    schema = {0} ({1})".format(
                        schema, type(schema)))
                    printlog("    input = {0} ({1})".format(data, type(data)))

            return is_valid

        for field in self:
            valid = validate_data_struct(self._source_schema, self[field])
            if not valid:
                PPRINTER.pprint(self._source_schema)
                PPRINTER.pprint(self[field])
                msg = 'ERROR: source for "{0}" did not validate'.format(field)
                fatal_error(msg)


class ExternalsDescriptionDict(ExternalsDescription):
    """Create a externals description object from a dictionary using the API
    representations. Primarily used to simplify creating model
    description files for unit testing.

    """

    def __init__(self, model_data, components=None):
        """Parse a native dictionary into a externals description.
        """
        ExternalsDescription.__init__(self)
        self._schema_major = 1
        self._schema_minor = 0
        self._schema_patch = 0
        self._input_major = 1
        self._input_minor = 0
        self._input_patch = 0
        self._verify_schema_version()
        if components:
            for k in model_data.items():
                if k not in components:
                    del model_data[k]

        self.update(model_data)
        self._check_user_input()


class ExternalsDescriptionConfigV1(ExternalsDescription):
    """Create a externals description object from a config_parser object,
    schema version 1.

    """

    def __init__(self, model_data, components=None):
        """Convert the config data into a standardized dict that can be used to
        construct the source objects

        """
        ExternalsDescription.__init__(self)
        self._schema_major = 1
        self._schema_minor = 1
        self._schema_patch = 0
        self._input_major, self._input_minor, self._input_patch = \
            get_cfg_schema_version(model_data)
        self._verify_schema_version()
        self._remove_metadata(model_data)
        self._parse_cfg(model_data, components=components)
        self._check_user_input()

    @staticmethod
    def _remove_metadata(model_data):
        """Remove the metadata section from the model configuration file so
        that it is simpler to look through the file and construct the
        externals description.

        """
        model_data.remove_section(DESCRIPTION_SECTION)

    def _parse_cfg(self, cfg_data, components=None):
        """Parse a config_parser object into a externals description.
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
            if components and name not in components:
                continue
            self[name] = {}
            self[name].update(list_to_dict(cfg_data.items(section)))
            self[name][self.REPO] = {}
            loop_keys = self[name].copy().keys()
            for item in loop_keys:
                if item in self._source_schema:
                    if isinstance(self._source_schema[item], bool):
                        self[name][item] = str_to_bool(self[name][item])
                elif item in self._source_schema[self.REPO]:
                    self[name][self.REPO][item] = self[name][item]
                    del self[name][item]
                else:
                    msg = ('Invalid input: "{sect}" contains unknown '
                           'item "{item}".'.format(sect=name, item=item))
                    fatal_error(msg)
