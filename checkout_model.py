#!/usr/bin/env python

"""
Tool to assemble respositories represented in a model-description file.

If loaded as a module (e.g., in a component's buildcpp), it can be used
to check the validity of existing subdirectories and load missing sources.
"""
from __future__ import print_function

import argparse
import errno
import json
import os
import os.path
import pprint
import re
import subprocess
import sys
import traceback
import xml.etree.ElementTree as ET

if sys.hexversion < 0x02070000:
    print(70 * "*")
    print("ERROR: {0} requires python >= 2.7.x. ".format(sys.argv[0]))
    print("It appears that you are running python {0}".format(
        ".".join(str(x) for x in sys.version_info[0:3])))
    print(70 * "*")
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
pretty_printer = pprint.PrettyPrinter(indent=4)
RE_NAMESPACE = re.compile(r"{[^}]*}")


# ---------------------------------------------------------------------
#
# User input
#
# ---------------------------------------------------------------------
def commandline_arguments():
    """Process the command line arguments
    """
    description = """Tool to manage checking out CESM from revision control based on a
model description file.

By default only the required components of the model are checkout out.
"""
    parser = argparse.ArgumentParser(description=description)

    parser.add_argument('--backtrace', action='store_true',
                        help='show exception backtraces as extra debugging '
                        'output')

    parser.add_argument("--model", nargs='?', default='CESM.xml',
                        help="The model description xml filename. "
                        "Default: %(default)s.")

    parser.add_argument('-r', '--required', action='store_true', default=False,
                        help="NOT IMPLEMENTED! Only checkout the required "
                        "components of the model, e.g. cime. Optional science "
                        "components will be checked out as needed by the "
                        "build system.")

    options = parser.parse_args()
    return options


# ---------------------------------------------------------------------
#
# Utility functions
#
# ---------------------------------------------------------------------
def perr(errstr):
    """
    Error output function
    """
    raise RuntimeError("{0}ERROR: {1}".format(os.linesep, errstr))


def check_output(commands):
    """
    Wrapper around subprocess.check_output to handle common exceptions.
    check_output runs a command with arguments and returns its output.
    On successful completion, check_output returns the command's output.
    """
    try:
        outstr = subprocess.check_output(commands)
    except OSError as error:
        print("Execution of '{0}' failed: {1}".format(
            (' '.join(commands)), error), file=sys.stderr)
    except ValueError as error:
        print("ValueError in '{0}': {1}".format(
            (' '.join(commands)), error), file=sys.stderr)
        outstr = None
    except subprocess.CalledProcessError as error:
        print("CalledProcessError in '{0}': {1}".format(
            (' '.join(commands)), error), file=sys.stderr)
        outstr = None

    return outstr


def scall(commands, log_filename=None):
    """
    Wrapper around subprocess.check_call to handle common exceptions.
    check_call runs a command with arguments and waits for it to complete.
    check_call raises an exception on a nonzero return code.
    scall returns the return code of the command (zero) or -1 on error.
    """
    retcode = -1
    try:
        if log_filename:
            fpath = os.path.join(os.path.abspath('.'), log_filename)
            with open(fpath, 'w') as logfile:
                print(" ".join(commands), file=logfile)
                retcode = subprocess.check_call(commands, stdout=logfile,
                                                stderr=subprocess.STDOUT)
        else:
            retcode = subprocess.check_call(commands)
    except OSError as error:
        print("Execution of '{0}' failed".format(
            (' '.join(commands))), file=sys.stderr)
        print(error, file=sys.stderr)
    except ValueError as error:
        print("ValueError in '{0}'".format(
            (' '.join(commands))), file=sys.stderr)
        print(error, file=sys.stderr)
    except subprocess.CalledProcessError as error:
        print("CalledProcessError in '{0}'".format(
            (' '.join(commands))), file=sys.stderr)
        print(error, file=sys.stderr)

    return retcode


def retcall(commands):
    """
    Wrapper around subprocess.call to handle common exceptions.
    call runs a command with arguments, waits for it to complete, and returns
    the command's return code.
    retcall sends all error output to /dev/null and is used when just the
    return code is desired.
    """
    with open(os.devnull, 'w') as null_file:
        try:
            retcode = subprocess.call(
                commands, stdout=null_file, stderr=subprocess.STDOUT)
        except OSError as error:
            print("Execution of '{0}' failed".format(
                ' '.join(commands)), file=sys.stderr)
            print(error, file=sys.stderr)
        except ValueError as error:
            print("ValueError in '{0}'".format(
                ' '.join(commands)), file=sys.stderr)
            print(error, file=sys.stderr)
        except subprocess.CalledProcessError as error:
            print("CalledProcessError in '{0}'".format(
                ' '.join(commands)), file=sys.stderr)
            print(error, file=sys.stderr)

    return retcode


def quit_on_fail(retcode, caller):
    """
    Check a return code and exit if non-zero.
    """
    if retcode != 0:
        raise RuntimeError("{0} failed with return code {1}".format(
            caller, retcode))


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
    protocol = repo_info['protocol'].lower()
    if 'git' == protocol:
        repo = _GitRepository(component_name, repo_info)
    elif 'svn' == protocol:
        repo = _SvnRepository(component_name, repo_info)
    elif 'externals_only' == protocol:
        repo = None
    else:
        raise RuntimeError("Unknown repo protocol, {0}".format(protocol))
    return repo


def read_model_description_file(root_dir, file_name):
    """
    """
    root_dir = os.path.abspath(root_dir)

    print("Processing model description file '{0}'".format(file_name))
    print("in directory : {0}".format(root_dir))
    file_path = os.path.join(root_dir, file_name)
    if not os.path.exists(file_name):
        msg = ("ERROR: Model description file, '{0}', does not "
               "exist at {1}".format(file_name, file_path))
        raise RuntimeError(msg)

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

    if not model_description:
        with open(file_path, 'r') as filehandle:
            try:
                json_data = json.loads(filehandle.read())
                model_description = json_data
                model_format = 'json'
            except ValueError as e:
                # not a json file
                print(e)

    if not model_description:
        try:
            config = config_parser()
            config.read(file_path)
            # insert cfg2dict here
            model_description = config
            model_format = 'cfg'
        except ConfigParser.MissingSectionHeaderError:
            # not a cfg file
            pass

    if not model_description:
        msg = "Unknown file format!"
        raise RuntimeError(msg)

    return model_format, model_description


class ModelDescription(dict):
    """
    """
    # keywords defining the interface into the model description data
    _EXTERNALS = u'externals'
    _BRANCH = u'branch'
    _REPO = u'repo'
    _REQUIRED = u'required'
    _TAG = u'tag'
    _PATH = u'path'
    _PROTOCOL = u'protocol'
    _URL = u'url'
    _NAME = u'name'

    # v1 xml keywords
    _V1_TREE_PATH = u'TREE_PATH'
    _V1_ROOT = u'ROOT'
    _V1_TAG = u'TAG'
    _V1_BRANCH = u'BRANCH'
    _V1_REQ_SOURCE = u'REQ_SOURCE'

    _source_schema = {_REQUIRED: True,
                      _PATH: u'string',
                      _EXTERNALS: u'string',
                      _REPO: {_PROTOCOL: u'string',
                              _URL: u'string',
                              _TAG: u'string',
                              _BRANCH: u'string',
                              }
                      }

    def __init__(self, model_format, model_data):
        """Convert the xml into a standardized dict that can be used to
        construct the source objects

        """
        if 'xml' == model_format:
            self._parse_xml(model_data)
        elif 'cfg' == model_format:
            self._parse_cfg(model_data)
        elif 'json' == model_format:
            self._parse_json(model_data)
        else:
            msg = "Unknown model data format '{0}'".format(model_format)
            raise RuntimeError(msg)

    def _validate(self):
        """
        """
        def validate_data_struct(reference, data):
            is_valid = False
            in_ref = True
            valid = True
            if isinstance(reference, dict) and isinstance(data, dict):
                for k in data:
                    in_ref = in_ref and (k in reference)
                    print(in_ref)
                    valid = valid and (
                        validate_data_struct(reference[k], data[k]))
                is_valid = in_ref and valid
            else:
                is_valid = isinstance(data, type(reference))
            return is_valid

        for m in self:
            valid = validate_data_struct(self._source_schema, self[m])
            if not valid:
                pretty_printer.pprint(self._source_schema)
                pretty_printer.pprint(self[m])
                raise RuntimeError(
                    "ERROR: source for '{0}' did not validate".format(m))

    def _parse_json(self, json_data):
        """
        """
        self.update(json_data)
        self._validate()

    def _parse_xml(self, xml_root):
        """
        """
        xml_root = self._get_xml_config_sourcetree(xml_root)
        version = self._get_xml_schema_version(xml_root)
        major_version = version[0]
        if '1' == major_version:
            self._parse_xml_v1(xml_root)
        elif '2' == major_version:
            self._parse_xml_v2(xml_root)
        else:
            msg = ("ERROR: unknown xml schema version '{0}'".format(
                major_version))
            raise RuntimeError(msg)
        self._validate()

    def _parse_xml_v1(self, xml_root):
        """
        """
        for src in xml_root.findall('./source'):
            source = {}
            source[self._EXTERNALS] = ''
            source[self._REQUIRED] = False
            source[self._PATH] = src.find(self._V1_TREE_PATH).text
            repo = {}
            xml_repo = src.find(self._REPO)
            repo[self._PROTOCOL] = xml_repo.get(self._PROTOCOL)
            repo[self._URL] = xml_repo.find(self._V1_ROOT).text
            repo[self._TAG] = xml_repo.find(self._V1_TAG)
            if repo[self._TAG] is not None:
                repo[self._TAG] = repo[self._TAG].text
            else:
                repo[self._TAG] = ''
            repo[self._BRANCH] = xml_repo.find(self._V1_BRANCH)
            if repo[self._BRANCH] is not None:
                repo[self._BRANCH] = repo[self._BRANCH].text
            else:
                repo[self._BRANCH] = ''
            source[self._REPO] = repo
            name = src.get(self._NAME).lower()
            self[name] = source
            required = xml_root.find(self._REQUIRED)
            if required is not None:
                for src in required.findall(self._V1_REQ_SOURCE):
                    name = src.text.lower()
                    self[name][self._REQUIRED] = True

    def _parse_xml_v2(self, xml_root):
        """
        """
        for src in xml_root.findall('./source'):
            source = {}
            source[self._PATH] = src.find(self._PATH).text
            repo = {}
            xml_repo = src.find(self._REPO)
            repo[self._PROTOCOL] = xml_repo.get(self._PROTOCOL)
            repo[self._URL] = xml_repo.find(self._URL).text
            repo[self._TAG] = xml_repo.find(self._TAG)
            if repo[self._TAG] is not None:
                repo[self._TAG] = repo[self._TAG].text
            else:
                repo[self._TAG] = ''
            repo[self._BRANCH] = xml_repo.find(self._BRANCH)
            if repo[self._BRANCH] is not None:
                repo[self._BRANCH] = repo[self._BRANCH].text
            else:
                repo[self._BRANCH] = ''
            source[self._REPO] = repo
            source[self._EXTERNALS] = src.find(self._EXTERNALS)
            if source[self._EXTERNALS] is not None:
                source[self._EXTERNALS] = source[self._EXTERNALS].text
            else:
                source[self._EXTERNALS] = ''
            required = src.get(self._REQUIRED).lower()
            if 'false' == required:
                source[self._REQUIRED] = False
            elif 'true' == required:
                source[self._REQUIRED] = True
            else:
                msg = "ERROR: unknown value for attribute 'required' = {0} ".format(
                    required)
                raise RuntimeError(msg)
            name = src.get(self._NAME).lower()
            self[name] = source

    @staticmethod
    def _get_xml_config_sourcetree(xml_root):
        """
        """
        st_str = 'config_sourcetree'
        xml_st = None
        if xml_root.tag == st_str:
            xml_st = xml_root
        else:
            xml_st = xml_root.find('./config_sourcetree')
        if xml_st is None:
            msg = "ERROR: xml does not contain a 'config_sourcetree' element."
            raise RuntimeError(msg)
        return xml_st

    @staticmethod
    def _get_xml_schema_version(xml_st):
        """
        """
        version = xml_st.get('version', None)
        if not version:
            msg = ("ERROR: xml config_sourcetree element must contain "
                   "a 'version' attribute.")
            raise RuntimeError(msg)
        return version.split('.')


# ---------------------------------------------------------------------
#
# Worker classes
#
# ---------------------------------------------------------------------
class _Repository(object):
    """
    Class to represent and operate on a repository description.
    """

    def __init__(self, component_name, repo):
        """
        Parse repo (a <repo> XML element).
        """
        self._name = component_name
        self._protocol = repo['protocol']
        self._tag = repo['tag']
        self._branch = repo['branch']
        self._url = repo['url']

        if self._url is '':
            perr("repo must have a URL")

        if self._tag is '' and self._branch is '':
            perr("repo must have either a branch or a tag element")

        if self._tag is not '' and self._branch is not '':
            perr("repo cannot have both a tag and a tag element")

    def load(self, repo_dir):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        if repo_dir or self._protocol:
            pass
        raise RuntimeError("DEV_ERROR: this method must be implemented in all "
                           "child classes!")


class _SvnRepository(_Repository):
    """
    Class to represent and operate on a repository description.
    """
    RE_URLLINE = re.compile(r"^URL:")

    def __init__(self, component_name, repo):
        """
        Parse repo (a <repo> XML element).
        """
        _Repository.__init__(self, component_name, repo)
        if len(self._branch) > 0:
            self._url = os.path.join(self._url, self._branch)
        elif len(self._tag) > 0:
            self._url = os.path.join(self._url, self._tag)
        else:
            raise RuntimeError(
                "DEV_ERROR in svn repository. Shouldn't be here!")

    def load(self, repo_dir):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        self._svn_checkout(repo_dir)

        return True

    def _svn_checkout(self, checkout_dir):
        """
        Checkout a subversion repository (repo_url) to checkout_dir.
        """
        caller = "svn_checkout {0} {1}".format(checkout_dir, self._url)
        cmd = ["svn", "checkout", self._url, checkout_dir]
        print("    {0}\n".format(' '.join(cmd)))
        log_filename = "svn-{0}.log".format(self._name)
        retcode = scall(cmd, log_filename)
        quit_on_fail(retcode, caller)

    def _svn_update(self, updir):
        """
        Refresh a subversion sandbox (updir)
        """
        caller = "svn_update {0}".format(updir)
        mycurrdir = os.path.abspath(".")
        os.chdir(updir)
        retcode = scall(["svn update"])
        quit_on_fail(retcode, caller)
        os.chdir(mycurrdir)

    def _svn_check_dir(self, chkdir, ver):
        """
        Check to see if directory (chkdir) exists and is the correct
        version (ver).
        Return True (correct), False (incorrect) or None (chkdir not found)

        """
        if os.path.exists(chkdir):
            svnout = check_output(["svn", "info", chkdir])
            if svnout is not None:
                url = None
                for line in svnout.splitlines():
                    if _SvnRepository.RE_URLLINE.match(line):
                        url = line.split(': ')[1]
                        break
                status = (url == ver)
            else:
                status = None
        else:
            status = None

        return status


class _GitRepository(_Repository):
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
        _Repository.__init__(self, component_name, repo)

    def load(self, repo_dir):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        self._git_checkout(repo_dir)

        return True

    def _git_ref_type(self, ref):
        """
        Determine if 'ref' is a local branch, a remote branch, a tag, or a
        commit.
        Should probably use this command instead:
        git show-ref --verify --quiet refs/heads/<branch-name>
        """
        ref_type = self.GIT_REF_UNKNOWN
        # First check for local branch
        gitout = check_output(["git", "branch"])
        if gitout is not None:
            branches = [x.lstrip('* ') for x in gitout.splitlines()]
            for branch in branches:
                if branch == ref:
                    ref_type = self.GIT_REF_LOCAL_BRANCH
                    break

        # Next, check for remote branch
        if ref_type == self.GIT_REF_UNKNOWN:
            gitout = check_output(["git", "branch", "-r"])
            if gitout is not None:
                for branch in gitout.splitlines():
                    match = _GitRepository.RE_REMOTEBRANCH.match(branch)
                    if (match is not None) and (match.group(1) == ref):
                        ref_type = self.GIT_REF_REMOTE_BRANCH
                        break

        # Next, check for a tag
        if ref_type == self.GIT_REF_UNKNOWN:
            gitout = check_output(["git", "tag"])
            if gitout is not None:
                for tag in gitout.splitlines():
                    if tag == ref:
                        ref_type = self.GIT_REF_TAG
                        break

        # Finally, see if it just looks like a commit hash
        if ((ref_type == self.GIT_REF_UNKNOWN) and
                _GitRepository.RE_GITHASH.match(ref)):
            ref_type = self.GIT_REF_SHA1

        # Return what we've come up with
        return ref_type

    def _git_current_branch(self):
        """
        Return the (current branch, sha1 hash) of working copy in wdir
        """
        branch = check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"])
        git_hash = check_output(["git", "rev-parse", "HEAD"])
        if branch is not None:
            branch = branch.rstrip()

        if git_hash is not None:
            git_hash = git_hash.rstrip()

        return (branch, git_hash)

    def _git_check_dir(self, chkdir, ref):
        """
        Check to see if directory (chkdir) exists and is the correct
        treeish (ref)
        Return True (correct), False (incorrect) or None (chkdir not found)
        """
        refchk = None
        mycurrdir = os.path.abspath(".")
        if os.path.exists(chkdir):
            if os.path.exists(os.path.join(chkdir, ".git")):
                os.chdir(chkdir)
                head = check_output(["git", "rev-parse", "HEAD"])
                if ref is not None:
                    refchk = check_output(["git", "rev-parse", ref])

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

    def _git_working_dir_clean(self, wdir):
        """
        Return True if wdir is clean or False if there are modifications
        """
        mycurrdir = os.path.abspath(".")
        os.chdir(wdir)
        retcode = retcall(["git", "diff", "--quiet", "--exit-code"])
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
                ["git", "config", "branch.{0}.remote".format(curr_branch)])
        else:
            remote = None

        os.chdir(mycurrdir)
        return remote

    # Need to decide how to do this. Just doing pull for now
    def _git_update(self, repo_dir):
        """
        Do an update and a FF merge if possible
        """
        caller = "_git_update {0}".format(repo_dir)
        mycurrdir = os.path.abspath(".")
        os.chdir(repo_dir)
        remote = self._git_remote(repo_dir)
        if remote is not None:
            retcode = scall(["git", "remote", "update", "--prune", remote])
            quit_on_fail(retcode, caller)

        retcode = scall(["git", "merge", "--ff-only", "@{u}"])
        os.chdir(mycurrdir)
        quit_on_fail(retcode, caller)

    def _git_checkout(self, checkout_dir):
        """
        Checkout 'branch' or 'tag' from 'repo_url'
        """
        caller = "_git_checkout {0} {1}".format(checkout_dir, self._url)
        retcode = 0
        mycurrdir = os.path.abspath(".")
        if os.path.exists(checkout_dir):
            # We can't do a clone. See what we have here
            if self._git_check_dir(checkout_dir, None):
                os.chdir(checkout_dir)
                # We have a git repo, is it from the correct URL?
                cmd = ["git", "config", "remote.origin.url"]
                check_url = check_output(cmd)
                if check_url is not None:
                    check_url = check_url.rstrip()

                if check_url != self._url:
                    perr("Invalid repository in {0}, url = {1}, "
                         "should be {2}".format(checkout_dir, check_url,
                                                self._url))
                # FIXME(bja, 2017-09) we are updating an existing
                # clone. Need to do a fetch here to ensure that the
                # branch or tag checkout will work

        else:
            cmd = ["git", "clone", self._url, checkout_dir]
            print("    {0}\n".format(' '.join(cmd)))
            log_filename = "git-{0}-clone.log".format(self._name)
            retcode = scall(cmd, log_filename)
            quit_on_fail(retcode, caller)
            os.chdir(checkout_dir)

        cmd = []
        if len(self._branch) > 0:
            (curr_branch, _) = self._git_current_branch()
            ref_type = self._git_ref_type(self._branch)
            if ref_type == self.GIT_REF_REMOTE_BRANCH:
                cmd = ["git", "checkout", "--track", "origin/" + self._branch]
            elif ref_type == self.GIT_REF_LOCAL_BRANCH:
                if curr_branch != self._branch:
                    if not self._git_working_dir_clean(checkout_dir):
                        perr("Working directory ({0}) not clean, "
                             "aborting".format(checkout_dir))
                    else:
                        cmd = ["git", "checkout", self._branch]

            else:
                perr("Unable to check out branch, {0}".format(self._branch))

        elif len(self._tag) > 0:
            # For now, do a hail mary and hope tag can be checked out
            cmd = ["git", "checkout", self._tag]
        else:
            raise RuntimeError("DEV_ERROR: in git repo. Shouldn't be here!")

        if cmd:
            print("    {0}\n".format(' '.join(cmd)))
            log_filename = "git-{0}-checkout.log".format(self._name)
            retcode = scall(cmd, log_filename)
            quit_on_fail(retcode, caller)

        os.chdir(mycurrdir)


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
        self._externals = ''
        self._externals_sourcetree = None
        # Parse the sub-elements
        self._path = source['path']
        self._repo_dir = os.path.basename(self._path)
        self._externals = source['externals']
        repo = create_repository(name, source['repo'])
        if repo is None:
            self._loaded = True
        else:
            self._repos.append(repo)

    def get_name(self):
        """
        Return the source object's name
        """
        return self._name

    def load(self, tree_root, load_all):
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
        mycurrdir = os.path.abspath(".")
        pdir = os.path.join(tree_root, os.path.dirname(self._path))
        if not os.path.exists(pdir):
            try:
                os.makedirs(pdir)
            except OSError as error:
                if error.errno != errno.EEXIST:
                    raise

        os.chdir(pdir)

        repo_loaded = self._loaded
        if not repo_loaded:
            for repo in self._repos:
                repo_loaded = repo.load(self._repo_dir)
                if repo_loaded:
                    break

        self._loaded = repo_loaded

        if len(self._externals) > 0:
            comp_dir = os.path.join(tree_root, self._path)
            os.chdir(comp_dir)
            if not os.path.exists(self._externals):
                raise RuntimeError("External model description file '{0}' "
                                   "does not exist!".format(self._externals))
            ext_root = comp_dir
            model_format, model_data = read_model_description_file(
                ext_root, self._externals)
            externals = ModelDescription(model_format, model_data)
            self._externals_sourcetree = SourceTree(ext_root, externals)
            self._externals_sourcetree.load(load_all)

        os.chdir(mycurrdir)
        return repo_loaded


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
            if model[comp]['required']:
                self._required_compnames.append(comp)

    def load(self, load_all, load_comp=None):
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

        if load_comps is not None:
            print("Loading these components: {0}".format(load_comps))

        for comp in load_comps:
            self._all_components[comp].load(self._root_dir, load_all)


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
    load_all = True
    if args.required:
        load_all = False
        msg = 'The required only option to checkout has not been implemented'
        raise NotImplementedError(msg)

    root_dir = os.path.abspath('.')
    model_format, model_data = read_model_description_file(
        root_dir, args.model)
    model = ModelDescription(model_format, model_data)
    if False:
        pretty_printer.pprint(model)
    source_tree = SourceTree(root_dir, model)
    source_tree.load(load_all)
    return 0


if __name__ == "__main__":
    arguments = commandline_arguments()
    try:
        return_status = _main(arguments)
        sys.exit(return_status)
    except Exception as error:
        print(str(error))
        if arguments.backtrace:
            traceback.print_exc()
        sys.exit(1)
