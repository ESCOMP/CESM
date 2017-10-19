#!/usr/bin/env python

"""
Tool to assemble respositories represented in a model-description file.

If loaded as a module (e.g., in a component's buildcpp), it can be used
to check the validity of existing subdirectories and load missing sources.
"""
from __future__ import print_function, unicode_literals

import argparse
import errno
import json
import logging
import os
import os.path
import pprint
import re
import subprocess
import sys
import textwrap
import traceback
import xml.etree.ElementTree as ET

if sys.hexversion < 0x02070000:
    print(70 * '*')
    print('ERROR: {0} requires python >= 2.7.x. '.format(sys.argv[0]))
    print('It appears that you are running python {0}'.format(
        '.'.join(str(x) for x in sys.version_info[0:3])))
    print(70 * '*')
    sys.exit(1)

if sys.version_info[0] == 2:
    from ConfigParser import SafeConfigParser as config_parser
    import ConfigParser
else:
    from configparser import ConfigParser as config_parser


# ---------------------------------------------------------------------
#
# Global variables
#
# ---------------------------------------------------------------------
PPRINTER = pprint.PrettyPrinter(indent=4)
RE_NAMESPACE = re.compile(r'{[^}]*}')
EMPTY_STR = ''


# ---------------------------------------------------------------------
#
# User input
#
# ---------------------------------------------------------------------
def commandline_arguments():
    """Process the command line arguments
    """
    description = '''
%(prog)s manages checking out CESM from revision control based on a
model description file. By default only the required components of the
model are checkout out.

NOTE: %(prog)s should be run from the root of the source tree.
'''
    epilog = '''
Supported workflows:

  NOTE: %(prog)s should be run from the root of the source tree. For
  example, if you cloned CESM with:

    $ git clone git@github.com/ncar/cesm cesm-dev

  Then the root of the source tree is /path/to/cesm-dev, and will be
  referred to as ${SRC_ROOT}.

  * Checkout all required components from default model description file:

      $ cd ${SRC_ROOT}
      $ ./checkout_cesm/%(prog)s

  * Checkout all required components from a user specified model
    description file:

      $ cd ${SRC_ROOT}
      $ ./checkout_cesm/%(prog)s --model myCESM.xml

  * Status summary of the repositories managed by %(prog)s:

      $ cd ${SRC_ROOT}
      $ ./checkout_cesm/%(prog)s --status

         cime   master
      MM clm    my_branch
      M  rtm    my_branch
       M mosart my_branch

    where:
      * column one indicates whether the currently checkout branch is the
        same as in the model description file.
      * column two indicates whether the working copy has modified files.

      * M - modified : untracked or modified files exist
      * e - empty : directory does not exist - checkout_model has not been run
      * ? - unknown : directory exists but .git or .svn directories are missing
      *   - blank / space : clean or no changes

  * Status details of the repositories managed by %(prog)s:

      $ cd ${SRC_ROOT}
      $ ./checkout_cesm/%(prog)s --status --verbose

      Output of the 'status' command of the svn or git repository.

Model description file:

  The model description contains a list of the model components that
  are used and their version control locations. Each component has:

  * name (string) : component name, e.g. cime, cism, clm, cam, etc.

  * required (boolean) : whether the component is a required checkout

  * path (string) : component path *relative* to where %(prog)s
    is called.

  * protoctol (string) : version control protocol that is used to
    manage the component.  'externals_only' will only process the
    externals model description file without trying to checkout the
    current component. This is used for retreiving externals for
    standalone cam and clm. Valid values are 'git', 'svn',
    'externals_only'.

  * repo_url (string) : URL for the repository location, examples:
    * svn - https://svn-ccsm-models.cgd.ucar.edu/glc
    * git - git@github.com:esmci/cime.git
    * local - /path/to/local/repository

  * tag (string) : tag to checkout

  * branch (string) : branch to checkout

  * externals (string) filename of the external model description
    file that should also be used. It is *relative* to the component
    path. For example, the CESM model description will load clm. CLM
    has additional externals that must be downloaded to be
    complete. Those additional externals are managed by the file
    pointed to by 'externals'.

'''

    parser = argparse.ArgumentParser(
        description=description, epilog=epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    #
    # user options
    #
    parser.add_argument('-m', '--model', nargs='?', default='CESM.xml',
                        help='The model description filename. '
                        'Default: %(default)s.')

    parser.add_argument('-o', '--optional', action='store_true', default=False,
                        help='By default only the required model components '
                        'are checked out. This flag will also checkout the '
                        'optional componets of the model.')

    parser.add_argument('-s', '--status', action='store_true', default=False,
                        help='Output status of the repositories managed by '
                        'checkout_model. By default only summary information '
                        'is provided. Use verbose output to see details.')

    parser.add_argument('-v', '--verbose', action='store_true', default=False,
                        help='Output additional information to '
                        'the screen and log file.')

    #
    # developer options
    #
    parser.add_argument('--backtrace', action='store_true',
                        help='DEVELOPER: show exception backtraces as extra '
                        'debugging output')

    parser.add_argument('-d', '--debug', action='store_true', default=False,
                        help='DEVELOPER: output additional debugging '
                        'information to the screen and log file.')

    options = parser.parse_args()
    return options


# ---------------------------------------------------------------------
#
# Utility functions
#
# ---------------------------------------------------------------------
def fatal_error(message):
    """
    Error output function
    """
    logging.error(message)
    raise RuntimeError("{0}ERROR: {1}".format(os.linesep, message))


def check_output(commands):
    """
    Wrapper around subprocess.check_output to handle common exceptions.
    check_output runs a command with arguments and returns its output.
    On successful completion, check_output returns the command's output.
    """
    logging.info('In directory: {0}'.format(os.getcwd()))
    logging.info('check_output running command:')
    logging.info(commands)
    try:
        outstr = subprocess.check_output(commands)
    except OSError as error:
        printlog('Execution of "{0}" failed: {1}'.format(
            (' '.join(commands)), error), file=sys.stderr)
    except ValueError as error:
        printlog('ValueError in "{0}": {1}'.format(
            (' '.join(commands)), error), file=sys.stderr)
        outstr = None
    except subprocess.CalledProcessError as error:
        printlog('CalledProcessError in "{0}": {1}'.format(
            (' '.join(commands)), error), file=sys.stderr)
        outstr = None

    return outstr


def execute_subprocess(commands, status_to_caller=False):
    """Wrapper around subprocess.check_output to handle common
    exceptions.

    check_output runs a command with arguments and waits
    for it to complete.

    check_output raises an exception on a nonzero return code.  if
    status_to_caller is true, execute_subprocess returns the subprocess
    return code, otherwise execute_subprocess treats non-zero return
    status as an error and raises an exception.

    """
    logging.info('In directory: {0}'.format(os.getcwd()))
    logging.info('execute_subprocess running command:')
    logging.info(commands)
    status = -1
    try:
        logging.info(' '.join(commands))
        output = subprocess.check_output(commands, stderr=subprocess.STDOUT)
        log_process_output(output)
        status = 0
    except OSError as error:
        msg = 'Execution of "{0}" failed'.format(
            ' '.join(commands))
        logging.error(error)
        fatal_error(msg)
    except ValueError as error:
        msg = 'ValueError in "{0}"'.format(
            ' '.join(commands))
        logging.error(error)
        fatal_error(msg)
    except subprocess.CalledProcessError as error:
        msg = 'CalledProcessError in "{0}"'.format(
            ' '.join(commands))
        logging.error(error)
        status_msg = 'Returned : {0}'.format(error.returncode)
        logging.error(status_msg)
        log_process_output(error.output)
        if not status_to_caller:
            fatal_error(msg)
        status = error.returncode
    return status


def log_process_output(output):
    """Log each line of process output at debug level so it can be
    filtered if necessary. By default, output is a single string, and
    logging.debug(output) will only put log info heading on the first
    line. This makes it hard to filter with grep.

    """
    output = output.split('\n')
    for line in output:
        logging.debug(line)


def printlog(msg, **kwargs):
    """Wrapper script around print to ensure that everything printed to
    the screen also gets logged.

    """
    logging.info(msg)
    if kwargs:
        print(msg, **kwargs)
    else:
        print(msg)


def strip_namespace(tag):
    """
    Remove a curly brace-encased namespace, if any.
    """
    match = RE_NAMESPACE.match(tag)
    if match is None:
        stripped_tag = tag
    else:
        stripped_tag = tag[len(match.group(0)):]

    return stripped_tag


# ---------------------------------------------------------------------
#
# Worker utilities
#
# ---------------------------------------------------------------------
def create_repository(component_name, repo_info):
    """Determine what type of repository we have, i.e. git or svn, and
    create the appropriate object.

    """
    protocol = repo_info[ModelDescription.PROTOCOL].lower()
    if protocol == 'git':
        repo = GitRepository(component_name, repo_info)
    elif protocol == 'svn':
        repo = SvnRepository(component_name, repo_info)
    elif protocol == 'externals_only':
        repo = None
    else:
        msg = 'Unknown repo protocol "{0}"'.format(protocol)
        fatal_error(msg)
    return repo


def read_model_description_file(root_dir, file_name):
    """Given a file name containing a model description, determine the
    format and read it into it's internal representation.

    """
    root_dir = os.path.abspath(root_dir)

    logging.info('In directory : {0}'.format(root_dir))
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
            xml_tree = ET.parse(filehandle)
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
    PATH = 'path'
    PROTOCOL = 'protocol'
    REPO_URL = 'repo_url'
    NAME = 'name'

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
        else:
            msg = 'Unknown model data format "{0}"'.format(model_format)
            fatal_error(msg)
        self._validate()

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

    def _parse_cfg(self, cfg_data):
        """Parse a config_parser object into a model description.
        """
        def str_to_bool(bool_str):
            """Convert a sting representation of as boolean into a true boolean.
            """
            value = None
            if bool_str == 'true'.lower():
                value = True
            elif bool_str == 'false'.lower():
                value = False
            if value is None:
                msg = ('ERROR: invalid boolean string value "{0}". '
                       'Must be "true" or "false"'.format(bool_str))
                fatal_error(msg)
            return value

        def list_to_dict(input_list, convert_to_lower_case=True):
            """Convert a list of key-value pairs into a dictionary.
            """
            output_dict = {}
            for item in input_list:
                key = unicode(item[0].strip())
                value = unicode(item[1].strip())
                if convert_to_lower_case:
                    key = key.lower()
                output_dict[key] = value
            return output_dict

        for section in cfg_data.sections():
            name = unicode(section.lower().strip())
            self[name] = {}
            self[name].update(list_to_dict(cfg_data.items(section)))
            self[name][self.REPO] = {}
            for item in self[name].keys():
                if item in self._source_schema:
                    if isinstance(self._source_schema[item], bool):
                        self[name][item] = str_to_bool(self[name][item])
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
            source[self.PATH] = unicode(src.find(self._V1_TREE_PATH).text)
            repo = {}
            xml_repo = src.find(self.REPO)
            repo[self.PROTOCOL] = unicode(xml_repo.get(self.PROTOCOL))
            repo[self.REPO_URL] = unicode(xml_repo.find(self._V1_ROOT).text)
            repo[self.TAG] = xml_repo.find(self._V1_TAG)
            if repo[self.TAG] is not None:
                repo[self.TAG] = unicode(repo[self.TAG].text)
            else:
                repo[self.TAG] = EMPTY_STR
            repo[self.BRANCH] = xml_repo.find(self._V1_BRANCH)
            if repo[self.BRANCH] is not None:
                repo[self.BRANCH] = unicode(repo[self.BRANCH].text)
            else:
                repo[self.BRANCH] = EMPTY_STR
            source[self.REPO] = repo
            name = unicode(src.get(self.NAME).lower())
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
            source[self.PATH] = unicode(src.find(self.PATH).text)
            repo = {}
            xml_repo = src.find(self.REPO)
            repo[self.PROTOCOL] = unicode(xml_repo.get(self.PROTOCOL))
            repo[self.REPO_URL] = xml_repo.find(self.REPO_URL)
            if repo[self.REPO_URL] is not None:
                repo[self.REPO_URL] = unicode(repo[self.REPO_URL].text)
            repo[self.TAG] = xml_repo.find(self.TAG)
            if repo[self.TAG] is not None:
                repo[self.TAG] = unicode(repo[self.TAG].text)
            else:
                repo[self.TAG] = EMPTY_STR
            repo[self.BRANCH] = xml_repo.find(self.BRANCH)
            if repo[self.BRANCH] is not None:
                repo[self.BRANCH] = unicode(repo[self.BRANCH].text)
            else:
                repo[self.BRANCH] = EMPTY_STR
            source[self.REPO] = repo
            source[self.EXTERNALS] = src.find(self.EXTERNALS)
            if source[self.EXTERNALS] is not None:
                source[self.EXTERNALS] = unicode(source[self.EXTERNALS].text)
            else:
                source[self.EXTERNALS] = EMPTY_STR
            required = unicode(src.get(self.REQUIRED).lower())
            if required == 'false':
                source[self.REQUIRED] = False
            elif required == 'true':
                source[self.REQUIRED] = True
            else:
                msg = 'ERROR: unknown value for attribute "required" = "{0}" '.format(
                    required)
                fatal_error(msg)
            name = src.get(self.NAME).lower()
            self[name] = source

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


# ---------------------------------------------------------------------
#
# Worker classes
#
# ---------------------------------------------------------------------
class Status(object):
    """Class to represent the status of a given source repository or tree.

    Individual repositories determine their own status in the
    Repository objects. This object is just resposible for storing the
    information and passing it up to a higher level for reporting or
    global decisions.

    There are two states of concern:

    * If the repository is in-sync with the model description file.

    * If the repostiory working copy is clean and there are no pending
    transactions (e.g. add, remove, rename, untracked files).

    """
    DEFAULT = '*'
    MODIFIED = 'M'
    EMPTY = 'e'
    UNKNOWN = '?'
    OK = ' '

    def __init__(self):
        self.sync_state = self.DEFAULT
        self.clean_state = self.DEFAULT
        self.path = EMPTY_STR

    def __str__(self):
        msg = '{sync}{clean} {path}'.format(
            sync=self.sync_state, clean=self.clean_state, path=self.path)
        return msg

    def safe_to_update(self):
        """Report if it is safe to update a repository. Safe is defined as:

        * If a repository is empty, it is safe to update.

        * If a repository exists and has a clean working copy state
        with no pending transactions.

        """
        safe_to_update = False
        repo_exists = self.exists()
        if not repo_exists:
            safe_to_update = True
        else:
            # If the repo exists, it must be in ok or modified
            # sync_state. Any other sync_state at this point
            # represents a logic error that should have been handled
            # before now!
            sync_safe = ((self.sync_state == Status.OK) or
                         (self.sync_state == Status.MODIFIED))
            if sync_safe:
                # The clean_state must be OK to update. Otherwise we
                # are dirty or there was a missed error previously.
                if self.clean_state == Status.OK:
                    safe_to_update = True
        return safe_to_update

    def exists(self):
        """Determine if the repo exists. This is indicated by:

        * sync_state is not EMPTY

            * if the sync_state is empty, then the valid states for
              clean_state are default, empty or unknown. Anything else
              and there was probably an internal logic error.

        NOTE(bja, 2017-10) For the moment we are considering a
        sync_state of default or unknown to require user intervention,
        but we may want to relax this convention. This is probably a
        result of a network error or internal logic error but more
        testing is needed.

        """
        is_empty = (self.sync_state == Status.EMPTY)
        clean_valid = ((self.clean_state == Status.DEFAULT) or
                       (self.clean_state == Status.EMPTY) or
                       (self.clean_state == Status.UNKNOWN))

        if is_empty and clean_valid:
            exists = False
        else:
            exists = True
        return exists


class Repository(object):
    """
    Class to represent and operate on a repository description.
    """

    def __init__(self, component_name, repo):
        """
        Parse repo model description
        """
        self._name = component_name
        self._protocol = repo[ModelDescription.PROTOCOL]
        self._tag = repo[ModelDescription.TAG]
        self._branch = repo[ModelDescription.BRANCH]
        self._url = repo[ModelDescription.REPO_URL]

        if self._url is EMPTY_STR:
            fatal_error('repo must have a URL')

        if self._tag is EMPTY_STR and self._branch is EMPTY_STR:
            fatal_error('repo must have either a branch or a tag element')

        if self._tag is not EMPTY_STR and self._branch is not EMPTY_STR:
            fatal_error('repo cannot have both a tag and a branch element')

    def checkout(self, repo_dir):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        msg = ('DEV_ERROR: checkout method must be implemented in all '
               'repository classes! {0}'.format(self.__class__.__name__))
        fatal_error(msg)

    def status(self, stat, repo_dir):
        """Report the status of the repo

        """
        msg = ('DEV_ERROR: status method must be implemented in all '
               'repository classes! {0}'.format(self.__class__.__name__))
        fatal_error(msg)

    def verbose_status(self, repo_dir):
        """Display the raw repo status to the user.

        """
        msg = ('DEV_ERROR: status method must be implemented in all '
               'repository classes! {0}'.format(self.__class__.__name__))
        fatal_error(msg)

    def url(self):
        """Public access of repo url.
        """
        return self._url

    def tag(self):
        """Public access of repo tag
        """
        return self._tag

    def branch(self):
        """Public access of repo branch.
        """
        return self._branch


class SvnRepository(Repository):
    """
    Class to represent and operate on a repository description.
    """
    RE_URLLINE = re.compile(r'^URL:')

    def __init__(self, component_name, repo):
        """
        Parse repo (a <repo> XML element).
        """
        Repository.__init__(self, component_name, repo)
        if self._branch:
            self._url = os.path.join(self._url, self._branch)
        elif self._tag:
            self._url = os.path.join(self._url, self._tag)
        else:
            msg = "DEV_ERROR in svn repository. Shouldn't be here!"
            fatal_error(msg)

    def status(self, stat, repo_dir):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        self.svn_check_sync(stat, repo_dir)
        if os.path.exists(repo_dir):
            self.svn_status(stat, repo_dir)
        return stat

    def verbose_status(self, repo_dir):
        """Display the raw repo status to the user.

        """
        repo_path = os.path.join(repo_dir, self._name)
        if os.path.exists(repo_path):
            self.svn_status_verbose(repo_path)

    def checkout(self, repo_dir):
        """Checkout or update the working copy

        If the repo destination directory exists, switch the sandbox to
        match the model description.

        If the repo destination directory does not exist, checkout the
        correct branch or tag.

        """
        if os.path.exists(repo_dir):
            self._svn_switch(repo_dir)
        else:
            self._svn_checkout(repo_dir)

        return True

    def _svn_checkout(self, checkout_dir):
        """
        Checkout a subversion repository (repo_url) to checkout_dir.
        """
        cmd = ['svn', 'checkout', self._url, checkout_dir]
        execute_subprocess(cmd)

    def _svn_switch(self, repo_dir):
        """
        Switch branches for in an svn sandbox
        """
        cwd = os.getcwd()
        os.chdir(repo_dir)
        cmd = ['svn', 'switch', self._url]
        execute_subprocess(cmd)
        os.chdir(cwd)

    @staticmethod
    def _svn_update(updir):
        """
        Refresh a subversion sandbox (updir)
        """
        mycurrdir = os.path.abspath('.')
        os.chdir(updir)
        execute_subprocess(['svn', 'update'])
        os.chdir(mycurrdir)

    @staticmethod
    def svn_info(repo_dir):
        """Return results of svn info command
        """
        cmd = ['svn', 'info', repo_dir]
        try:
            output = check_output(cmd)
        except subprocess.CalledProcessError as e:
            logging.info(e)
            output = ''
        return output

    @staticmethod
    def svn_check_url(svn_output, expected_url):
        """Determine the svn url from svn info output and return whether it
        matches the expected value.

        """
        url = None
        for line in svn_output.splitlines():
            if SvnRepository.RE_URLLINE.match(line):
                url = line.split(': ')[1].strip()
                break
        if not url:
            status = Status.UNKNOWN
        elif url == expected_url:
            status = Status.OK
        else:
            status = Status.MODIFIED
        return status

    def svn_check_sync(self, stat, repo_dir):
        """Check to see if repository directory exists and is at the expected
        url.  Return: status object

        """
        if not os.path.exists(repo_dir):
            stat.sync_state = Status.EMPTY
        else:
            svn_output = self.svn_info(repo_dir)
            if not svn_output:
                stat.sync_state = Status.UNKNOWN
            else:
                stat.sync_state = self.svn_check_url(svn_output, self._url)

    @staticmethod
    def _svn_status_xml(repo_dir):
        """
        Get status of the subversion sandbox in repo_dir
        """
        cmd = ['svn', 'status', '--xml', repo_dir]
        svn_output = check_output(cmd)
        return svn_output

    @staticmethod
    def xml_status_is_dirty(svn_output):
        """Parse svn status xml output and determine if the working copy is
        clean or dirty. Dirty is defined as:

        * modified files
        * added files
        * deleted files
        * missing files
        * unversioned files

        """
        SVN_MISSING = 'missing'
        SVN_MODIFIED = 'modified'
        SVN_DELETED = 'deleted'
        SVN_UNVERSIONED = 'unversioned'
        SVN_ADDED = 'added'
        svn_dirty = [SVN_MISSING, SVN_MODIFIED,
                     SVN_DELETED, SVN_UNVERSIONED, SVN_ADDED]
        is_dirty = False
        xml_status = ET.fromstring(svn_output)
        xml_target = xml_status.find('./target')
        entries = xml_target.findall('./entry')
        for entry in entries:
            status = entry.find('./wc-status')
            item = status.get('item')
            if item in svn_dirty:
                is_dirty = True
        return is_dirty

    def svn_status(self, stat, repo_dir):
        """Report whether the svn repository is in-sync with the model
        description and whether the sandbox is clean or dirty.

        """
        svn_output = self._svn_status_xml(repo_dir)
        is_dirty = self.xml_status_is_dirty(svn_output)
        if is_dirty:
            stat.clean_state = Status.MODIFIED
        else:
            stat.clean_state = Status.OK

    @staticmethod
    def _svn_status_verbose(repo_dir):
        """capture the full svn status output
        """
        cmd = ['svn', 'status', repo_dir]
        svn_output = check_output(cmd)
        return svn_output

    def svn_status_verbose(self, repo_dir):
        """Display the raw svn status output to the user.

        """
        svn_output = self._svn_status_verbose(repo_dir)
        log_process_output(svn_output)
        print(svn_output)


class GitRepository(Repository):
    """
    Class to represent and operate on a repository description.
    """

    GIT_REF_UNKNOWN = 'unknown'
    GIT_REF_LOCAL_BRANCH = 'localBranch'
    GIT_REF_REMOTE_BRANCH = 'remoteBranch'
    GIT_REF_TAG = 'gitTag'
    GIT_REF_SHA1 = 'gitSHA1'

    RE_GITHASH = re.compile(r"\A([a-fA-F0-9]+)\Z")
    RE_REMOTEBRANCH = re.compile(r"\s*origin/(\S+)")

    def __init__(self, component_name, repo):
        """
        Parse repo (a <repo> XML element).
        """
        Repository.__init__(self, component_name, repo)

    def checkout(self, repo_dir):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        self._git_checkout(repo_dir)

        return True

    def status(self, stat, repo_dir):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        self.git_check_sync(stat, repo_dir)
        if os.path.exists(repo_dir):
            self.git_status(stat, repo_dir)

    def verbose_status(self, repo_dir):
        """Display the raw repo status to the user.

        """
        if os.path.exists(repo_dir):
            self.git_status_verbose(repo_dir)

    def _git_ref_type(self, ref):
        """
        Determine if 'ref' is a local branch, a remote branch, a tag, or a
        commit.
        Should probably use this command instead:
        git show-ref --verify --quiet refs/heads/<branch-name>
        """
        ref_type = self.GIT_REF_UNKNOWN
        # First check for local branch
        gitout = check_output(['git', 'branch'])
        if gitout is not None:
            branches = [x.lstrip('* ') for x in gitout.splitlines()]
            for branch in branches:
                if branch == ref:
                    ref_type = self.GIT_REF_LOCAL_BRANCH
                    break

        # Next, check for remote branch
        if ref_type == self.GIT_REF_UNKNOWN:
            gitout = check_output(['git', 'branch', '-r'])
            if gitout is not None:
                for branch in gitout.splitlines():
                    match = GitRepository.RE_REMOTEBRANCH.match(branch)
                    if (match is not None) and (match.group(1) == ref):
                        ref_type = self.GIT_REF_REMOTE_BRANCH
                        break

        # Next, check for a tag
        if ref_type == self.GIT_REF_UNKNOWN:
            gitout = check_output(['git', 'tag'])
            if gitout is not None:
                for tag in gitout.splitlines():
                    if tag == ref:
                        ref_type = self.GIT_REF_TAG
                        break

        # Finally, see if it just looks like a commit hash
        if ((ref_type == self.GIT_REF_UNKNOWN) and
                GitRepository.RE_GITHASH.match(ref)):
            ref_type = self.GIT_REF_SHA1

        # Return what we've come up with
        return ref_type

    @staticmethod
    def _git_current_branch():
        """
        Return the (current branch, sha1 hash) of working copy in wdir
        """
        branch = check_output(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
        git_hash = check_output(['git', 'rev-parse', 'HEAD'])
        if branch is not None:
            branch = branch.rstrip()

        if git_hash is not None:
            git_hash = git_hash.rstrip()

        return (branch, git_hash)

    @staticmethod
    def git_branch():
        """Run the git branch command
        """
        cmd = ['git', 'branch']
        git_output = check_output(cmd)
        return git_output

    @staticmethod
    def current_ref_from_branch_command(git_output):
        """Parse output of the 'git branch' command to determine the current branch.
        The line starting with '*' is the current branch. It can be one of:

        On a branch:
        * cm-testing

        Detached head from a tag:
        * (HEAD detached at junk-tag)

        Detached head from a hash
        * (HEAD detached at 0246874c)

        NOTE: Parsing the output of the porcelain is probably not a
        great idea, but there doesn't appear to be a single plumbing
        command that will return the same info.

        """
        lines = git_output.splitlines()
        current_branch = None
        for line in lines:
            if line.startswith('*'):
                current_branch = line
        ref = EMPTY_STR
        if current_branch:
            if 'detached' in current_branch:
                ref = current_branch.split(' ')[-1]
                ref = ref.strip(')')
            else:
                ref = current_branch.split()[-1]
        return ref

    def git_check_sync(self, stat, repo_dir):
        """Determine whether a git repository is in-sync with the model
        description.

        Because repos can have multiple remotes, the only criteria is
        whether the branch or tag is the same.

        """
        current_dir = os.path.abspath('.')
        if not os.path.exists(repo_dir):
            stat.sync_state = Status.EMPTY
        else:
            git_dir = os.path.join(repo_dir, '.git')
            if not os.path.exists(git_dir):
                stat.sync_state = Status.UNKNOWN
            else:
                os.chdir(repo_dir)
                git_output = self.git_branch()
                ref = self.current_ref_from_branch_command(git_output)
                if ref == EMPTY_STR:
                    stat.sync_state = Status.UNKNOWN
                elif self._tag:
                    if self._tag == ref:
                        stat.sync_state = Status.OK
                    else:
                        stat.sync_state = Status.MODIFIED
                else:
                    if self._branch == ref:
                        stat.sync_state = Status.OK
                    else:
                        stat.sync_state = Status.MODIFIED
        os.chdir(current_dir)

    @staticmethod
    def _git_check_dir(chkdir, ref):
        """
        Check to see if directory (chkdir) exists and is the correct
        treeish (ref)
        Return True (correct), False (incorrect) or None (chkdir not found)
        """
        refchk = None
        mycurrdir = os.path.abspath('.')
        if os.path.exists(chkdir):
            if os.path.exists(os.path.join(chkdir, '.git')):
                os.chdir(chkdir)
                head = check_output(['git', 'rev-parse', 'HEAD'])
                if ref is not None:
                    refchk = check_output(['git', 'rev-parse', ref])

            else:
                head = None

            if ref is None:
                status = head is not None
            elif refchk is None:
                status = None
            else:
                status = (head == refchk)
        else:
            status = None

        os.chdir(mycurrdir)
        return status

    @staticmethod
    def _git_working_dir_clean(wdir):
        """
        Return True if wdir is clean or False if there are modifications
        """
        mycurrdir = os.path.abspath('.')
        os.chdir(wdir)
        cmd = ['git', 'diff', '--quiet', '--exit-code']
        retcode = execute_subprocess(cmd, status_to_caller=True)
        os.chdir(mycurrdir)
        return retcode == 0

    def _git_remote(self, repo_dir):
        """
        Return the remote for the current branch or tag
        """
        mycurrdir = os.path.abspath(".")
        os.chdir(repo_dir)
        # Make sure we are on a remote-tracking branch
        (curr_branch, _) = self._git_current_branch()
        ref_type = self._git_ref_type(curr_branch)
        if ref_type == self.GIT_REF_REMOTE_BRANCH:
            remote = check_output(
                ['git', 'config', 'branch.{0}.remote'.format(curr_branch)])
        else:
            remote = None

        os.chdir(mycurrdir)
        return remote

    # Need to decide how to do this. Just doing pull for now
    def _git_update(self, repo_dir):
        """
        Do an update and a FF merge if possible
        """
        mycurrdir = os.path.abspath('.')
        os.chdir(repo_dir)
        remote = self._git_remote(repo_dir)
        if remote is not None:
            cmd = ['git', 'remote', 'update', '--prune', remote]
            execute_subprocess(cmd)

        cmd = ['git', 'merge', '--ff-only', '@{u}']
        execute_subprocess(cmd)
        os.chdir(mycurrdir)

    def _git_checkout(self, checkout_dir):
        """
        Checkout 'branch' or 'tag' from 'repo_url'
        """
        mycurrdir = os.path.abspath('.')
        if os.path.exists(checkout_dir):
            # We can't do a clone. See what we have here
            if self._git_check_dir(checkout_dir, None):
                os.chdir(checkout_dir)
                # We have a git repo, is it from the correct URL?
                cmd = ['git', 'config', 'remote.origin.url']
                check_url = check_output(cmd)
                if check_url is not None:
                    check_url = check_url.rstrip()

                if check_url != self._url:
                    msg = ("Invalid repository in {0}, url = {1}, "
                           "should be {2}".format(checkout_dir, check_url,
                                                  self._url))
                    fatal_error(msg)
                # FIXME(bja, 2017-09) we are updating an existing
                # clone. Need to do a fetch here to ensure that the
                # branch or tag checkout will work

        else:
            cmd = ['git', 'clone', self._url, checkout_dir]
            execute_subprocess(cmd)
            os.chdir(checkout_dir)

        cmd = []
        if self._branch:
            (curr_branch, _) = self._git_current_branch()
            ref_type = self._git_ref_type(self._branch)
            if ref_type == self.GIT_REF_REMOTE_BRANCH:
                cmd = ['git', 'checkout', '--track', 'origin/' + self._branch]
            elif ref_type == self.GIT_REF_LOCAL_BRANCH:
                if curr_branch != self._branch:
                    if not self._git_working_dir_clean(checkout_dir):
                        msg = ('Working directory "{0}" not clean, '
                               'aborting'.format(checkout_dir))
                        fatal_error(msg)
                    else:
                        cmd = ['git', 'checkout', self._branch]

            else:
                msg = 'Unable to check out branch, "{0}"'.format(self._branch)
                fatal_error(msg)

        elif self._tag:
            # For now, do a hail mary and hope tag can be checked out
            cmd = ['git', 'checkout', self._tag]
        else:
            msg = "DEV_ERROR: in git repo. Shouldn't be here!"
            fatal_error(msg)

        if cmd:
            execute_subprocess(cmd)

        os.chdir(mycurrdir)

    @staticmethod
    def git_status_porcelain_v1z():
        """Run the git status command on the cwd and report results in the
        machine parable format that is guarenteed not to change
        between version or user configuration.

        """
        cmd = ['git', 'status', '--porcelain=v1', '-z']
        git_output = check_output(cmd)
        return git_output

    @staticmethod
    def git_status_v1z_is_dirty(git_output):
        """Parse the git status output from --porcelain=v1 -z and determine if
        the repo status is clean or dirty. Dirty means:

        * modified files
        * missing files
        * added files
        * untracked files
        * removed
        * renamed
        * unmerged

        NOTE: Based on the above definition, the porcelain status
        should be an empty string to be considered 'clean'. Of course
        this assumes we only get an empty string from an status
        command on a clean checkout, and not some error condition...

        GIT_DELETED = 'D'
        GIT_MODIFIED = 'M'
        GIT_UNTRACKED = '?'
        GIT_RENAMED = 'R'
        GIT_COPIED = 'C'
        GIT_UNMERGED = 'U'
        git_dirty[GIT_DELETED, GIT_MODIFIED, GIT_UNTRACKED, GIT_RENAMED,
                  GIT_COPIED, GIT_UNMERGED, ]
        git_output = git_output.split('\0')

        """
        is_dirty = False
        if git_output:
            is_dirty = True
        return is_dirty

    def git_status(self, stat, repo_dir):
        """Determine the clean/dirty status of a git repository

        """
        cwd = os.getcwd()
        os.chdir(repo_dir)
        git_output = self.git_status_porcelain_v1z()
        is_dirty = self.git_status_v1z_is_dirty(git_output)
        if is_dirty:
            stat.clean_state = Status.MODIFIED
        else:
            stat.clean_state = Status.OK
        os.chdir(cwd)

    @staticmethod
    def _git_status_verbose():
        """Run the git status command and capture the output
        """
        cmd = ['git', 'status']
        git_output = check_output(cmd)
        return git_output

    def git_status_verbose(self, repo_dir):
        """Display raw git status output to the user

        """
        cwd = os.getcwd()
        os.chdir(repo_dir)
        git_output = self._git_status_verbose()
        log_process_output(git_output)
        print(git_output)
        os.chdir(cwd)


class _Source(object):
    """
    _Source represents a <source> object in a <config_sourcetree>
    """

    def __init__(self, name, source):
        """
        Parse an XML node for a <source> tag
        """
        self._name = name
        self._repos = []
        self._loaded = False
        self._externals = EMPTY_STR
        self._externals_sourcetree = None
        # Parse the sub-elements
        self._path = source[ModelDescription.PATH]
        self._repo_dir = os.path.basename(self._path)
        self._externals = source[ModelDescription.EXTERNALS]
        if self._externals:
            self._create_externals_sourcetree()
        repo = create_repository(name, source[ModelDescription.REPO])
        self._loaded = False
        if repo is None:
            self._loaded = True
        else:
            self._repos.append(repo)

    def get_name(self):
        """
        Return the source object's name
        """
        return self._name

    def get_path(self):
        """
        Return the source object's path
        """
        return self._path

    def status(self, tree_root):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        If load_all is True, also load all of the the sources sub-sources.
        """

        stat = Status()
        stat.path = self.get_path()
        ext_stats = {}
        # Make sure we are in correct location
        mycurrdir = os.path.abspath('.')
        pdir = os.path.join(tree_root, os.path.dirname(self._path))
        if not os.path.exists(pdir):
            stat.sync_state = Status.EMPTY
        else:
            os.chdir(pdir)

            repo_loaded = self._loaded
            if not repo_loaded:
                for repo in self._repos:
                    repo.status(stat, self._repo_dir)

            if self._externals:
                comp_dir = os.path.join(tree_root, self._path)
                os.chdir(comp_dir)
                ext_stats = self._externals_sourcetree.status()

            os.chdir(mycurrdir)

        all_stats = {}
        if self._path != '.':
            # '.' paths are standalone component directories that are
            # not managed by checkout_model.
            all_stats[self._name] = stat
        if ext_stats:
            all_stats.update(ext_stats)

        return all_stats

    def verbose_status(self, tree_root):
        """Display the verbose status to the user. This is just the raw output
        from the repository 'status' command.

        """
        repo_dir = os.path.join(tree_root, os.path.dirname(self.get_path()))
        if not os.path.exists(repo_dir):
            msg = ('Repository directory for "{0}" is empty or does not '
                   'exist!'.format(self._name))
            printlog(msg)
        else:
            cwd = os.getcwd()
            os.chdir(repo_dir)
            for repo in self._repos:
                repo.verbose_status(repo_dir)
            os.chdir(cwd)

    def checkout(self, tree_root, load_all):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        If load_all is True, also load all of the the sources sub-sources.
        """
        if load_all:
            pass
        # Make sure we are in correct location
        mycurrdir = os.path.abspath('.')
        pdir = os.path.join(tree_root, os.path.dirname(self._path))
        if not os.path.exists(pdir):
            try:
                os.makedirs(pdir)
            except OSError as error:
                if error.errno != errno.EEXIST:
                    msg = 'Could not create directory "{0}"'.format(pdir)
                    fatal_error(msg)

        os.chdir(pdir)

        repo_loaded = self._loaded
        if not repo_loaded:
            for repo in self._repos:
                repo_loaded = repo.checkout(self._repo_dir)
                if repo_loaded:
                    break

        self._loaded = repo_loaded

        if self._externals:
            comp_dir = os.path.join(tree_root, self._path)
            os.chdir(comp_dir)
            self._externals_sourcetree.checkout(load_all)

        os.chdir(mycurrdir)
        return repo_loaded

    def _create_externals_sourcetree(self):
        """
        """
        if not os.path.exists(self._externals):
            msg = ('External model description file "{0}" '
                   'does not exist!'.format(self._externals))
            fatal_error(msg)
        ext_root = self._path
        model_format, model_data = read_model_description_file(
            ext_root, self._externals)
        externals = ModelDescription(model_format, model_data)
        self._externals_sourcetree = SourceTree(ext_root, externals)


class SourceTree(object):
    """
    SourceTree represents a <config_sourcetree> object
    """

    def __init__(self, root_dir, model):
        """
        Parse a model file into a SourceTree object
        """
        self._root_dir = root_dir
        self._all_components = {}
        self._required_compnames = []
        for comp in model:
            src = _Source(comp, model[comp])
            self._all_components[comp] = src
            if model[comp][ModelDescription.REQUIRED]:
                self._required_compnames.append(comp)

    def status(self):
        """Report the status components

        FIXME(bja, 2017-10) what do we do about situations where the
        user checked out the optional components, but didn't add
        optional for running status? What do we do where the user
        didn't add optional to the checkout but did add it to the
        status. -- For now, we run status on all components, and try
        to do the right thing based on the results....

        """
        load_comps = self._all_components.keys()

        summary = {}
        for comp in load_comps:
            printlog('{0}, '.format(comp), end='')
            stat = self._all_components[comp].status(self._root_dir)
            summary.update(stat)

        return summary

    def verbose_status(self):
        """Display verbose status to the user. This is just the raw output of
        the git and svn status commands.

        """
        load_comps = self._all_components.keys()
        for comp in load_comps:
            self._all_components[comp].verbose_status(self._root_dir)

    def checkout(self, load_all, load_comp=None):
        """
        Checkout or update indicated components into the the configured
        subdirs.

        If load_all is True, recursively checkout all sources.
        If load_all is False, load_comp is an optional set of components to load.
        If load_all is True and load_comp is None, only load the required sources.
        """
        if load_all:
            load_comps = self._all_components.keys()
        elif load_comp is not None:
            load_comps = [load_comp]
        else:
            load_comps = self._required_compnames

        for comp in load_comps:
            printlog('{0}, '.format(comp), end='')
            self._all_components[comp].checkout(self._root_dir, load_all)


def check_safe_to_update_repos(tree_status, debug):
    """Check if *ALL* repositories are in a safe state to update. We don't
    want to do a partial update of the repositories then die, leaving
    the model in an inconsistent state.

    Note: if there is an update to do, the repositories will by
    definiation be out of synce with the model description, so we
    can't use that as criteria for updating.

    """
    safe_to_update = True
    for comp in tree_status:
        stat = tree_status[comp]
        if debug:
            printlog('{0} - {1} sync {2} clean {3}'.format(
                comp, stat.safe_to_update(), stat.sync_state,
                stat.clean_state))

        safe_to_update &= stat.safe_to_update()
    return safe_to_update


# ---------------------------------------------------------------------
#
# main
#
# ---------------------------------------------------------------------
def _main(args):
    """
    Function to call when module is called from the command line.
    Parse model file and load required repositories or all repositories if
    the --all option is passed.
    """
    logging.basicConfig(filename='checkout_model.log',
                        format='%(levelname)s : %(asctime)s : %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S',
                        level=logging.DEBUG)
    logging.info('Begining of checkout_model')

    load_all = False
    if args.optional:
        load_all = True

    root_dir = os.path.abspath('.')
    model_format, model_data = read_model_description_file(
        root_dir, args.model)
    model = ModelDescription(model_format, model_data)
    if args.debug:
        PPRINTER.pprint(model)

    source_tree = SourceTree(root_dir, model)
    printlog('Checking status of components: ', end='')
    tree_status = source_tree.status()
    printlog('')

    if args.status:
        # user requested status-only
        for comp in tree_status:
            msg = str(tree_status[comp])
            printlog(msg)
        if args.verbose:
            # user requested verbose status dump of the git/svn status commands
            source_tree.verbose_status()
    else:
        # checkout / update the model repositories.
        safe_to_update = check_safe_to_update_repos(tree_status, args.debug)
        if not safe_to_update:
            msg = textwrap.fill(
                'Model contains repositories that are not in a clean '
                'state. Please run with the --status flag and ensure all '
                'repositories are clean before updating.')
            printlog('-' * 70)
            printlog(msg)
            printlog('-' * 70)
        else:
            printlog('Checkout components: ', end='')
            source_tree.checkout(load_all)
            printlog('')

    logging.info('checkout_model completed without exceptions.')
    return 0


if __name__ == '__main__':
    arguments = commandline_arguments()
    try:
        RET_STATUS = _main(arguments)
        sys.exit(RET_STATUS)
    except Exception as error:
        printlog(str(error))
        if arguments.backtrace:
            traceback.print_exc()
        sys.exit(1)
