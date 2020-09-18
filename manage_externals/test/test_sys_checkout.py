#!/usr/bin/env python

"""Unit test driver for checkout_externals

Note: this script assume the path to the manic and
checkout_externals module is already in the python path. This is
usually handled by the makefile. If you call it directly, you may need
to adjust your path.

NOTE(bja, 2017-11) If a test fails, we want to keep the repo for that
test. But the tests will keep running, so we need a unique name. Also,
tearDown is always called after each test. I haven't figured out how
to determine if an assertion failed and whether it is safe to clean up
the test repos.

So the solution is:

* assign a unique id to each test repo.

* never cleanup during the run.

* Erase any existing repos at the begining of the module in
setUpModule.

"""

# NOTE(bja, 2017-11) pylint complains that the module is too big, but
# I'm still working on how to break up the tests and still have the
# temporary directory be preserved....
# pylint: disable=too-many-lines


from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import logging
import os
import os.path
import shutil
import sys
import unittest

from manic.externals_description import ExternalsDescription
from manic.externals_description import DESCRIPTION_SECTION, VERSION_ITEM
from manic.externals_description import git_submodule_status
from manic.externals_status import ExternalStatus
from manic.repository_git import GitRepository
from manic.utils import printlog, execute_subprocess
from manic.global_constants import LOCAL_PATH_INDICATOR, VERBOSITY_DEFAULT
from manic.global_constants import LOG_FILE_NAME
from manic import checkout

# ConfigParser was renamed in python2 to configparser. In python2,
# ConfigParser returns byte strings, str, instead of unicode. We need
# unicode to be compatible with xml and json parser and python3.
try:
    # python2
    from ConfigParser import SafeConfigParser as config_parser
except ImportError:
    # python3
    from configparser import ConfigParser as config_parser

# ---------------------------------------------------------------------
#
# Global constants
#
# ---------------------------------------------------------------------

# environment variable names
MANIC_TEST_BARE_REPO_ROOT = 'MANIC_TEST_BARE_REPO_ROOT'
MANIC_TEST_TMP_REPO_ROOT = 'MANIC_TEST_TMP_REPO_ROOT'

# directory names
TMP_REPO_DIR_NAME = 'tmp'
BARE_REPO_ROOT_NAME = 'repos'
CONTAINER_REPO_NAME = 'container.git'
MIXED_REPO_NAME = 'mixed-cont-ext.git'
SIMPLE_REPO_NAME = 'simple-ext.git'
SIMPLE_FORK_NAME = 'simple-ext-fork.git'
SIMPLE_LOCAL_ONLY_NAME = '.'
ERROR_REPO_NAME = 'error'
EXTERNALS_NAME = 'externals'
SUB_EXTERNALS_PATH = 'src'
CFG_NAME = 'externals.cfg'
CFG_SUB_NAME = 'sub-externals.cfg'
README_NAME = 'readme.txt'
REMOTE_BRANCH_FEATURE2 = 'feature2'
NESTED_NAME = ['./fred', './fred/wilma', './fred/wilma/barney']


SVN_TEST_REPO = 'https://github.com/escomp/cesm'

# Disable too-many-public-methods error
# pylint: disable=R0904

def setUpModule():  # pylint: disable=C0103
    """Setup for all tests in this module. It is called once per module!
    """
    logging.basicConfig(filename=LOG_FILE_NAME,
                        format='%(levelname)s : %(asctime)s : %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S',
                        level=logging.DEBUG)
    repo_root = os.path.join(os.getcwd(), TMP_REPO_DIR_NAME)
    repo_root = os.path.abspath(repo_root)
    # delete if it exists from previous runs
    try:
        shutil.rmtree(repo_root)
    except BaseException:
        pass
    # create clean dir for this run
    os.mkdir(repo_root)
    # set into the environment so var will be expanded in externals
    # filess when executables are run
    os.environ[MANIC_TEST_TMP_REPO_ROOT] = repo_root


class GenerateExternalsDescriptionCfgV1(object):
    """Class to provide building blocks to create
    ExternalsDescriptionCfgV1 files.

    Includes predefined files used in tests.

    """

    def __init__(self):
        self._schema_version = '1.1.0'
        self._config = None

    def container_full(self, dest_dir):
        """Create the full container config file with simple and mixed use
        externals

        """
        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_tag',
                            tag='tag1')

        self.create_section(SIMPLE_REPO_NAME, 'simp_branch',
                            branch=REMOTE_BRANCH_FEATURE2)

        self.create_section(SIMPLE_REPO_NAME, 'simp_opt',
                            tag='tag1', required=False)

        self.create_section(MIXED_REPO_NAME, 'mixed_req',
                            branch='master', externals=CFG_SUB_NAME)

        self.write_config(dest_dir)

    def container_simple_required(self, dest_dir):
        """Create a container externals file with only simple externals.

        """
        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_tag',
                            tag='tag1')

        self.create_section(SIMPLE_REPO_NAME, 'simp_branch',
                            branch=REMOTE_BRANCH_FEATURE2)

        self.create_section(SIMPLE_REPO_NAME, 'simp_hash',
                            ref_hash='60b1cc1a38d63')

        self.write_config(dest_dir)

    def container_nested_required(self, dest_dir, order):
        """Create a container externals file with only simple externals.

        """
        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_tag', nested=True,
                            tag='tag1', path=NESTED_NAME[order[0]])

        self.create_section(SIMPLE_REPO_NAME, 'simp_branch', nested=True,
                            branch=REMOTE_BRANCH_FEATURE2, path=NESTED_NAME[order[1]])

        self.create_section(SIMPLE_REPO_NAME, 'simp_hash', nested=True,
                            ref_hash='60b1cc1a38d63', path=NESTED_NAME[order[2]])

        self.write_config(dest_dir)


    def container_simple_optional(self, dest_dir):
        """Create a container externals file with optional simple externals

        """
        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_req',
                            tag='tag1')

        self.create_section(SIMPLE_REPO_NAME, 'simp_opt',
                            tag='tag1', required=False)

        self.write_config(dest_dir)

    def container_simple_svn(self, dest_dir):
        """Create a container externals file with only simple externals.

        """
        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_tag', tag='tag1')

        self.create_svn_external('svn_branch', branch='trunk')
        self.create_svn_external('svn_tag', tag='tags/cesm2.0.beta07')

        self.write_config(dest_dir)

    def container_sparse(self, dest_dir):
        """Create a container with a full external and a sparse external

        """
        # Create a file for a sparse pattern match
        sparse_filename = 'sparse_checkout'
        with open(os.path.join(dest_dir, sparse_filename), 'w') as sfile:
            sfile.write('readme.txt')

        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_tag',
                            tag='tag2')

        sparse_relpath = '../../{}'.format(sparse_filename)
        self.create_section(SIMPLE_REPO_NAME, 'simp_sparse',
                            tag='tag2', sparse=sparse_relpath)

        self.write_config(dest_dir)

    def mixed_simple_base(self, dest_dir):
        """Create a mixed-use base externals file with only simple externals.

        """
        self.create_config()
        self.create_section_ext_only('mixed_base')
        self.create_section(SIMPLE_REPO_NAME, 'simp_tag',
                            tag='tag1')

        self.create_section(SIMPLE_REPO_NAME, 'simp_branch',
                            branch=REMOTE_BRANCH_FEATURE2)

        self.create_section(SIMPLE_REPO_NAME, 'simp_hash',
                            ref_hash='60b1cc1a38d63')

        self.write_config(dest_dir)

    def mixed_simple_sub(self, dest_dir):
        """Create a mixed-use sub externals file with only simple externals.

        """
        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_tag',
                            tag='tag1', path=SUB_EXTERNALS_PATH)

        self.create_section(SIMPLE_REPO_NAME, 'simp_branch',
                            branch=REMOTE_BRANCH_FEATURE2,
                            path=SUB_EXTERNALS_PATH)

        self.write_config(dest_dir, filename=CFG_SUB_NAME)

    def write_config(self, dest_dir, filename=CFG_NAME):
        """Write the configuration file to disk

        """
        dest_path = os.path.join(dest_dir, filename)
        with open(dest_path, 'w') as configfile:
            self._config.write(configfile)

    def create_config(self):
        """Create an config object and add the required metadata section

        """
        self._config = config_parser()
        self.create_metadata()

    def create_metadata(self):
        """Create the metadata section of the config file
        """
        self._config.add_section(DESCRIPTION_SECTION)

        self._config.set(DESCRIPTION_SECTION, VERSION_ITEM,
                         self._schema_version)

    def create_section(self, repo_type, name, tag='', branch='',
                       ref_hash='', required=True, path=EXTERNALS_NAME,
                       externals='', repo_path=None, from_submodule=False,
                       sparse='', nested=False):
        # pylint: disable=too-many-branches
        """Create a config section with autofilling some items and handling
        optional items.

        """
        # pylint: disable=R0913
        self._config.add_section(name)
        if not from_submodule:
            if nested:
                self._config.set(name, ExternalsDescription.PATH, path)
            else:
                self._config.set(name, ExternalsDescription.PATH,
                                 os.path.join(path, name))

        self._config.set(name, ExternalsDescription.PROTOCOL,
                         ExternalsDescription.PROTOCOL_GIT)

        # from_submodules is incompatible with some other options, turn them off
        if (from_submodule and
                ((repo_path is not None) or tag or ref_hash or branch)):
            printlog('create_section: "from_submodule" is incompatible with '
                     '"repo_url", "tag", "hash", and "branch" options;\n'
                     'Ignoring those options for {}'.format(name))
            repo_url = None
            tag = ''
            ref_hash = ''
            branch = ''

        if repo_path is not None:
            repo_url = repo_path
        else:
            repo_url = os.path.join('${MANIC_TEST_BARE_REPO_ROOT}', repo_type)

        if not from_submodule:
            self._config.set(name, ExternalsDescription.REPO_URL, repo_url)

        self._config.set(name, ExternalsDescription.REQUIRED, str(required))

        if tag:
            self._config.set(name, ExternalsDescription.TAG, tag)

        if branch:
            self._config.set(name, ExternalsDescription.BRANCH, branch)

        if ref_hash:
            self._config.set(name, ExternalsDescription.HASH, ref_hash)

        if externals:
            self._config.set(name, ExternalsDescription.EXTERNALS, externals)

        if sparse:
            self._config.set(name, ExternalsDescription.SPARSE, sparse)

        if from_submodule:
            self._config.set(name, ExternalsDescription.SUBMODULE, "True")

    def create_section_ext_only(self, name,
                                required=True, externals=CFG_SUB_NAME):
        """Create a config section with autofilling some items and handling
        optional items.

        """
        # pylint: disable=R0913
        self._config.add_section(name)
        self._config.set(name, ExternalsDescription.PATH, LOCAL_PATH_INDICATOR)

        self._config.set(name, ExternalsDescription.PROTOCOL,
                         ExternalsDescription.PROTOCOL_EXTERNALS_ONLY)

        self._config.set(name, ExternalsDescription.REPO_URL,
                         LOCAL_PATH_INDICATOR)

        self._config.set(name, ExternalsDescription.REQUIRED, str(required))

        if externals:
            self._config.set(name, ExternalsDescription.EXTERNALS, externals)

    def create_svn_external(self, name, tag='', branch=''):
        """Create a config section for an svn repository.

        """
        self._config.add_section(name)
        self._config.set(name, ExternalsDescription.PATH,
                         os.path.join(EXTERNALS_NAME, name))

        self._config.set(name, ExternalsDescription.PROTOCOL,
                         ExternalsDescription.PROTOCOL_SVN)

        self._config.set(name, ExternalsDescription.REPO_URL, SVN_TEST_REPO)

        self._config.set(name, ExternalsDescription.REQUIRED, str(True))

        if tag:
            self._config.set(name, ExternalsDescription.TAG, tag)

        if branch:
            self._config.set(name, ExternalsDescription.BRANCH, branch)

    @staticmethod
    def create_branch(dest_dir, repo_name, branch, with_commit=False):
        """Update a repository branch, and potentially the remote.
        """
        # pylint: disable=R0913
        cwd = os.getcwd()
        repo_root = os.path.join(dest_dir, EXTERNALS_NAME)
        repo_root = os.path.join(repo_root, repo_name)
        os.chdir(repo_root)
        cmd = ['git', 'checkout', '-b', branch, ]
        execute_subprocess(cmd)
        if with_commit:
            msg = 'start work on {0}'.format(branch)
            with open(README_NAME, 'a') as handle:
                handle.write(msg)
            cmd = ['git', 'add', README_NAME, ]
            execute_subprocess(cmd)
            cmd = ['git', 'commit', '-m', msg, ]
            execute_subprocess(cmd)
        os.chdir(cwd)

    @staticmethod
    def create_commit(dest_dir, repo_name, local_tracking_branch=None):
        """Make a commit on whatever is currently checked out.

        This is used to test sync state changes from local commits on
        detached heads and tracking branches.

        """
        cwd = os.getcwd()
        repo_root = os.path.join(dest_dir, EXTERNALS_NAME)
        repo_root = os.path.join(repo_root, repo_name)
        os.chdir(repo_root)
        if local_tracking_branch:
            cmd = ['git', 'checkout', '-b', local_tracking_branch, ]
            execute_subprocess(cmd)

        msg = 'work on great new feature!'
        with open(README_NAME, 'a') as handle:
            handle.write(msg)
        cmd = ['git', 'add', README_NAME, ]
        execute_subprocess(cmd)
        cmd = ['git', 'commit', '-m', msg, ]
        execute_subprocess(cmd)
        os.chdir(cwd)

    def update_branch(self, dest_dir, name, branch, repo_type=None,
                      filename=CFG_NAME):
        """Update a repository branch, and potentially the remote.
        """
        # pylint: disable=R0913
        self._config.set(name, ExternalsDescription.BRANCH, branch)

        if repo_type:
            if repo_type == SIMPLE_LOCAL_ONLY_NAME:
                repo_url = SIMPLE_LOCAL_ONLY_NAME
            else:
                repo_url = os.path.join('${MANIC_TEST_BARE_REPO_ROOT}',
                                        repo_type)
            self._config.set(name, ExternalsDescription.REPO_URL, repo_url)

        try:
            # remove the tag if it existed
            self._config.remove_option(name, ExternalsDescription.TAG)
        except BaseException:
            pass

        self.write_config(dest_dir, filename)

    def update_svn_branch(self, dest_dir, name, branch, filename=CFG_NAME):
        """Update a repository branch, and potentially the remote.
        """
        # pylint: disable=R0913
        self._config.set(name, ExternalsDescription.BRANCH, branch)

        try:
            # remove the tag if it existed
            self._config.remove_option(name, ExternalsDescription.TAG)
        except BaseException:
            pass

        self.write_config(dest_dir, filename)

    def update_tag(self, dest_dir, name, tag, repo_type=None,
                   filename=CFG_NAME, remove_branch=True):
        """Update a repository tag, and potentially the remote

        NOTE(bja, 2017-11) remove_branch=False should result in an
        overspecified external with both a branch and tag. This is
        used for error condition testing.

        """
        # pylint: disable=R0913
        self._config.set(name, ExternalsDescription.TAG, tag)

        if repo_type:
            repo_url = os.path.join('${MANIC_TEST_BARE_REPO_ROOT}', repo_type)
            self._config.set(name, ExternalsDescription.REPO_URL, repo_url)

        try:
            # remove the branch if it existed
            if remove_branch:
                self._config.remove_option(name, ExternalsDescription.BRANCH)
        except BaseException:
            pass

        self.write_config(dest_dir, filename)

    def update_underspecify_branch_tag(self, dest_dir, name,
                                       filename=CFG_NAME):
        """Update a repository protocol, and potentially the remote
        """
        # pylint: disable=R0913
        try:
            # remove the branch if it existed
            self._config.remove_option(name, ExternalsDescription.BRANCH)
        except BaseException:
            pass

        try:
            # remove the tag if it existed
            self._config.remove_option(name, ExternalsDescription.TAG)
        except BaseException:
            pass

        self.write_config(dest_dir, filename)

    def update_underspecify_remove_url(self, dest_dir, name,
                                       filename=CFG_NAME):
        """Update a repository protocol, and potentially the remote
        """
        # pylint: disable=R0913
        try:
            # remove the repo url if it existed
            self._config.remove_option(name, ExternalsDescription.REPO_URL)
        except BaseException:
            pass

        self.write_config(dest_dir, filename)

    def update_protocol(self, dest_dir, name, protocol, repo_type=None,
                        filename=CFG_NAME):
        """Update a repository protocol, and potentially the remote
        """
        # pylint: disable=R0913
        self._config.set(name, ExternalsDescription.PROTOCOL, protocol)

        if repo_type:
            repo_url = os.path.join('${MANIC_TEST_BARE_REPO_ROOT}', repo_type)
            self._config.set(name, ExternalsDescription.REPO_URL, repo_url)

        self.write_config(dest_dir, filename)


class BaseTestSysCheckout(unittest.TestCase):
    """Base class of reusable systems level test setup for
    checkout_externals

    """
    # NOTE(bja, 2017-11) pylint complains about long method names, but
    # it is hard to differentiate tests without making them more
    # cryptic.
    # pylint: disable=invalid-name

    status_args = ['--status']
    checkout_args = []
    optional_args = ['--optional']
    verbose_args = ['--status', '--verbose']

    def setUp(self):
        """Setup for all individual checkout_externals tests
        """
        # directory we want to return to after the test system and
        # checkout_externals are done cd'ing all over the place.
        self._return_dir = os.getcwd()

        self._test_id = self.id().split('.')[-1]

        # find root
        if os.path.exists(os.path.join(os.getcwd(), 'checkout_externals')):
            root_dir = os.path.abspath(os.getcwd())
        else:
            # maybe we are in a subdir, search up
            root_dir = os.path.abspath(os.path.join(os.getcwd(), os.pardir))
            while os.path.basename(root_dir):
                if os.path.exists(os.path.join(root_dir, 'checkout_externals')):
                    break
                root_dir = os.path.dirname(root_dir)

        if not os.path.exists(os.path.join(root_dir, 'checkout_externals')):
            raise RuntimeError('Cannot find checkout_externals')

        # path to the executable
        self._checkout = os.path.join(root_dir, 'checkout_externals')

        # directory where we have test repositories
        test_dir = os.path.join(root_dir, 'test')
        self._bare_root = os.path.join(test_dir, BARE_REPO_ROOT_NAME)
        self._bare_root = os.path.abspath(self._bare_root)

        # set into the environment so var will be expanded in externals files
        os.environ[MANIC_TEST_BARE_REPO_ROOT] = self._bare_root

        # set the input file generator
        self._generator = GenerateExternalsDescriptionCfgV1()
        # set the input file generator for secondary externals
        self._sub_generator = GenerateExternalsDescriptionCfgV1()

    def tearDown(self):
        """Tear down for individual tests
        """
        # remove the env var we added in setup
        del os.environ[MANIC_TEST_BARE_REPO_ROOT]

        # return to our common starting point
        os.chdir(self._return_dir)

    def setup_test_repo(self, parent_repo_name, dest_dir_in=None):
        """Setup the paths and clone the base test repo

        """
        # unique repo for this test
        test_dir_name = self._test_id
        print("Test repository name: {0}".format(test_dir_name))

        parent_repo_dir = os.path.join(self._bare_root, parent_repo_name)
        if dest_dir_in is None:
            dest_dir = os.path.join(os.environ[MANIC_TEST_TMP_REPO_ROOT],
                                    test_dir_name)
        else:
            dest_dir = dest_dir_in

        # pylint: disable=W0212
        GitRepository._git_clone(parent_repo_dir, dest_dir, VERBOSITY_DEFAULT)
        return dest_dir

    @staticmethod
    def _add_file_to_repo(under_test_dir, filename, tracked):
        """Add a file to the repository so we can put it into a dirty state

        """
        cwd = os.getcwd()
        os.chdir(under_test_dir)
        with open(filename, 'w') as tmp:
            tmp.write('Hello, world!')

        if tracked:
            # NOTE(bja, 2018-01) brittle hack to obtain repo dir and
            # file name
            path_data = filename.split('/')
            repo_dir = os.path.join(path_data[0], path_data[1])
            os.chdir(repo_dir)
            tracked_file = path_data[2]
            cmd = ['git', 'add', tracked_file]
            execute_subprocess(cmd)

        os.chdir(cwd)

    @staticmethod
    def execute_cmd_in_dir(under_test_dir, args):
        """Extecute the checkout command in the appropriate repo dir with the
        specified additional args

        Note that we are calling the command line processing and main
        routines and not using a subprocess call so that we get code
        coverage results!

        """
        cwd = os.getcwd()
        checkout_path = os.path.abspath('{0}/../../checkout_externals')
        os.chdir(under_test_dir)
        cmdline = ['--externals', CFG_NAME, ]
        cmdline += args
        repo_root = 'MANIC_TEST_BARE_REPO_ROOT={root}'.format(
            root=os.environ[MANIC_TEST_BARE_REPO_ROOT])
        manual_cmd = ('Test cmd:\npushd {cwd}; {env} {checkout} {args}'.format(
            cwd=under_test_dir, env=repo_root, checkout=checkout_path,
            args=' '.join(cmdline)))
        printlog(manual_cmd)
        options = checkout.commandline_arguments(cmdline)
        overall_status, tree_status = checkout.main(options)
        os.chdir(cwd)
        return overall_status, tree_status

    # ----------------------------------------------------------------
    #
    # Check results for generic perturbation of states
    #
    # ----------------------------------------------------------------
    def _check_generic_empty_default_required(self, tree, name):
        self.assertEqual(tree[name].sync_state, ExternalStatus.EMPTY)
        self.assertEqual(tree[name].clean_state, ExternalStatus.DEFAULT)
        self.assertEqual(tree[name].source_type, ExternalStatus.MANAGED)

    def _check_generic_ok_clean_required(self, tree, name):
        self.assertEqual(tree[name].sync_state, ExternalStatus.STATUS_OK)
        self.assertEqual(tree[name].clean_state, ExternalStatus.STATUS_OK)
        self.assertEqual(tree[name].source_type, ExternalStatus.MANAGED)

    def _check_generic_ok_dirty_required(self, tree, name):
        self.assertEqual(tree[name].sync_state, ExternalStatus.STATUS_OK)
        self.assertEqual(tree[name].clean_state, ExternalStatus.DIRTY)
        self.assertEqual(tree[name].source_type, ExternalStatus.MANAGED)

    def _check_generic_modified_ok_required(self, tree, name):
        self.assertEqual(tree[name].sync_state, ExternalStatus.MODEL_MODIFIED)
        self.assertEqual(tree[name].clean_state, ExternalStatus.STATUS_OK)
        self.assertEqual(tree[name].source_type, ExternalStatus.MANAGED)

    def _check_generic_empty_default_optional(self, tree, name):
        self.assertEqual(tree[name].sync_state, ExternalStatus.EMPTY)
        self.assertEqual(tree[name].clean_state, ExternalStatus.DEFAULT)
        self.assertEqual(tree[name].source_type, ExternalStatus.OPTIONAL)

    def _check_generic_ok_clean_optional(self, tree, name):
        self.assertEqual(tree[name].sync_state, ExternalStatus.STATUS_OK)
        self.assertEqual(tree[name].clean_state, ExternalStatus.STATUS_OK)
        self.assertEqual(tree[name].source_type, ExternalStatus.OPTIONAL)

    # ----------------------------------------------------------------
    #
    # Check results for individual named externals
    #
    # ----------------------------------------------------------------
    def _check_simple_tag_empty(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_tag'.format(directory)
        self._check_generic_empty_default_required(tree, name)

    def _check_nested_tag_empty(self, tree, name=EXTERNALS_NAME):
        self._check_generic_empty_default_required(tree, name)

    def _check_simple_tag_ok(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_tag'.format(directory)
        self._check_generic_ok_clean_required(tree, name)

    def _check_nested_tag_ok(self, tree, name=EXTERNALS_NAME):
        self._check_generic_ok_clean_required(tree, name)

    def _check_simple_tag_dirty(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_tag'.format(directory)
        self._check_generic_ok_dirty_required(tree, name)

    def _check_simple_tag_modified(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_tag'.format(directory)
        self._check_generic_modified_ok_required(tree, name)

    def _check_simple_branch_empty(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_branch'.format(directory)
        self._check_generic_empty_default_required(tree, name)

    def _check_nested_branch_empty(self, tree, name=EXTERNALS_NAME):
        self._check_generic_empty_default_required(tree, name)

    def _check_simple_branch_ok(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_branch'.format(directory)
        self._check_generic_ok_clean_required(tree, name)

    def _check_nested_branch_ok(self, tree, name=EXTERNALS_NAME):
        self._check_generic_ok_clean_required(tree, name)

    def _check_simple_branch_modified(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_branch'.format(directory)
        self._check_generic_modified_ok_required(tree, name)

    def _check_simple_hash_empty(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_hash'.format(directory)
        self._check_generic_empty_default_required(tree, name)

    def _check_nested_hash_empty(self, tree, name=EXTERNALS_NAME):
        self._check_generic_empty_default_required(tree, name)

    def _check_simple_hash_ok(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_hash'.format(directory)
        self._check_generic_ok_clean_required(tree, name)

    def _check_nested_hash_ok(self, tree, name=EXTERNALS_NAME):
        self._check_generic_ok_clean_required(tree, name)

    def _check_simple_hash_modified(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_hash'.format(directory)
        self._check_generic_modified_ok_required(tree, name)

    def _check_simple_req_empty(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_req'.format(directory)
        self._check_generic_empty_default_required(tree, name)

    def _check_simple_req_ok(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_req'.format(directory)
        self._check_generic_ok_clean_required(tree, name)

    def _check_simple_opt_empty(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_opt'.format(directory)
        self._check_generic_empty_default_optional(tree, name)

    def _check_simple_opt_ok(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_opt'.format(directory)
        self._check_generic_ok_clean_optional(tree, name)

    def _check_mixed_ext_branch_empty(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/mixed_req'.format(directory)
        self._check_generic_empty_default_required(tree, name)

    def _check_mixed_ext_branch_ok(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/mixed_req'.format(directory)
        self._check_generic_ok_clean_required(tree, name)

    def _check_mixed_ext_branch_modified(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/mixed_req'.format(directory)
        self._check_generic_modified_ok_required(tree, name)

    def _check_simple_sparse_empty(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_sparse'.format(directory)
        self._check_generic_empty_default_required(tree, name)

    def _check_simple_sparse_ok(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/simp_sparse'.format(directory)
        self._check_generic_ok_clean_required(tree, name)

    # ----------------------------------------------------------------
    #
    # Check results for groups of externals under specific conditions
    #
    # ----------------------------------------------------------------
    def _check_container_simple_required_pre_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_empty(tree)
        self._check_simple_branch_empty(tree)
        self._check_simple_hash_empty(tree)

    def _check_container_nested_required_pre_checkout(self, overall, tree, order):
        self.assertEqual(overall, 0)
        self._check_nested_tag_empty(tree, name=NESTED_NAME[order[0]])
        self._check_nested_branch_empty(tree, name=NESTED_NAME[order[1]])
        self._check_nested_hash_empty(tree, name=NESTED_NAME[order[2]])

    def _check_container_simple_required_checkout(self, overall, tree):
        # Note, this is the internal tree status just before checkout
        self.assertEqual(overall, 0)
        self._check_simple_tag_empty(tree)
        self._check_simple_branch_empty(tree)
        self._check_simple_hash_empty(tree)

    def _check_container_nested_required_checkout(self, overall, tree, order):
        # Note, this is the internal tree status just before checkout
        self.assertEqual(overall, 0)
        self._check_nested_tag_empty(tree, name=NESTED_NAME[order[0]])
        self._check_nested_branch_empty(tree, name=NESTED_NAME[order[1]])
        self._check_nested_hash_empty(tree, name=NESTED_NAME[order[2]])

    def _check_container_simple_required_post_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree)
        self._check_simple_branch_ok(tree)
        self._check_simple_hash_ok(tree)

    def _check_container_nested_required_post_checkout(self, overall, tree, order):
        self.assertEqual(overall, 0)
        self._check_nested_tag_ok(tree, name=NESTED_NAME[order[0]])
        self._check_nested_branch_ok(tree, name=NESTED_NAME[order[1]])
        self._check_nested_hash_ok(tree, name=NESTED_NAME[order[2]])

    def _check_container_simple_required_out_of_sync(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_modified(tree)
        self._check_simple_branch_modified(tree)
        self._check_simple_hash_modified(tree)

    def _check_container_simple_optional_pre_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_req_empty(tree)
        self._check_simple_opt_empty(tree)

    def _check_container_simple_optional_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_req_empty(tree)
        self._check_simple_opt_empty(tree)

    def _check_container_simple_optional_post_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_req_ok(tree)
        self._check_simple_opt_empty(tree)

    def _check_container_simple_optional_post_optional(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_req_ok(tree)
        self._check_simple_opt_ok(tree)

    def _check_container_simple_required_sb_modified(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree)
        self._check_simple_branch_modified(tree)
        self._check_simple_hash_ok(tree)

    def _check_container_simple_optional_st_dirty(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_dirty(tree)
        self._check_simple_branch_ok(tree)

    def _check_container_full_pre_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_empty(tree)
        self._check_simple_branch_empty(tree)
        self._check_simple_opt_empty(tree)
        self._check_mixed_ext_branch_required_pre_checkout(overall, tree)

    def _check_container_component_post_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_opt_ok(tree)
        self._check_simple_tag_empty(tree)
        self._check_simple_branch_empty(tree)

    def _check_container_component_post_checkout2(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_empty(tree)
        self._check_simple_branch_ok(tree)

    def _check_container_component_post_checkout3(self, overall, tree):
        self.assertEqual(overall, 0)
        self.assertFalse("simp_opt" in tree)
        self._check_simple_tag_ok(tree)
        self._check_simple_branch_ok(tree)

    def _check_container_full_post_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree)
        self._check_simple_branch_ok(tree)
        self._check_simple_opt_empty(tree)
        self._check_mixed_ext_branch_required_post_checkout(overall, tree)

    def _check_container_full_pre_checkout_ext_change(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree)
        self._check_simple_branch_ok(tree)
        self._check_simple_opt_empty(tree)
        self._check_mixed_ext_branch_required_pre_checkout_ext_change(
            overall, tree)

    def _check_container_full_post_checkout_subext_modified(
            self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree)
        self._check_simple_branch_ok(tree)
        self._check_simple_opt_empty(tree)
        self._check_mixed_ext_branch_required_post_checkout_subext_modified(
            overall, tree)

    def _check_mixed_ext_branch_required_pre_checkout(self, overall, tree):
        # Note, this is the internal tree status just before checkout
        self.assertEqual(overall, 0)
        self._check_mixed_ext_branch_empty(tree, directory=EXTERNALS_NAME)
        # NOTE: externals/mixed_req/src should not exist in the tree
        # since this is the status before checkout of mixed_req.

    def _check_mixed_ext_branch_required_post_checkout(self, overall, tree):
        # Note, this is the internal tree status just before checkout
        self.assertEqual(overall, 0)
        self._check_mixed_ext_branch_ok(tree, directory=EXTERNALS_NAME)
        check_dir = "{0}/{1}/{2}".format(EXTERNALS_NAME, "mixed_req",
                                         SUB_EXTERNALS_PATH)
        self._check_simple_branch_ok(tree, directory=check_dir)

    def _check_mixed_ext_branch_required_pre_checkout_ext_change(
            self, overall, tree):
        # Note, this is the internal tree status just after change the
        # externals description file, but before checkout
        self.assertEqual(overall, 0)
        self._check_mixed_ext_branch_modified(tree, directory=EXTERNALS_NAME)
        check_dir = "{0}/{1}/{2}".format(EXTERNALS_NAME, "mixed_req",
                                         SUB_EXTERNALS_PATH)
        self._check_simple_branch_ok(tree, directory=check_dir)

    def _check_mixed_ext_branch_required_post_checkout_subext_modified(
            self, overall, tree):
        # Note, this is the internal tree status just after change the
        # externals description file, but before checkout
        self.assertEqual(overall, 0)
        self._check_mixed_ext_branch_ok(tree, directory=EXTERNALS_NAME)
        check_dir = "{0}/{1}/{2}".format(EXTERNALS_NAME, "mixed_req",
                                         SUB_EXTERNALS_PATH)
        self._check_simple_branch_modified(tree, directory=check_dir)

    def _check_mixed_cont_simple_required_pre_checkout(self, overall, tree):
        # Note, this is the internal tree status just before checkout
        self.assertEqual(overall, 0)
        self._check_simple_tag_empty(tree, directory=EXTERNALS_NAME)
        self._check_simple_branch_empty(tree, directory=EXTERNALS_NAME)
        self._check_simple_branch_empty(tree, directory=SUB_EXTERNALS_PATH)

    def _check_mixed_cont_simple_required_checkout(self, overall, tree):
        # Note, this is the internal tree status just before checkout
        self.assertEqual(overall, 0)
        self._check_simple_tag_empty(tree, directory=EXTERNALS_NAME)
        self._check_simple_branch_empty(tree, directory=EXTERNALS_NAME)
        self._check_simple_branch_empty(tree, directory=SUB_EXTERNALS_PATH)

    def _check_mixed_cont_simple_required_post_checkout(self, overall, tree):
        # Note, this is the internal tree status just before checkout
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree, directory=EXTERNALS_NAME)
        self._check_simple_branch_ok(tree, directory=EXTERNALS_NAME)
        self._check_simple_branch_ok(tree, directory=SUB_EXTERNALS_PATH)

    def _check_container_sparse_pre_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_empty(tree)
        self._check_simple_sparse_empty(tree)

    def _check_container_sparse_post_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree)
        self._check_simple_sparse_ok(tree)

    def _check_file_exists(self, repo_dir, pathname):
        "Check that <pathname> exists in <repo_dir>"
        self.assertTrue(os.path.exists(os.path.join(repo_dir, pathname)))

    def _check_file_absent(self, repo_dir, pathname):
        "Check that <pathname> does not exist in <repo_dir>"
        self.assertFalse(os.path.exists(os.path.join(repo_dir, pathname)))

class TestSysCheckout(BaseTestSysCheckout):
    """Run systems level tests of checkout_externals

    """
    # NOTE(bja, 2017-11) pylint complains about long method names, but
    # it is hard to differentiate tests without making them more
    # cryptic.
    # pylint: disable=invalid-name

    # ----------------------------------------------------------------
    #
    # Run systems tests
    #
    # ----------------------------------------------------------------
    def test_container_simple_required(self):
        """Verify that a container with simple subrepos
        generates the correct initial status.

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # status of empty repo
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_pre_checkout(overall, tree)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_checkout(overall, tree)

        # status clean checked out
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_post_checkout(overall, tree)

    def test_container_nested_required(self):
        """Verify that a container with nested subrepos
        generates the correct initial status.
        Tests over all possible permutations
        """

        orders = [[0, 1, 2], [1, 2, 0], [2, 0, 1],
                  [0, 2, 1], [2, 1, 0], [1, 0, 2]]
        for n, order in enumerate(orders):
            # create repo
            dest_dir = os.path.join(os.environ[MANIC_TEST_TMP_REPO_ROOT],
                                  self._test_id, "test"+str(n))
            under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME,
                                                  dest_dir_in=dest_dir)
            self._generator.container_nested_required(under_test_dir, order)

            # status of empty repo
            overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                    self.status_args)
            self._check_container_nested_required_pre_checkout(overall, tree, order)

            # checkout
            overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                    self.checkout_args)
            self._check_container_nested_required_checkout(overall, tree, order)

            # status clean checked out
            overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                    self.status_args)
            self._check_container_nested_required_post_checkout(overall, tree, order)

    def test_container_simple_optional(self):
        """Verify that container with an optional simple subrepos
        generates the correct initial status.

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_optional(under_test_dir)

        # check status of empty repo
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_optional_pre_checkout(overall, tree)

        # checkout required
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_optional_checkout(overall, tree)

        # status
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_optional_post_checkout(overall, tree)

        # checkout optional
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.optional_args)
        self._check_container_simple_optional_post_checkout(overall, tree)

        # status
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_optional_post_optional(overall, tree)

    def test_container_simple_verbose(self):
        """Verify that container with simple subrepos runs with verbose status
        output and generates the correct initial status.

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_checkout(overall, tree)

        # check verbose status
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.verbose_args)
        self._check_container_simple_required_post_checkout(overall, tree)

    def test_container_simple_dirty(self):
        """Verify that a container with simple subrepos
        and a dirty status exits gracefully.

        """
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_checkout(overall, tree)

        # add a file to the repo
        tracked = True
        self._add_file_to_repo(under_test_dir, 'externals/simp_tag/tmp.txt',
                               tracked)

        # checkout: pre-checkout status should be dirty, did not
        # modify working copy.
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_optional_st_dirty(overall, tree)

        # verify status is still dirty
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_optional_st_dirty(overall, tree)

    def test_container_simple_untracked(self):
        """Verify that a container with simple subrepos and a untracked files
        is not considered 'dirty' and will attempt an update.

        """
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_checkout(overall, tree)

        # add a file to the repo
        tracked = False
        self._add_file_to_repo(under_test_dir, 'externals/simp_tag/tmp.txt',
                               tracked)

        # checkout: pre-checkout status should be clean, ignoring the
        # untracked file.
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_post_checkout(overall, tree)

        # verify status is still clean
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_post_checkout(overall, tree)

    def test_container_simple_detached_sync(self):
        """Verify that a container with simple subrepos generates the correct
        out of sync status when making commits from a detached head
        state.

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # status of empty repo
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_pre_checkout(overall, tree)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_checkout(overall, tree)

        # make a commit on the detached head of the tag and hash externals
        self._generator.create_commit(under_test_dir, 'simp_tag')
        self._generator.create_commit(under_test_dir, 'simp_hash')
        self._generator.create_commit(under_test_dir, 'simp_branch')

        # status of repo, branch, tag and hash should all be out of sync!
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_out_of_sync(overall, tree)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        # same pre-checkout out of sync status
        self._check_container_simple_required_out_of_sync(overall, tree)

        # now status should be in-sync
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_post_checkout(overall, tree)

    def test_container_remote_branch(self):
        """Verify that a container with remote branch change works

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_checkout(overall, tree)

        # update the config file to point to a different remote with
        # the same branch
        self._generator.update_branch(under_test_dir, 'simp_branch',
                                      REMOTE_BRANCH_FEATURE2, SIMPLE_FORK_NAME)

        # status of simp_branch should be out of sync
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_sb_modified(overall, tree)

        # checkout new externals
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_sb_modified(overall, tree)

        # status should be synced
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_post_checkout(overall, tree)

    def test_container_remote_tag_same_branch(self):
        """Verify that a container with remote tag change works. The new tag
        should not be in the original repo, only the new remote
        fork. The new tag is automatically fetched because it is on
        the branch.

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_checkout(overall, tree)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.update_tag(under_test_dir, 'simp_branch',
                                   'forked-feature-v1', SIMPLE_FORK_NAME)

        # status of simp_branch should be out of sync
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_sb_modified(overall, tree)

        # checkout new externals
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_sb_modified(overall, tree)

        # status should be synced
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_post_checkout(overall, tree)

    def test_container_remote_tag_fetch_all(self):
        """Verify that a container with remote tag change works. The new tag
        should not be in the original repo, only the new remote
        fork. It should also not be on a branch that will be fetch,
        and therefore not fetched by default with 'git fetch'. It will
        only be retreived by 'git fetch --tags'

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_checkout(overall, tree)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.update_tag(under_test_dir, 'simp_branch',
                                   'abandoned-feature', SIMPLE_FORK_NAME)

        # status of simp_branch should be out of sync
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_sb_modified(overall, tree)

        # checkout new externals
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_sb_modified(overall, tree)

        # status should be synced
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_post_checkout(overall, tree)

    def test_container_preserve_dot(self):
        """Verify that after inital checkout, modifying an external git repo
        url to '.' and the current branch will leave it unchanged.

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_required_checkout(overall, tree)

        # update the config file to point to a different remote with
        # the same branch
        self._generator.update_branch(under_test_dir, 'simp_branch',
                                      REMOTE_BRANCH_FEATURE2, SIMPLE_FORK_NAME)
        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)

        # verify status is clean and unmodified
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_post_checkout(overall, tree)

        # update branch to point to a new branch that only exists in
        # the local fork
        self._generator.create_branch(under_test_dir, 'simp_branch',
                                      'private-feature', with_commit=True)
        self._generator.update_branch(under_test_dir, 'simp_branch',
                                      'private-feature',
                                      SIMPLE_LOCAL_ONLY_NAME)
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)

        # verify status is clean and unmodified
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_required_post_checkout(overall, tree)

    def test_container_full(self):
        """Verify that 'full' container with simple and mixed subrepos
        generates the correct initial status.

        The mixed subrepo has a sub-externals file with different
        sub-externals on different branches.

        """
        # create the test repository
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)

        # create the top level externals file
        self._generator.container_full(under_test_dir)

        # inital checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_full_pre_checkout(overall, tree)

        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_full_post_checkout(overall, tree)

        # Check existance of some files
        subrepo_path = os.path.join('externals', 'simp_tag')
        self._check_file_exists(under_test_dir,
                                os.path.join(subrepo_path, 'readme.txt'))
        self._check_file_absent(under_test_dir, os.path.join(subrepo_path,
                                                             'simple_subdir',
                                                             'subdir_file.txt'))

        # update the mixed-use repo to point to different branch
        self._generator.update_branch(under_test_dir, 'mixed_req',
                                      'new-feature', MIXED_REPO_NAME)

        # check status out of sync for mixed_req, but sub-externals
        # are still in sync
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_full_pre_checkout_ext_change(overall, tree)

        # run the checkout. Now the mixed use external and it's
        # sub-exterals should be changed. Returned status is
        # pre-checkout!
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_full_pre_checkout_ext_change(overall, tree)

        # check status out of sync for mixed_req, and sub-externals
        # are in sync.
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_full_post_checkout(overall, tree)

    def test_container_component(self):
        """Verify that optional component checkout works
        """
        # create the test repository
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)

        # create the top level externals file
        self._generator.container_full(under_test_dir)

        # inital checkout, first try a nonexistant component argument noref
        checkout_args = ['simp_opt', 'noref']
        checkout_args.extend(self.checkout_args)

        with self.assertRaises(RuntimeError):
            self.execute_cmd_in_dir(under_test_dir, checkout_args)

        checkout_args = ['simp_opt']
        checkout_args.extend(self.checkout_args)

        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                checkout_args)

        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_component_post_checkout(overall, tree)
        checkout_args.append('simp_branch')
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                checkout_args)
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_component_post_checkout2(overall, tree)

    def test_container_exclude_component(self):
        """Verify that exclude component checkout works
        """
        # create the test repository
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)

        # create the top level externals file
        self._generator.container_full(under_test_dir)

        # inital checkout, exclude simp_opt
        checkout_args = ['--exclude', 'simp_opt']
        checkout_args.extend(self.checkout_args)
        overall, tree = self.execute_cmd_in_dir(under_test_dir, checkout_args)
        checkout_args.append("--status")
        overall, tree = self.execute_cmd_in_dir(under_test_dir, checkout_args)
        self._check_container_component_post_checkout3(overall, tree)

    def test_mixed_simple(self):
        """Verify that a mixed use repo can serve as a 'full' container,
        pulling in a set of externals and a seperate set of sub-externals.

        """
        #import pdb; pdb.set_trace()
        # create repository
        under_test_dir = self.setup_test_repo(MIXED_REPO_NAME)
        # create top level externals file
        self._generator.mixed_simple_base(under_test_dir)
        # NOTE: sub-externals file is already in the repo so we can
        # switch branches during testing. Since this is a mixed-repo
        # serving as the top level container repo, we can't switch
        # during this test.

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_mixed_cont_simple_required_checkout(overall, tree)

        # verify status is clean and unmodified
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_mixed_cont_simple_required_post_checkout(overall, tree)

    def test_container_sparse(self):
        """Verify that 'full' container with simple subrepo
        can run a sparse checkout and generate the correct initial status.

        """
        # create the test repository
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)

        # create the top level externals file
        self._generator.container_sparse(under_test_dir)

        # inital checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_sparse_pre_checkout(overall, tree)

        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_sparse_post_checkout(overall, tree)

        # Check existance of some files
        subrepo_path = os.path.join('externals', 'simp_tag')
        self._check_file_exists(under_test_dir,
                                os.path.join(subrepo_path, 'readme.txt'))
        self._check_file_exists(under_test_dir, os.path.join(subrepo_path,
                                                             'simple_subdir',
                                                             'subdir_file.txt'))
        subrepo_path = os.path.join('externals', 'simp_sparse')
        self._check_file_exists(under_test_dir,
                                os.path.join(subrepo_path, 'readme.txt'))
        self._check_file_absent(under_test_dir, os.path.join(subrepo_path,
                                                             'simple_subdir',
                                                             'subdir_file.txt'))


class TestSysCheckoutSVN(BaseTestSysCheckout):
    """Run systems level tests of checkout_externals accessing svn repositories

    SVN tests - these tests use the svn repository interface. Since
    they require an active network connection, they are significantly
    slower than the git tests. But svn testing is critical. So try to
    design the tests to only test svn repository functionality
    (checkout, switch) and leave generic testing of functionality like
    'optional' to the fast git tests.

    Example timing as of 2017-11:

      * All other git and unit tests combined take between 4-5 seconds

      * Just checking if svn is available for a single test takes 2 seconds.

      * The single svn test typically takes between 10 and 25 seconds
        (depending on the network)!

    NOTE(bja, 2017-11) To enable CI testing we can't use a real remote
    repository that restricts access and it seems inappropriate to hit
    a random open source repo. For now we are just hitting one of our
    own github repos using the github svn server interface. This
    should be "good enough" for basic checkout and swich
    functionality. But if additional svn functionality is required, a
    better solution will be necessary. I think eventually we want to
    create a small local svn repository on the fly (doesn't require an
    svn server or network connection!) and use it for testing.

    """

    def _check_svn_branch_ok(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/svn_branch'.format(directory)
        self._check_generic_ok_clean_required(tree, name)

    def _check_svn_branch_dirty(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/svn_branch'.format(directory)
        self._check_generic_ok_dirty_required(tree, name)

    def _check_svn_tag_ok(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/svn_tag'.format(directory)
        self._check_generic_ok_clean_required(tree, name)

    def _check_svn_tag_modified(self, tree, directory=EXTERNALS_NAME):
        name = './{0}/svn_tag'.format(directory)
        self._check_generic_modified_ok_required(tree, name)

    def _check_container_simple_svn_post_checkout(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree)
        self._check_svn_branch_ok(tree)
        self._check_svn_tag_ok(tree)

    def _check_container_simple_svn_sb_dirty_st_mod(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree)
        self._check_svn_tag_modified(tree)
        self._check_svn_branch_dirty(tree)

    def _check_container_simple_svn_sb_clean_st_mod(self, overall, tree):
        self.assertEqual(overall, 0)
        self._check_simple_tag_ok(tree)
        self._check_svn_tag_modified(tree)
        self._check_svn_branch_ok(tree)

    @staticmethod
    def have_svn_access():
        """Check if we have svn access so we can enable tests that use svn.

        """
        have_svn = False
        cmd = ['svn', 'ls', SVN_TEST_REPO, ]
        try:
            execute_subprocess(cmd)
            have_svn = True
        except BaseException:
            pass
        return have_svn

    def skip_if_no_svn_access(self):
        """Function decorator to disable svn tests when svn isn't available
        """
        have_svn = self.have_svn_access()
        if not have_svn:
            raise unittest.SkipTest("No svn access")

    def test_container_simple_svn(self):
        """Verify that a container repo can pull in an svn branch and svn tag.

        """
        self.skip_if_no_svn_access()
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_svn(under_test_dir)

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)

        # verify status is clean and unmodified
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_svn_post_checkout(overall, tree)

        # update description file to make the tag into a branch and
        # trigger a switch
        self._generator.update_svn_branch(under_test_dir, 'svn_tag', 'trunk')

        # checkout
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)

        # verify status is clean and unmodified
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.status_args)
        self._check_container_simple_svn_post_checkout(overall, tree)

        # add an untracked file to the repo
        tracked = False
        self._add_file_to_repo(under_test_dir,
                               'externals/svn_branch/tmp.txt', tracked)

        # run a no-op checkout: pre-checkout status should be clean,
        # ignoring the untracked file.
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_svn_post_checkout(overall, tree)

        # update description file to make the branch into a tag and
        # trigger a modified sync status
        self._generator.update_svn_branch(under_test_dir, 'svn_tag',
                                          'tags/cesm2.0.beta07')

        # checkout: pre-checkout status should be clean and modified,
        # will modify working copy.
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.checkout_args)
        self._check_container_simple_svn_sb_clean_st_mod(overall, tree)

        # verify status is still clean and unmodified, last
        # checkout modified the working dir state.
        overall, tree = self.execute_cmd_in_dir(under_test_dir,
                                                self.verbose_args)
        self._check_container_simple_svn_post_checkout(overall, tree)

class TestSubrepoCheckout(BaseTestSysCheckout):
    # Need to store information at setUp time for checking
    # pylint: disable=too-many-instance-attributes
    """Run tests to ensure proper handling of repos with submodules.

    By default, submodules in git repositories are checked out. A git
    repository checked out as a submodule is treated as if it was
    listed in an external with the same properties as in the source
    .gitmodules file.
    """

    def setUp(self):
        """Setup for all submodule checkout tests
        Create a repo with two submodule repositories.
        """

        # Run the basic setup
        super().setUp()
        # create test repo
        # We need to do this here (rather than have a static repo) because
        # git submodules do not allow for variables in .gitmodules files
        self._test_repo_name = 'test_repo_with_submodules'
        self._bare_branch_name = 'subrepo_branch'
        self._config_branch_name = 'subrepo_config_branch'
        self._container_extern_name = 'externals_container.cfg'
        self._my_test_dir = os.path.join(os.environ[MANIC_TEST_TMP_REPO_ROOT],
                                         self._test_id)
        self._repo_dir = os.path.join(self._my_test_dir, self._test_repo_name)
        self._checkout_dir = 'repo_with_submodules'
        check_dir = self.setup_test_repo(CONTAINER_REPO_NAME,
                                         dest_dir_in=self._repo_dir)
        self.assertTrue(self._repo_dir == check_dir)
        # Add the submodules
        cwd = os.getcwd()
        fork_repo_dir = os.path.join(self._bare_root, SIMPLE_FORK_NAME)
        simple_repo_dir = os.path.join(self._bare_root, SIMPLE_REPO_NAME)
        self._simple_ext_fork_name = os.path.splitext(SIMPLE_FORK_NAME)[0]
        self._simple_ext_name = os.path.join('sourc',
                                             os.path.splitext(SIMPLE_REPO_NAME)[0])
        os.chdir(self._repo_dir)
        # Add a branch with a subrepo
        cmd = ['git', 'branch', self._bare_branch_name, 'master']
        execute_subprocess(cmd)
        cmd = ['git', 'checkout', self._bare_branch_name]
        execute_subprocess(cmd)
        cmd = ['git', 'submodule', 'add', fork_repo_dir]
        execute_subprocess(cmd)
        cmd = ['git', 'commit', '-am', "'Added simple-ext-fork as a submodule'"]
        execute_subprocess(cmd)
        # Save the fork repo hash for comparison
        os.chdir(self._simple_ext_fork_name)
        self._fork_hash_check = self.get_git_hash()
        os.chdir(self._repo_dir)
        # Now, create a branch to test from_sbmodule
        cmd = ['git', 'branch',
               self._config_branch_name, self._bare_branch_name]
        execute_subprocess(cmd)
        cmd = ['git', 'checkout', self._config_branch_name]
        execute_subprocess(cmd)
        cmd = ['git', 'submodule', 'add', '--name', SIMPLE_REPO_NAME,
               simple_repo_dir, self._simple_ext_name]
        execute_subprocess(cmd)
        # Checkout feature2
        os.chdir(self._simple_ext_name)
        cmd = ['git', 'branch', 'feature2', 'origin/feature2']
        execute_subprocess(cmd)
        cmd = ['git', 'checkout', 'feature2']
        execute_subprocess(cmd)
        # Save the fork repo hash for comparison
        self._simple_hash_check = self.get_git_hash()
        os.chdir(self._repo_dir)
        self.create_externals_file(filename=self._container_extern_name,
                                   dest_dir=self._repo_dir, from_submodule=True)
        cmd = ['git', 'add', self._container_extern_name]
        execute_subprocess(cmd)
        cmd = ['git', 'commit', '-am', "'Added simple-ext as a submodule'"]
        execute_subprocess(cmd)
        # Reset to master
        cmd = ['git', 'checkout', 'master']
        execute_subprocess(cmd)
        os.chdir(cwd)

    @staticmethod
    def get_git_hash(revision="HEAD"):
        """Return the hash for <revision>"""
        cmd = ['git', 'rev-parse', revision]
        git_out = execute_subprocess(cmd, output_to_caller=True)
        return git_out.strip()

    def create_externals_file(self, name='', filename=CFG_NAME, dest_dir=None,
                              branch_name=None, sub_externals=None,
                              from_submodule=False):
        # pylint: disable=too-many-arguments
        """Create a container externals file with only simple externals.

        """
        self._generator.create_config()

        if dest_dir is None:
            dest_dir = self._my_test_dir

        if from_submodule:
            self._generator.create_section(SIMPLE_FORK_NAME,
                                           self._simple_ext_fork_name,
                                           from_submodule=True)
            self._generator.create_section(SIMPLE_REPO_NAME,
                                           self._simple_ext_name,
                                           branch='feature3', path='',
                                           from_submodule=False)
        else:
            if branch_name is None:
                branch_name = 'master'

            self._generator.create_section(self._test_repo_name,
                                           self._checkout_dir,
                                           branch=branch_name,
                                           path=name, externals=sub_externals,
                                           repo_path=self._repo_dir)

        self._generator.write_config(dest_dir, filename=filename)

    def idempotence_check(self, checkout_dir):
        """Verify that calling checkout_externals and
        checkout_externals --status does not cause errors"""
        cwd = os.getcwd()
        os.chdir(checkout_dir)
        overall, _ = self.execute_cmd_in_dir(self._my_test_dir,
                                             self.checkout_args)
        self.assertTrue(overall == 0)
        overall, _ = self.execute_cmd_in_dir(self._my_test_dir,
                                             self.status_args)
        self.assertTrue(overall == 0)
        os.chdir(cwd)

    def test_submodule_checkout_bare(self):
        """Verify that a git repo with submodule is properly checked out
        This test if for where there is no 'externals' keyword in the
        parent repo.
        Correct behavior is that the submodule is checked out using
        normal git submodule behavior.
        """
        simple_ext_fork_tag = "(tag1)"
        simple_ext_fork_status = " "
        self.create_externals_file(branch_name=self._bare_branch_name)
        overall, _ = self.execute_cmd_in_dir(self._my_test_dir,
                                             self.checkout_args)
        self.assertTrue(overall == 0)
        cwd = os.getcwd()
        checkout_dir = os.path.join(self._my_test_dir, self._checkout_dir)
        fork_file = os.path.join(checkout_dir,
                                 self._simple_ext_fork_name, "readme.txt")
        self.assertTrue(os.path.exists(fork_file))
        os.chdir(checkout_dir)
        submods = git_submodule_status(checkout_dir)
        self.assertEqual(len(submods.keys()), 1)
        self.assertTrue(self._simple_ext_fork_name in submods)
        submod = submods[self._simple_ext_fork_name]
        self.assertTrue('hash' in submod)
        self.assertEqual(submod['hash'], self._fork_hash_check)
        self.assertTrue('status' in submod)
        self.assertEqual(submod['status'], simple_ext_fork_status)
        self.assertTrue('tag' in submod)
        self.assertEqual(submod['tag'], simple_ext_fork_tag)
        os.chdir(cwd)
        self.idempotence_check(checkout_dir)

    def test_submodule_checkout_none(self):
        """Verify that a git repo with submodule is properly checked out
        This test is for when 'externals=None' is in parent repo's
        externals cfg file.
        Correct behavior is the submodle is not checked out.
        """
        self.create_externals_file(branch_name=self._bare_branch_name,
                                   sub_externals="none")
        overall, _ = self.execute_cmd_in_dir(self._my_test_dir,
                                             self.checkout_args)
        self.assertTrue(overall == 0)
        cwd = os.getcwd()
        checkout_dir = os.path.join(self._my_test_dir, self._checkout_dir)
        fork_file = os.path.join(checkout_dir,
                                 self._simple_ext_fork_name, "readme.txt")
        self.assertFalse(os.path.exists(fork_file))
        os.chdir(cwd)
        self.idempotence_check(checkout_dir)

    def test_submodule_checkout_config(self): # pylint: disable=too-many-locals
        """Verify that a git repo with submodule is properly checked out
        This test if for when the 'from_submodule' keyword is used in the
        parent repo.
        Correct behavior is that the submodule is checked out using
        normal git submodule behavior.
        """
        tag_check = None # Not checked out as submodule
        status_check = "-" # Not checked out as submodule
        self.create_externals_file(branch_name=self._config_branch_name,
                                   sub_externals=self._container_extern_name)
        overall, _ = self.execute_cmd_in_dir(self._my_test_dir,
                                             self.checkout_args)
        self.assertTrue(overall == 0)
        cwd = os.getcwd()
        checkout_dir = os.path.join(self._my_test_dir, self._checkout_dir)
        fork_file = os.path.join(checkout_dir,
                                 self._simple_ext_fork_name, "readme.txt")
        self.assertTrue(os.path.exists(fork_file))
        os.chdir(checkout_dir)
        # Check submodule status
        submods = git_submodule_status(checkout_dir)
        self.assertEqual(len(submods.keys()), 2)
        self.assertTrue(self._simple_ext_fork_name in submods)
        submod = submods[self._simple_ext_fork_name]
        self.assertTrue('hash' in submod)
        self.assertEqual(submod['hash'], self._fork_hash_check)
        self.assertTrue('status' in submod)
        self.assertEqual(submod['status'], status_check)
        self.assertTrue('tag' in submod)
        self.assertEqual(submod['tag'], tag_check)
        self.assertTrue(self._simple_ext_name in submods)
        submod = submods[self._simple_ext_name]
        self.assertTrue('hash' in submod)
        self.assertEqual(submod['hash'], self._simple_hash_check)
        self.assertTrue('status' in submod)
        self.assertEqual(submod['status'], status_check)
        self.assertTrue('tag' in submod)
        self.assertEqual(submod['tag'], tag_check)
        # Check fork repo status
        os.chdir(self._simple_ext_fork_name)
        self.assertEqual(self.get_git_hash(), self._fork_hash_check)
        os.chdir(checkout_dir)
        os.chdir(self._simple_ext_name)
        hash_check = self.get_git_hash('origin/feature3')
        self.assertEqual(self.get_git_hash(), hash_check)
        os.chdir(cwd)
        self.idempotence_check(checkout_dir)

class TestSysCheckoutErrors(BaseTestSysCheckout):
    """Run systems level tests of error conditions in checkout_externals

    Error conditions - these tests are designed to trigger specific
    error conditions and ensure that they are being handled as
    runtime errors (and hopefully usefull error messages) instead of
    the default internal message that won't mean anything to the
    user, e.g. key error, called process error, etc.

    These are not 'expected failures'. They are pass when a
    RuntimeError is raised, fail if any other error is raised (or no
    error is raised).

    """

    # NOTE(bja, 2017-11) pylint complains about long method names, but
    # it is hard to differentiate tests without making them more
    # cryptic.
    # pylint: disable=invalid-name

    def test_error_unknown_protocol(self):
        """Verify that a runtime error is raised when the user specified repo
        protocol is not known.

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.update_protocol(under_test_dir, 'simp_branch',
                                        'this-protocol-does-not-exist')

        with self.assertRaises(RuntimeError):
            self.execute_cmd_in_dir(under_test_dir, self.checkout_args)

    def test_error_switch_protocol(self):
        """Verify that a runtime error is raised when the user switches
        protocols, git to svn.

        TODO(bja, 2017-11) This correctly results in an error, but it
        isn't a helpful error message.

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.update_protocol(under_test_dir, 'simp_branch', 'svn')
        with self.assertRaises(RuntimeError):
            self.execute_cmd_in_dir(under_test_dir, self.checkout_args)

    def test_error_unknown_tag(self):
        """Verify that a runtime error is raised when the user specified tag
        does not exist.

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.update_tag(under_test_dir, 'simp_branch',
                                   'this-tag-does-not-exist', SIMPLE_REPO_NAME)

        with self.assertRaises(RuntimeError):
            self.execute_cmd_in_dir(under_test_dir, self.checkout_args)

    def test_error_overspecify_tag_branch(self):
        """Verify that a runtime error is raised when the user specified both
        tag and a branch

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.update_tag(under_test_dir, 'simp_branch',
                                   'this-tag-does-not-exist', SIMPLE_REPO_NAME,
                                   remove_branch=False)

        with self.assertRaises(RuntimeError):
            self.execute_cmd_in_dir(under_test_dir, self.checkout_args)

    def test_error_underspecify_tag_branch(self):
        """Verify that a runtime error is raised when the user specified
        neither a tag or a branch

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.update_underspecify_branch_tag(under_test_dir,
                                                       'simp_branch')

        with self.assertRaises(RuntimeError):
            self.execute_cmd_in_dir(under_test_dir, self.checkout_args)

    def test_error_missing_url(self):
        """Verify that a runtime error is raised when the user specified
        neither a tag or a branch

        """
        # create repo
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.update_underspecify_remove_url(under_test_dir,
                                                       'simp_branch')

        with self.assertRaises(RuntimeError):
            self.execute_cmd_in_dir(under_test_dir, self.checkout_args)


if __name__ == '__main__':
    unittest.main()
