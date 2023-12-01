#!/usr/bin/env python3

"""Unit test driver for checkout_externals

Terminology: 
  * 'container': a repo that has externals
  * 'simple': a repo that has no externals, but is referenced as an external by another repo.
  * 'mixed': a repo that both has externals and is referenced as an external by another repo.

  * 'clean': the local repo matches the version in the externals and has no local modifications.
  * 'empty': the external isn't checked out at all.

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


# Module-wide root directory for all the per-test subdirs we'll create on
# the fly (which are placed under wherever $CWD is when the test runs).
# Set by setupModule().
module_tmp_root_dir = None
TMP_REPO_DIR_NAME = 'tmp'  # subdir under $CWD

# subdir under test/ that holds all of our checked-in repositories (which we
# will clone for these tests).
BARE_REPO_ROOT_NAME = 'repos'

# Environment var referenced by checked-in externals file in mixed-cont-ext.git,
# which should be pointed to the fully-resolved BARE_REPO_ROOT_NAME directory.
# We explicitly clear this after every test, via tearDown().
MIXED_CONT_EXT_ROOT_ENV_VAR = 'MANIC_TEST_BARE_REPO_ROOT'

# Subdirs under bare repo root, each holding a repository. For more info
# on the contents of these repositories, see test/repos/README.md. In these
# tests the 'parent' repos are cloned as a starting point, whereas the 'child'
# repos are checked out when the tests run checkout_externals.
CONTAINER_REPO = 'container.git'     # Parent repo
SIMPLE_REPO = 'simple-ext.git'       # Child repo
SIMPLE_FORK_REPO = 'simple-ext-fork.git'  # Child repo
MIXED_REPO = 'mixed-cont-ext.git'    # Both parent and child
SVN_TEST_REPO = 'simple-ext.svn'     # Subversion repository

# Standard (arbitrary) external names for test configs
TAG_SECTION = 'simp_tag'
BRANCH_SECTION = 'simp_branch'
HASH_SECTION = 'simp_hash'

# All the configs we construct check out their externals into these local paths.
EXTERNALS_PATH = 'externals'
SUB_EXTERNALS_PATH = 'src'  # For mixed test repos, 

# For testing behavior with '.' instead of an explicit paths.
SIMPLE_LOCAL_ONLY_NAME = '.'

# Externals files.
CFG_NAME = 'externals.cfg'  # We construct this on a per-test basis.
CFG_SUB_NAME = 'sub-externals.cfg' # Already exists in mixed-cont-ext repo.

# Arbitrary text file in all the test repos.
README_NAME = 'readme.txt'  

# Branch that exists in both the simple and simple-fork repos.
REMOTE_BRANCH_FEATURE2 = 'feature2'

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

    # Make available to all tests in this file.
    global module_tmp_root_dir
    assert module_tmp_root_dir == None, module_tmp_root_dir
    module_tmp_root_dir = repo_root


class RepoUtils(object):
    """Convenience methods for interacting with git repos."""
    @staticmethod
    def create_branch(repo_base_dir, external_name, branch, with_commit=False):
        """Create branch and optionally (with_commit) add a single commit.
        """
        # pylint: disable=R0913
        cwd = os.getcwd()
        repo_root = os.path.join(repo_base_dir, EXTERNALS_PATH, external_name)
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
    def create_commit(repo_base_dir, external_name):
        """Make a commit to the given external.
        
        This is used to test sync state changes from local commits on
        detached heads and tracking branches.
        """
        cwd = os.getcwd()
        repo_root = os.path.join(repo_base_dir, EXTERNALS_PATH, external_name)
        os.chdir(repo_root)

        msg = 'work on great new feature!'
        with open(README_NAME, 'a') as handle:
            handle.write(msg)
        cmd = ['git', 'add', README_NAME, ]
        execute_subprocess(cmd)
        cmd = ['git', 'commit', '-m', msg, ]
        execute_subprocess(cmd)
        os.chdir(cwd)

    @staticmethod
    def clone_test_repo(bare_root, test_id, parent_repo_name, dest_dir_in):
        """Clone repo at <bare_root>/<parent_repo_name> into dest_dir_in or local per-test-subdir.

        Returns output dir.
        """
        parent_repo_dir = os.path.join(bare_root, parent_repo_name)
        if dest_dir_in is None:
            # create unique subdir for this test
            test_dir_name = test_id
            print("Test repository name: {0}".format(test_dir_name))
            dest_dir = os.path.join(module_tmp_root_dir, test_dir_name)
        else:
            dest_dir = dest_dir_in

        # pylint: disable=W0212
        GitRepository._git_clone(parent_repo_dir, dest_dir, VERBOSITY_DEFAULT)
        return dest_dir

    @staticmethod
    def add_file_to_repo(under_test_dir, filename, tracked):
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

class GenerateExternalsDescriptionCfgV1(object):
    """Building blocks to create ExternalsDescriptionCfgV1 files.

    Basic usage: create_config() multiple create_*(), then write_config().
    Optionally after that: write_with_*().
    """

    def __init__(self, bare_root):
        self._schema_version = '1.1.0'
        self._config = None

        # directory where we have test repositories (which we will clone for
        # tests)
        self._bare_root = bare_root

    def write_config(self, dest_dir, filename=CFG_NAME):
        """Write self._config to disk

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

    def url_for_repo_path(self, repo_path, repo_path_abs=None):
        if repo_path_abs is not None:
            return repo_path_abs
        else:
            return os.path.join(self._bare_root, repo_path)
        
    def create_section(self, repo_path, name, tag='', branch='',
                       ref_hash='', required=True, path=EXTERNALS_PATH,
                       sub_externals='', repo_path_abs=None, from_submodule=False,
                       sparse='', nested=False):
        # pylint: disable=too-many-branches
        """Create a config ExternalsDescription section with the given name.

        Autofills some items and handles some optional items.

        repo_path_abs overrides repo_path (which is relative to the bare repo)
        path is a subdir under repo_path to check out to.
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
                ((repo_path_abs is not None) or tag or ref_hash or branch)):
            printlog('create_section: "from_submodule" is incompatible with '
                     '"repo_url", "tag", "hash", and "branch" options;\n'
                     'Ignoring those options for {}'.format(name))
            repo_url = None
            tag = ''
            ref_hash = ''
            branch = ''

        repo_url = self.url_for_repo_path(repo_path, repo_path_abs)

        if not from_submodule:
            self._config.set(name, ExternalsDescription.REPO_URL, repo_url)

        self._config.set(name, ExternalsDescription.REQUIRED, str(required))

        if tag:
            self._config.set(name, ExternalsDescription.TAG, tag)

        if branch:
            self._config.set(name, ExternalsDescription.BRANCH, branch)

        if ref_hash:
            self._config.set(name, ExternalsDescription.HASH, ref_hash)

        if sub_externals:
            self._config.set(name, ExternalsDescription.EXTERNALS,
                             sub_externals)

        if sparse:
            self._config.set(name, ExternalsDescription.SPARSE, sparse)

        if from_submodule:
            self._config.set(name, ExternalsDescription.SUBMODULE, "True")

    def create_section_reference_to_subexternal(self, name):
        """Just a reference to another externals file.

        """
        # pylint: disable=R0913
        self._config.add_section(name)
        self._config.set(name, ExternalsDescription.PATH, LOCAL_PATH_INDICATOR)

        self._config.set(name, ExternalsDescription.PROTOCOL,
                         ExternalsDescription.PROTOCOL_EXTERNALS_ONLY)

        self._config.set(name, ExternalsDescription.REPO_URL,
                         LOCAL_PATH_INDICATOR)

        self._config.set(name, ExternalsDescription.REQUIRED, str(True))

        self._config.set(name, ExternalsDescription.EXTERNALS, CFG_SUB_NAME)

    def create_svn_external(self, name, url, tag='', branch=''):
        """Create a config section for an svn repository.

        """
        self._config.add_section(name)
        self._config.set(name, ExternalsDescription.PATH,
                         os.path.join(EXTERNALS_PATH, name))

        self._config.set(name, ExternalsDescription.PROTOCOL,
                         ExternalsDescription.PROTOCOL_SVN)

        self._config.set(name, ExternalsDescription.REPO_URL, url)

        self._config.set(name, ExternalsDescription.REQUIRED, str(True))

        if tag:
            self._config.set(name, ExternalsDescription.TAG, tag)

        if branch:
            self._config.set(name, ExternalsDescription.BRANCH, branch)

    def write_with_git_branch(self, dest_dir, name, branch, new_remote_repo_path=None):
        """Update fields in our config and write it to disk.

        name is the key of the ExternalsDescription in self._config to update.
        """
        # pylint: disable=R0913
        self._config.set(name, ExternalsDescription.BRANCH, branch)

        if new_remote_repo_path:
            if new_remote_repo_path == SIMPLE_LOCAL_ONLY_NAME:
                repo_url = SIMPLE_LOCAL_ONLY_NAME
            else:
                repo_url = os.path.join(self._bare_root, new_remote_repo_path)
            self._config.set(name, ExternalsDescription.REPO_URL, repo_url)

        try:
            # remove the tag if it existed
            self._config.remove_option(name, ExternalsDescription.TAG)
        except BaseException:
            pass

        self.write_config(dest_dir)

    def write_with_svn_branch(self, dest_dir, name, branch):
        """Update a repository branch, and potentially the remote.
        """
        # pylint: disable=R0913
        self._config.set(name, ExternalsDescription.BRANCH, branch)

        try:
            # remove the tag if it existed
            self._config.remove_option(name, ExternalsDescription.TAG)
        except BaseException:
            pass

        self.write_config(dest_dir)

    def write_with_tag_and_remote_repo(self, dest_dir, name, tag, new_remote_repo_path,
                                       remove_branch=True):
        """Update a repository tag and the remote.

        NOTE(bja, 2017-11) remove_branch=False should result in an
        overspecified external with both a branch and tag. This is
        used for error condition testing.

        """
        # pylint: disable=R0913
        self._config.set(name, ExternalsDescription.TAG, tag)

        if new_remote_repo_path:
            repo_url = os.path.join(self._bare_root, new_remote_repo_path)
            self._config.set(name, ExternalsDescription.REPO_URL, repo_url)

        try:
            # remove the branch if it existed
            if remove_branch:
                self._config.remove_option(name, ExternalsDescription.BRANCH)
        except BaseException:
            pass

        self.write_config(dest_dir)

    def write_without_branch_tag(self, dest_dir, name):
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

        self.write_config(dest_dir)

    def write_without_repo_url(self, dest_dir, name):
        """Update a repository protocol, and potentially the remote
        """
        # pylint: disable=R0913
        try:
            # remove the repo url if it existed
            self._config.remove_option(name, ExternalsDescription.REPO_URL)
        except BaseException:
            pass

        self.write_config(dest_dir)

    def write_with_protocol(self, dest_dir, name, protocol, repo_path=None):
        """Update a repository protocol, and potentially the remote
        """
        # pylint: disable=R0913
        self._config.set(name, ExternalsDescription.PROTOCOL, protocol)

        if repo_path:
            repo_url = os.path.join(self._bare_root, repo_path)
            self._config.set(name, ExternalsDescription.REPO_URL, repo_url)

        self.write_config(dest_dir)


def _execute_checkout_in_dir(dirname, args, debug_env=''):
    """Execute the checkout command in the appropriate repo dir with the
    specified additional args. 

    args should be a list of strings.
    debug_env shuld be a string of the form 'FOO=bar' or the empty string. 

    Note that we are calling the command line processing and main
    routines and not using a subprocess call so that we get code
    coverage results! Note this means that environment variables are passed
    to checkout_externals via os.environ; debug_env is just used to aid
    manual reproducibility of a given call.

    Returns (overall_status, tree_status)
    where overall_status is 0 for success, nonzero otherwise.
    and tree_status is set if --status was passed in, None otherwise.

    Note this command executes the checkout command, it doesn't
    necessarily do any checking out (e.g. if --status is passed in).
    """
    cwd = os.getcwd()

    # Construct a command line for reproducibility; this command is not
    # actually executed in the test.
    os.chdir(dirname)
    cmdline = ['--externals', CFG_NAME, ]
    cmdline += args
    manual_cmd = ('Running equivalent of:\n'
                  'pushd {dirname}; '
                  '{debug_env} /path/to/checkout_externals {args}'.format(
                      dirname=dirname, debug_env=debug_env,
                      args=' '.join(cmdline)))
    printlog(manual_cmd)
    options = checkout.commandline_arguments(cmdline)
    overall_status, tree_status = checkout.main(options)
    os.chdir(cwd)
    return overall_status, tree_status
        
class BaseTestSysCheckout(unittest.TestCase):
    """Base class of reusable systems level test setup for
    checkout_externals

    """
    # NOTE(bja, 2017-11) pylint complains about long method names, but
    # it is hard to differentiate tests without making them more
    # cryptic.
    # pylint: disable=invalid-name

    # Command-line args for checkout_externals, used in execute_checkout_in_dir()
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

        # directory where we have test repositories (which we will clone for
        # tests)
        self._bare_root = os.path.abspath(
            os.path.join(root_dir, 'test', BARE_REPO_ROOT_NAME))

        # set the input file generator
        self._generator = GenerateExternalsDescriptionCfgV1(self._bare_root)
        # set the input file generator for secondary externals
        self._sub_generator = GenerateExternalsDescriptionCfgV1(self._bare_root)

    def tearDown(self):
        """Tear down for individual tests
        """
        # return to our common starting point
        os.chdir(self._return_dir)
        
        # (in case this was set) Don't pollute environment of other tests.
        os.environ.pop(MIXED_CONT_EXT_ROOT_ENV_VAR,
                       None)  # Don't care if key wasn't set.

    def clone_test_repo(self, parent_repo_name, dest_dir_in=None):
        """Clones repo under self._bare_root"""
        return RepoUtils.clone_test_repo(self._bare_root, self._test_id,
                                         parent_repo_name, dest_dir_in)

    def execute_checkout_in_dir(self, dirname, args, debug_env=''):
        overall_status, tree_status = _execute_checkout_in_dir(dirname, args,
                                                               debug_env=debug_env)
        self.assertEqual(overall_status, 0)
        return tree_status

    def execute_checkout_with_status(self, dirname, args, debug_env=''):
        """Calls checkout a second time to get status if needed."""
        tree_status = self.execute_checkout_in_dir(
            dirname, args, debug_env=debug_env)
        if tree_status is None:
            tree_status = self.execute_checkout_in_dir(dirname,
                                                       self.status_args,
                                                       debug_env=debug_env)
            self.assertNotEqual(tree_status, None)
        return tree_status
    
    def _check_sync_clean(self, ext_status, expected_sync_state,
                          expected_clean_state):
        self.assertEqual(ext_status.sync_state, expected_sync_state)
        self.assertEqual(ext_status.clean_state, expected_clean_state)

    @staticmethod
    def _external_path(section_name, base_path=EXTERNALS_PATH):
        return './{0}/{1}'.format(base_path, section_name)
        
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
    def test_required_bytag(self):
        """Check out a required external pointing to a git tag."""
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, TAG_SECTION,
                                       tag='tag1')
        self._generator.write_config(cloned_repo_dir)

        # externals start out 'empty' aka not checked out.
        tree = self.execute_checkout_in_dir(cloned_repo_dir,
                                            self.status_args)
        local_path_rel = self._external_path(TAG_SECTION)
        self._check_sync_clean(tree[local_path_rel],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        local_path_abs = os.path.join(cloned_repo_dir, local_path_rel)
        self.assertFalse(os.path.exists(local_path_abs))

        # after checkout, the external is 'clean' aka at the correct version.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[local_path_rel],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

        # Actually checked out the desired repo.
        self.assertEqual('origin', GitRepository._remote_name_for_url(
            # Which url to look up
            self._generator.url_for_repo_path(SIMPLE_REPO),
            # Which directory has the local checked-out repo.
            dirname=local_path_abs))
        
        # Actually checked out the desired tag.
        (tag_found, tag_name) = GitRepository._git_current_tag(local_path_abs)
        self.assertEqual(tag_name, 'tag1')

        # Check existence of some simp_tag files
        tag_path = os.path.join('externals', TAG_SECTION)
        self._check_file_exists(cloned_repo_dir,
                                os.path.join(tag_path, README_NAME))
        # Subrepo should not exist (not referenced by configs).
        self._check_file_absent(cloned_repo_dir, os.path.join(tag_path,
                                                             'simple_subdir',
                                                             'subdir_file.txt'))
        
    def test_required_bybranch(self):
        """Check out a required external pointing to a git branch."""
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                       branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # externals start out 'empty' aka not checked out.
        tree = self.execute_checkout_in_dir(cloned_repo_dir,
                                            self.status_args)
        local_path_rel = self._external_path(BRANCH_SECTION)
        self._check_sync_clean(tree[local_path_rel],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        local_path_abs = os.path.join(cloned_repo_dir, local_path_rel)
        self.assertFalse(os.path.exists(local_path_abs))

        # after checkout, the external is 'clean' aka at the correct version.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[local_path_rel],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self.assertTrue(os.path.exists(local_path_abs))

        # Actually checked out the desired repo.
        self.assertEqual('origin', GitRepository._remote_name_for_url(
            # Which url to look up
            self._generator.url_for_repo_path(SIMPLE_REPO),
            # Which directory has the local checked-out repo.
            dirname=local_path_abs))

        # Actually checked out the desired branch. 
        (branch_found, branch_name) = GitRepository._git_current_remote_branch(
            local_path_abs)
        self.assertEquals(branch_name, 'origin/' + REMOTE_BRANCH_FEATURE2)
        
    def test_required_byhash(self):
        """Check out a required external pointing to a git hash."""
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, HASH_SECTION,
                                       ref_hash='60b1cc1a38d63')
        self._generator.write_config(cloned_repo_dir)

        # externals start out 'empty' aka not checked out.
        tree = self.execute_checkout_in_dir(cloned_repo_dir,
                                            self.status_args)
        local_path_rel = self._external_path(HASH_SECTION)
        self._check_sync_clean(tree[local_path_rel],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        local_path_abs = os.path.join(cloned_repo_dir, local_path_rel)
        self.assertFalse(os.path.exists(local_path_abs))

        # after checkout, the externals are 'clean' aka at their correct version.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[local_path_rel],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

        # Actually checked out the desired repo.
        self.assertEqual('origin', GitRepository._remote_name_for_url(
            # Which url to look up
            self._generator.url_for_repo_path(SIMPLE_REPO),
            # Which directory has the local checked-out repo.
            dirname=local_path_abs))

        # Actually checked out the desired hash.
        (hash_found, hash_name) = GitRepository._git_current_hash(
            local_path_abs)
        self.assertTrue(hash_name.startswith('60b1cc1a38d63'),
                        msg=hash_name)
        
    def test_container_nested_required(self):
        """Verify that a container with nested subrepos generates the correct initial status.
        Tests over all possible permutations
        """
        # Output subdirs for each of the externals, to test that one external can be
        # checked out in a subdir of another.
        NESTED_SUBDIR = ['./fred', './fred/wilma', './fred/wilma/barney']

        # Assert that each type of external (e.g. tag vs branch) can be at any parent level
        # (e.g. child/parent/grandparent).
        orders = [[0, 1, 2], [1, 2, 0], [2, 0, 1],
                  [0, 2, 1], [2, 1, 0], [1, 0, 2]]
        for n, order in enumerate(orders):
            dest_dir = os.path.join(module_tmp_root_dir, self._test_id,
                                    "test"+str(n))
            cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO,
                                                   dest_dir_in=dest_dir)
            self._generator.create_config()
            # We happen to check out each section via a different reference (tag/branch/hash) but
            # those don't really matter, we just need to check out three repos into a nested set of
            # directories.
            self._generator.create_section(
                SIMPLE_REPO, TAG_SECTION, nested=True,
                tag='tag1', path=NESTED_SUBDIR[order[0]])
            self._generator.create_section(
                SIMPLE_REPO, BRANCH_SECTION, nested=True,
                branch=REMOTE_BRANCH_FEATURE2, path=NESTED_SUBDIR[order[1]])
            self._generator.create_section(
                SIMPLE_REPO, HASH_SECTION, nested=True,
                ref_hash='60b1cc1a38d63', path=NESTED_SUBDIR[order[2]])
            self._generator.write_config(cloned_repo_dir)

            # all externals start out 'empty' aka not checked out.
            tree = self.execute_checkout_in_dir(cloned_repo_dir,
                                                self.status_args)
            self._check_sync_clean(tree[NESTED_SUBDIR[order[0]]],
                                   ExternalStatus.EMPTY,
                                   ExternalStatus.DEFAULT)
            self._check_sync_clean(tree[NESTED_SUBDIR[order[1]]],
                                   ExternalStatus.EMPTY,
                                   ExternalStatus.DEFAULT)
            self._check_sync_clean(tree[NESTED_SUBDIR[order[2]]],
                                   ExternalStatus.EMPTY,
                                   ExternalStatus.DEFAULT)

            # after checkout, all the repos are 'clean'.
            tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                     self.checkout_args)
            self._check_sync_clean(tree[NESTED_SUBDIR[order[0]]],
                                   ExternalStatus.STATUS_OK,
                                   ExternalStatus.STATUS_OK)
            self._check_sync_clean(tree[NESTED_SUBDIR[order[1]]],
                                   ExternalStatus.STATUS_OK,
                                   ExternalStatus.STATUS_OK)
            self._check_sync_clean(tree[NESTED_SUBDIR[order[2]]],
                                   ExternalStatus.STATUS_OK,
                                   ExternalStatus.STATUS_OK)
            
    def test_container_simple_optional(self):
        """Verify that container with an optional simple subrepos generates
        the correct initial status.

        """
        # create repo and externals config.
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, 'simp_req',
                            tag='tag1')

        self._generator.create_section(SIMPLE_REPO, 'simp_opt',
                            tag='tag1', required=False)

        self._generator.write_config(cloned_repo_dir)

        # all externals start out 'empty' aka not checked out.
        tree = self.execute_checkout_in_dir(cloned_repo_dir,
                                            self.status_args)
        req_status = tree[self._external_path('simp_req')]
        self._check_sync_clean(req_status,
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        self.assertEqual(req_status.source_type, ExternalStatus.MANAGED)

        opt_status = tree[self._external_path('simp_opt')]
        self._check_sync_clean(opt_status,
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        self.assertEqual(opt_status.source_type, ExternalStatus.OPTIONAL)

        # after checkout, required external is clean, optional is still empty.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        req_status = tree[self._external_path('simp_req')]
        self._check_sync_clean(req_status,
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self.assertEqual(req_status.source_type, ExternalStatus.MANAGED)
        
        opt_status = tree[self._external_path('simp_opt')]
        self._check_sync_clean(opt_status,
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        self.assertEqual(opt_status.source_type, ExternalStatus.OPTIONAL)

        # after checking out optionals, the optional external is also clean.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.optional_args)
        req_status = tree[self._external_path('simp_req')]        
        self._check_sync_clean(req_status,
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self.assertEqual(req_status.source_type, ExternalStatus.MANAGED)

        opt_status = tree[self._external_path('simp_opt')]
        self._check_sync_clean(opt_status,
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self.assertEqual(opt_status.source_type, ExternalStatus.OPTIONAL)

    def test_container_simple_verbose(self):
        """Verify that verbose status matches non-verbose.
        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, TAG_SECTION,
                                 tag='tag1')
        self._generator.write_config(cloned_repo_dir)

        # after checkout, all externals should be 'clean'.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

        # 'Verbose' status should tell the same story.
        tree = self.execute_checkout_in_dir(cloned_repo_dir,
                                            self.verbose_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

    def test_container_simple_dirty(self):
        """Verify that a container with a new tracked file is marked dirty.
        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, TAG_SECTION,
                                 tag='tag1')
        self._generator.write_config(cloned_repo_dir)

        # checkout, should start out clean.
        tree = self.execute_checkout_with_status(cloned_repo_dir, self.checkout_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

        # add a tracked file to the simp_tag external, should be dirty.
        RepoUtils.add_file_to_repo(cloned_repo_dir,
                                   'externals/{0}/tmp.txt'.format(TAG_SECTION),
                                   tracked=True)
        tree = self.execute_checkout_in_dir(cloned_repo_dir, self.status_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.DIRTY)

        # Re-checkout; simp_tag should still be dirty.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.DIRTY)

    def test_container_simple_untracked(self):
        """Verify that a container with simple subrepos and a untracked files
        is not considered 'dirty' and will attempt an update.

        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, TAG_SECTION,
                                       tag='tag1')
        self._generator.write_config(cloned_repo_dir)

        # checkout, should start out clean.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

        # add an untracked file to the simp_tag external, should stay clean.
        RepoUtils.add_file_to_repo(cloned_repo_dir,
                                   'externals/{0}/tmp.txt'.format(TAG_SECTION),
                                   tracked=False)
        tree = self.execute_checkout_in_dir(cloned_repo_dir, self.status_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        
        # After checkout, the external should still be 'clean'.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

    def test_container_simple_detached_sync(self):
        """Verify that a container with simple subrepos generates the correct
        out of sync status when making commits from a detached head
        state. 

        For more info about 'detached head' state: https://www.cloudbees.com/blog/git-detached-head
        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, TAG_SECTION,
                                 tag='tag1')
        
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                 branch=REMOTE_BRANCH_FEATURE2)
        
        self._generator.create_section(SIMPLE_REPO, 'simp_hash',
                                 ref_hash='60b1cc1a38d63')
        
        self._generator.write_config(cloned_repo_dir)

        # externals start out 'empty' aka not checked out.
        tree = self.execute_checkout_in_dir(cloned_repo_dir, self.status_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        self._check_sync_clean(tree[self._external_path(HASH_SECTION)],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)

        # checkout
        self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

        # Commit on top of the tag and hash (creating the detached head state in those two
        # externals' repos)
        # The branch commit does not create the detached head state, but here for completeness.
        RepoUtils.create_commit(cloned_repo_dir, TAG_SECTION)
        RepoUtils.create_commit(cloned_repo_dir, HASH_SECTION)
        RepoUtils.create_commit(cloned_repo_dir, BRANCH_SECTION)

        # sync status of all three should be 'modified' (uncommitted changes)
        # clean status is 'ok' (matches externals version)
        tree = self.execute_checkout_in_dir(cloned_repo_dir, self.status_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.MODEL_MODIFIED,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.MODEL_MODIFIED,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path(HASH_SECTION)],
                               ExternalStatus.MODEL_MODIFIED,
                               ExternalStatus.STATUS_OK)

        # after checkout, all externals should be totally clean (no uncommitted changes,
        # and matches externals version).
        tree = self.execute_checkout_with_status(cloned_repo_dir, self.checkout_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path(HASH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

    def test_container_remote_branch(self):
        """Verify that a container with remote branch change works

        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                 branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # initial checkout
        self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

        # update the branch external to point to a different remote with the same branch,
        # then simp_branch should be out of sync
        self._generator.write_with_git_branch(cloned_repo_dir,
                                              name=BRANCH_SECTION,
                                              branch=REMOTE_BRANCH_FEATURE2,
                                              new_remote_repo_path=SIMPLE_FORK_REPO)
        tree = self.execute_checkout_in_dir(cloned_repo_dir, self.status_args)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.MODEL_MODIFIED,
                               ExternalStatus.STATUS_OK)

        # checkout new externals, now simp_branch should be clean.
        tree = self.execute_checkout_with_status(cloned_repo_dir, self.checkout_args)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

    def test_container_remote_tag_same_branch(self):
        """Verify that a container with remote tag change works. The new tag
        should not be in the original repo, only the new remote
        fork. The new tag is automatically fetched because it is on
        the branch.

        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                       branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # initial checkout
        self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

        # update the config file to point to a different remote with
        # the new tag replacing the old branch. Tag MUST NOT be in the original
        # repo! status of simp_branch should then be out of sync
        self._generator.write_with_tag_and_remote_repo(cloned_repo_dir, BRANCH_SECTION,
                                                       tag='forked-feature-v1',
                                                       new_remote_repo_path=SIMPLE_FORK_REPO)
        tree = self.execute_checkout_in_dir(cloned_repo_dir,
                                            self.status_args)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.MODEL_MODIFIED,
                               ExternalStatus.STATUS_OK)

        # checkout new externals, then should be synced.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

    def test_container_remote_tag_fetch_all(self):
        """Verify that a container with remote tag change works. The new tag
        should not be in the original repo, only the new remote
        fork. It should also not be on a branch that will be fetched,
        and therefore not fetched by default with 'git fetch'. It will
        only be retrieved by 'git fetch --tags'
        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                 branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # initial checkout
        self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

        # update the config file to point to a different remote with
        # the new tag instead of the old branch. Tag MUST NOT be in the original
        # repo! status of simp_branch should then be out of sync.
        self._generator.write_with_tag_and_remote_repo(cloned_repo_dir, BRANCH_SECTION,
                                                       tag='abandoned-feature',
                                                       new_remote_repo_path=SIMPLE_FORK_REPO)
        tree = self.execute_checkout_in_dir(cloned_repo_dir, self.status_args)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.MODEL_MODIFIED,
                               ExternalStatus.STATUS_OK)

        # checkout new externals, should be clean again.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

    def test_container_preserve_dot(self):
        """Verify that after inital checkout, modifying an external git repo
        url to '.' and the current branch will leave it unchanged.

        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                 branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # initial checkout
        self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

        # update the config file to point to a different remote with
        # the same branch.
        self._generator.write_with_git_branch(cloned_repo_dir, name=BRANCH_SECTION,
                                              branch=REMOTE_BRANCH_FEATURE2,
                                              new_remote_repo_path=SIMPLE_FORK_REPO)
        # after checkout, should be clean again.
        tree = self.execute_checkout_with_status(cloned_repo_dir, self.checkout_args)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

        # update branch to point to a new branch that only exists in
        # the local fork
        RepoUtils.create_branch(cloned_repo_dir, external_name=BRANCH_SECTION,
                                branch='private-feature', with_commit=True)
        self._generator.write_with_git_branch(cloned_repo_dir, name=BRANCH_SECTION,
                                              branch='private-feature',
                                              new_remote_repo_path=SIMPLE_LOCAL_ONLY_NAME)
        # after checkout, should be clean again.
        tree = self.execute_checkout_with_status(cloned_repo_dir, self.checkout_args)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

    def test_container_mixed_subrepo(self):
        """Verify container with mixed subrepo.

        The mixed subrepo has a sub-externals file with different
        sub-externals on different branches.

        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)

        self._generator.create_config()
        self._generator.create_section(MIXED_REPO, 'mixed_req',
                                       branch='master', sub_externals=CFG_SUB_NAME)
        self._generator.write_config(cloned_repo_dir)

        # The subrepo has a repo_url that uses this environment variable.
        # It'll be cleared in tearDown().
        os.environ[MIXED_CONT_EXT_ROOT_ENV_VAR] = self._bare_root
        debug_env = MIXED_CONT_EXT_ROOT_ENV_VAR + '=' + self._bare_root 
        
        # inital checkout: all requireds are clean, and optional is empty.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args,
                                                 debug_env=debug_env)
        mixed_req_path = self._external_path('mixed_req')
        self._check_sync_clean(tree[mixed_req_path],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        sub_ext_base_path = "{0}/{1}/{2}".format(EXTERNALS_PATH, 'mixed_req', SUB_EXTERNALS_PATH)
        # The already-checked-in subexternals file has a 'simp_branch' section
        self._check_sync_clean(tree[self._external_path('simp_branch', base_path=sub_ext_base_path)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

        # update the mixed-use external to point to different branch
        # status should become out of sync for mixed_req, but sub-externals
        # are still in sync
        self._generator.write_with_git_branch(cloned_repo_dir, name='mixed_req',
                                              branch='new-feature',
                                              new_remote_repo_path=MIXED_REPO)
        tree = self.execute_checkout_in_dir(cloned_repo_dir, self.status_args,
                                            debug_env=debug_env)
        self._check_sync_clean(tree[mixed_req_path],
                               ExternalStatus.MODEL_MODIFIED,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path('simp_branch', base_path=sub_ext_base_path)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

        # run the checkout. Now the mixed use external and its sub-externals should be clean.
        tree = self.execute_checkout_with_status(cloned_repo_dir, self.checkout_args,
                                                 debug_env=debug_env)
        self._check_sync_clean(tree[mixed_req_path],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path('simp_branch', base_path=sub_ext_base_path)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        
    def test_container_component(self):
        """Verify that optional component checkout works
        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)

        # create the top level externals file
        self._generator.create_config()
        # Optional external, by tag.
        self._generator.create_section(SIMPLE_REPO, 'simp_opt',
                                       tag='tag1', required=False)

        # Required external, by branch.
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                       branch=REMOTE_BRANCH_FEATURE2)

        # Required external, by hash.
        self._generator.create_section(SIMPLE_REPO, HASH_SECTION,
                                       ref_hash='60b1cc1a38d63')
        self._generator.write_config(cloned_repo_dir)
        
        # inital checkout, first try a nonexistent component argument noref
        checkout_args = ['simp_opt', 'noref']
        checkout_args.extend(self.checkout_args)

        with self.assertRaises(RuntimeError):
            self.execute_checkout_in_dir(cloned_repo_dir, checkout_args)

        # Now explicitly check out one optional component..
        # Explicitly listed component (opt) should be present, the other two not.
        checkout_args = ['simp_opt']
        checkout_args.extend(self.checkout_args)
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 checkout_args)
        self._check_sync_clean(tree[self._external_path('simp_opt')],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        self._check_sync_clean(tree[self._external_path(HASH_SECTION)],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)

        # Check out a second component, this one required.
        # Explicitly listed component (branch) should be present, the still-unlisted one (tag) not.
        checkout_args.append(BRANCH_SECTION)
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 checkout_args)
        self._check_sync_clean(tree[self._external_path('simp_opt')],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path(HASH_SECTION)],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)


    def test_container_exclude_component(self):
        """Verify that exclude component checkout works
        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, TAG_SECTION,
                                 tag='tag1')
        
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                 branch=REMOTE_BRANCH_FEATURE2)
        
        self._generator.create_section(SIMPLE_REPO, 'simp_hash',
                                 ref_hash='60b1cc1a38d63')
        
        self._generator.write_config(cloned_repo_dir)

        # inital checkout should result in all externals being clean except excluded TAG_SECTION.
        checkout_args = ['--exclude', TAG_SECTION]
        checkout_args.extend(self.checkout_args)
        tree = self.execute_checkout_with_status(cloned_repo_dir, checkout_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.EMPTY,
                               ExternalStatus.DEFAULT)
        self._check_sync_clean(tree[self._external_path(BRANCH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path(HASH_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

    def test_subexternal(self):
        """Verify that an externals file can be brought in as a reference.

        """
        cloned_repo_dir = self.clone_test_repo(MIXED_REPO)

        self._generator.create_config()
        self._generator.create_section_reference_to_subexternal('mixed_base')
        self._generator.write_config(cloned_repo_dir)

        # The subrepo has a repo_url that uses this environment variable.
        # It'll be cleared in tearDown().
        os.environ[MIXED_CONT_EXT_ROOT_ENV_VAR] = self._bare_root
        debug_env = MIXED_CONT_EXT_ROOT_ENV_VAR + '=' + self._bare_root 

        # After checkout, confirm required's are clean and the referenced
        # subexternal's contents are also clean.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args,
                                                 debug_env=debug_env)
        
        self._check_sync_clean(
            tree[self._external_path(BRANCH_SECTION, base_path=SUB_EXTERNALS_PATH)],
            ExternalStatus.STATUS_OK,
            ExternalStatus.STATUS_OK)

    def test_container_sparse(self):
        """Verify that 'full' container with simple subrepo
        can run a sparse checkout and generate the correct initial status.

        """
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)

        # Create a file to list filenames to checkout.
        sparse_filename = 'sparse_checkout'
        with open(os.path.join(cloned_repo_dir, sparse_filename), 'w') as sfile:
            sfile.write(README_NAME)

        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, TAG_SECTION,
                                       tag='tag2')

        # Same tag as above, but with a sparse file too.
        sparse_relpath = '../../' + sparse_filename
        self._generator.create_section(SIMPLE_REPO, 'simp_sparse',
                                       tag='tag2', sparse=sparse_relpath)

        self._generator.write_config(cloned_repo_dir)

        # inital checkout, confirm required's are clean.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._external_path('simp_sparse')],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

        # Check existence of some files - full set in TAG_SECTION, and sparse set
        # in 'simp_sparse'.
        subrepo_path = os.path.join('externals', TAG_SECTION)
        self._check_file_exists(cloned_repo_dir,
                                os.path.join(subrepo_path, README_NAME))
        self._check_file_exists(cloned_repo_dir, os.path.join(subrepo_path,
                                                             'simple_subdir',
                                                             'subdir_file.txt'))
        subrepo_path = os.path.join('externals', 'simp_sparse')
        self._check_file_exists(cloned_repo_dir,
                                os.path.join(subrepo_path, README_NAME))
        self._check_file_absent(cloned_repo_dir, os.path.join(subrepo_path,
                                                             'simple_subdir',
                                                             'subdir_file.txt'))

class TestSysCheckoutSVN(BaseTestSysCheckout):
    """Run systems level tests of checkout_externals accessing svn repositories

    SVN tests - these tests use the svn repository interface.
    """

    @staticmethod
    def _svn_branch_name():
        return './{0}/svn_branch'.format(EXTERNALS_PATH)

    @staticmethod
    def _svn_tag_name():
        return './{0}/svn_tag'.format(EXTERNALS_PATH)
    
    def _svn_test_repo_url(self):
        return 'file://' + os.path.join(self._bare_root, SVN_TEST_REPO)

    def _check_tag_branch_svn_tag_clean(self, tree):
        self._check_sync_clean(tree[self._external_path(TAG_SECTION)],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._svn_branch_name()],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)
        self._check_sync_clean(tree[self._svn_tag_name()],
                               ExternalStatus.STATUS_OK,
                               ExternalStatus.STATUS_OK)

    def _have_svn_access(self):
        """Check if we have svn access so we can enable tests that use svn.

        """
        have_svn = False
        cmd = ['svn', 'ls', self._svn_test_repo_url(), ]
        try:
            execute_subprocess(cmd)
            have_svn = True
        except BaseException:
            pass
        return have_svn

    def _skip_if_no_svn_access(self):
        """Function decorator to disable svn tests when svn isn't available
        """
        have_svn = self._have_svn_access()
        if not have_svn:
            raise unittest.SkipTest("No svn access")

    def test_container_simple_svn(self):
        """Verify that a container repo can pull in an svn branch and svn tag.

        """
        self._skip_if_no_svn_access()
        # create repo
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)

        self._generator.create_config()
        # Git repo.
        self._generator.create_section(SIMPLE_REPO, TAG_SECTION, tag='tag1')

        # Svn repos.
        self._generator.create_svn_external('svn_branch', self._svn_test_repo_url(), branch='trunk')
        self._generator.create_svn_external('svn_tag', self._svn_test_repo_url(), tag='tags/cesm2.0.beta07')

        self._generator.write_config(cloned_repo_dir)

        # checkout, make sure all sections are clean.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_tag_branch_svn_tag_clean(tree)

        # update description file to make the tag into a branch and
        # trigger a switch
        self._generator.write_with_svn_branch(cloned_repo_dir, 'svn_tag',
                                              'trunk')

        # checkout, again the results should be clean.
        tree = self.execute_checkout_with_status(cloned_repo_dir,
                                                 self.checkout_args)
        self._check_tag_branch_svn_tag_clean(tree)

        # add an untracked file to the repo
        tracked = False
        RepoUtils.add_file_to_repo(cloned_repo_dir,
                                   'externals/svn_branch/tmp.txt', tracked)

        # run a no-op checkout.
        self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

        # update description file to make the branch into a tag and
        # trigger a modified sync status
        self._generator.write_with_svn_branch(cloned_repo_dir, 'svn_tag',
                                              'tags/cesm2.0.beta07')

        self.execute_checkout_in_dir(cloned_repo_dir,self.checkout_args)

        # verify status is still clean and unmodified, last
        # checkout modified the working dir state.
        tree = self.execute_checkout_in_dir(cloned_repo_dir,
                                            self.verbose_args)
        self._check_tag_branch_svn_tag_clean(tree)

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
        self._my_test_dir = os.path.join(module_tmp_root_dir, self._test_id)
        self._repo_dir = os.path.join(self._my_test_dir, self._test_repo_name)
        self._checkout_dir = 'repo_with_submodules'
        check_dir = self.clone_test_repo(CONTAINER_REPO,
                                         dest_dir_in=self._repo_dir)
        self.assertTrue(self._repo_dir == check_dir)
        # Add the submodules
        cwd = os.getcwd()
        fork_repo_dir = os.path.join(self._bare_root, SIMPLE_FORK_REPO)
        simple_repo_dir = os.path.join(self._bare_root, SIMPLE_REPO)
        self._simple_ext_fork_name = os.path.splitext(SIMPLE_FORK_REPO)[0]
        self._simple_ext_name = os.path.join('sourc',
                                             os.path.splitext(SIMPLE_REPO)[0])
        os.chdir(self._repo_dir)
        # Add a branch with a subrepo
        cmd = ['git', 'branch', self._bare_branch_name, 'master']
        execute_subprocess(cmd)
        cmd = ['git', 'checkout', self._bare_branch_name]
        execute_subprocess(cmd)
        cmd = ['git', '-c', 'protocol.file.allow=always','submodule', 'add', fork_repo_dir]
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
        cmd = ['git', '-c', 'protocol.file.allow=always', 'submodule', 'add', '--name', SIMPLE_REPO,
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
        self.write_externals_config(filename=self._container_extern_name,
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

    def write_externals_config(self, name='', dest_dir=None,
                               filename=CFG_NAME,
                               branch_name=None, sub_externals=None,
                               from_submodule=False):
        # pylint: disable=too-many-arguments
        """Create a container externals file with only simple externals.

        """
        self._generator.create_config()

        if dest_dir is None:
            dest_dir = self._my_test_dir

        if from_submodule:
            self._generator.create_section(SIMPLE_FORK_REPO,
                                           self._simple_ext_fork_name,
                                           from_submodule=True)
            self._generator.create_section(SIMPLE_REPO,
                                           self._simple_ext_name,
                                           branch='feature3', path='',
                                           from_submodule=False)
        else:
            if branch_name is None:
                branch_name = 'master'

            self._generator.create_section(self._test_repo_name,
                                           self._checkout_dir,
                                           branch=branch_name,
                                           path=name, sub_externals=sub_externals,
                                           repo_path_abs=self._repo_dir)

        self._generator.write_config(dest_dir, filename=filename)

    def idempotence_check(self, checkout_dir):
        """Verify that calling checkout_externals and
        checkout_externals --status does not cause errors"""
        cwd = os.getcwd()
        os.chdir(checkout_dir)
        self.execute_checkout_in_dir(self._my_test_dir,
                                     self.checkout_args)
        self.execute_checkout_in_dir(self._my_test_dir,
                                     self.status_args)
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
        self.write_externals_config(branch_name=self._bare_branch_name)
        self.execute_checkout_in_dir(self._my_test_dir,
                                     self.checkout_args)
        cwd = os.getcwd()
        checkout_dir = os.path.join(self._my_test_dir, self._checkout_dir)
        fork_file = os.path.join(checkout_dir,
                                 self._simple_ext_fork_name, "readme.txt")
        self.assertTrue(os.path.exists(fork_file))

        submods = git_submodule_status(checkout_dir)
        print('checking status of', checkout_dir, ':', submods)
        self.assertEqual(len(submods.keys()), 1)
        self.assertTrue(self._simple_ext_fork_name in submods)
        submod = submods[self._simple_ext_fork_name]
        self.assertTrue('hash' in submod)
        self.assertEqual(submod['hash'], self._fork_hash_check)
        self.assertTrue('status' in submod)
        self.assertEqual(submod['status'], simple_ext_fork_status)
        self.assertTrue('tag' in submod)
        self.assertEqual(submod['tag'], simple_ext_fork_tag)
        self.idempotence_check(checkout_dir)

    def test_submodule_checkout_none(self):
        """Verify that a git repo with submodule is properly checked out
        This test is for when 'externals=None' is in parent repo's
        externals cfg file.
        Correct behavior is the submodle is not checked out.
        """
        self.write_externals_config(branch_name=self._bare_branch_name,
                                    sub_externals="none")
        self.execute_checkout_in_dir(self._my_test_dir,
                                     self.checkout_args)
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
        self.write_externals_config(branch_name=self._config_branch_name,
                                    sub_externals=self._container_extern_name)
        self.execute_checkout_in_dir(self._my_test_dir,
                                     self.checkout_args)
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
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                       branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.write_with_protocol(cloned_repo_dir, BRANCH_SECTION,
                                            'this-protocol-does-not-exist')

        with self.assertRaises(RuntimeError):
            self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

    def test_error_switch_protocol(self):
        """Verify that a runtime error is raised when the user switches
        protocols, git to svn.

        TODO(bja, 2017-11) This correctly results in an error, but it
        isn't a helpful error message.

        """
        # create repo
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                       branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.write_with_protocol(cloned_repo_dir, BRANCH_SECTION, 'svn')
        with self.assertRaises(RuntimeError):
            self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

    def test_error_unknown_tag(self):
        """Verify that a runtime error is raised when the user specified tag
        does not exist.

        """
        # create repo
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                       branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.write_with_tag_and_remote_repo(cloned_repo_dir, BRANCH_SECTION,
                                                       tag='this-tag-does-not-exist',
                                                       new_remote_repo_path=SIMPLE_REPO)

        with self.assertRaises(RuntimeError):
            self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

    def test_error_overspecify_tag_branch(self):
        """Verify that a runtime error is raised when the user specified both
        tag and a branch

        """
        # create repo
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                       branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.write_with_tag_and_remote_repo(cloned_repo_dir, BRANCH_SECTION,
                                                       tag='this-tag-does-not-exist',
                                                       new_remote_repo_path=SIMPLE_REPO,
                                                       remove_branch=False)

        with self.assertRaises(RuntimeError):
            self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

    def test_error_underspecify_tag_branch(self):
        """Verify that a runtime error is raised when the user specified
        neither a tag or a branch

        """
        # create repo
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                       branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.write_without_branch_tag(cloned_repo_dir, BRANCH_SECTION)

        with self.assertRaises(RuntimeError):
            self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)

    def test_error_missing_url(self):
        """Verify that a runtime error is raised when the user specified
        neither a tag or a branch

        """
        # create repo
        cloned_repo_dir = self.clone_test_repo(CONTAINER_REPO)
        self._generator.create_config()
        self._generator.create_section(SIMPLE_REPO, BRANCH_SECTION,
                                       branch=REMOTE_BRANCH_FEATURE2)
        self._generator.write_config(cloned_repo_dir)

        # update the config file to point to a different remote with
        # the tag instead of branch. Tag MUST NOT be in the original
        # repo!
        self._generator.write_without_repo_url(cloned_repo_dir,
                                               BRANCH_SECTION)

        with self.assertRaises(RuntimeError):
            self.execute_checkout_in_dir(cloned_repo_dir, self.checkout_args)


if __name__ == '__main__':
    unittest.main()
