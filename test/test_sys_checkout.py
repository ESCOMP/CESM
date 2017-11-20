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

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import os
import os.path
import random
import shutil
import subprocess
import unittest

from manic.externals_description import ExternalsDescription
from manic.externals_description import DESCRIPTION_SECTION, VERSION_ITEM
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
ERROR_REPO_NAME = 'error'
REPO_UNDER_TEST = 'under_test'
EXTERNALS_NAME = 'externals'
CFG_NAME = 'externals.cfg'


def setUpModule():  # pylint: disable=C0103
    """Setup for all tests in this module. It is called once per module!
    """
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
        self._schema_version = '1.0.0'
        self._config = None

    def container_full(self, dest_dir):
        """Create the full container config file with simple and mixed use
        externals

        """
        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_tag',
                            tag='tag1')

        self.create_section(SIMPLE_REPO_NAME, 'simp_branch',
                            branch='feature2')

        self.create_section(SIMPLE_REPO_NAME, 'simp_opt',
                            tag='tag1', required=False)

        self.create_section(MIXED_REPO_NAME, 'mixed_req',
                            tag='tag1', externals='sub-ext.cfg')

        self.create_section(MIXED_REPO_NAME, 'mixed_opt',
                            tag='tag1', externals='sub-ext.cfg',
                            required=False)

        self._write_config(dest_dir)

    def container_simple_required(self, dest_dir):
        """Create a container externals file with only simple externals.

        """
        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_tag',
                            tag='tag1')

        self.create_section(SIMPLE_REPO_NAME, 'simp_branch',
                            branch='feature2')

        self._write_config(dest_dir)

    def container_simple_optional(self, dest_dir):
        """Create a container externals file with optional simple externals

        """
        self.create_config()
        self.create_section(SIMPLE_REPO_NAME, 'simp_req',
                            tag='tag1')

        self.create_section(SIMPLE_REPO_NAME, 'simp_opt',
                            tag='tag1', required=False)

        self._write_config(dest_dir)

    def _write_config(self, dest_dir, filename=CFG_NAME):
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
                       required=True, externals=''):
        """Create a config section with autofilling some items and handling
        optional items.

        """
        self._config.add_section(name)
        self._config.set(name, ExternalsDescription.PATH,
                         os.path.join(EXTERNALS_NAME, name))

        self._config.set(name, ExternalsDescription.PROTOCOL,
                         ExternalsDescription.PROTOCOL_GIT)

        repo_url = os.path.join('${MANIC_TEST_BARE_REPO_ROOT}', repo_type)
        self._config.set(name, ExternalsDescription.REPO_URL, repo_url)

        self._config.set(name, ExternalsDescription.REQUIRED, str(required))

        if tag:
            self._config.set(name, ExternalsDescription.TAG, tag)

        if branch:
            self._config.set(name, ExternalsDescription.BRANCH, branch)

        if externals:
            self._config.set(name, ExternalsDescription.EXTERNALS, externals)


class TestSysCheckout(unittest.TestCase):
    """Run systems level tests of checkout_externals

    """

    def setUp(self):
        """Setup for all individual checkout_externals tests
        """
        # directory we want to return to after the test system and
        # checkout_externals are done cd'ing all over the place.
        self._return_dir = os.getcwd()

        # create a random test id for this test.
        self._test_id = random.randint(0, 999)

        # path to the executable
        self._checkout = os.path.join('../checkout_externals')
        self._checkout = os.path.abspath(self._checkout)

        # directory where we have test repositories
        self._bare_root = os.path.join(os.getcwd(), BARE_REPO_ROOT_NAME)
        self._bare_root = os.path.abspath(self._bare_root)

        # set into the environment so var will be expanded in externals files
        os.environ[MANIC_TEST_BARE_REPO_ROOT] = self._bare_root

        # set the input file generator
        self._generator = GenerateExternalsDescriptionCfgV1()

    def tearDown(self):
        """Tear down for individual tests
        """
        # remove the env var we added in setup
        del os.environ[MANIC_TEST_BARE_REPO_ROOT]

        # return to our common starting point
        os.chdir(self._return_dir)

    def setup_test_repo(self, parent_repo_name):
        """Setup the paths and clone the base test repo

        """
        # unique repo for this test
        test_dir_name = '{0}.{1}'.format(REPO_UNDER_TEST, self._test_id)
        print("Test repository name: {0}".format(test_dir_name))

        parent_repo_dir = os.path.join(self._bare_root, parent_repo_name)
        dest_dir = os.path.join(os.environ[MANIC_TEST_TMP_REPO_ROOT],
                                test_dir_name)
        self.clone_repo(parent_repo_dir, dest_dir)
        return dest_dir

    @staticmethod
    def clone_repo(base_repo_dir, dest_dir):
        """Call git to clone the repository

        """
        cmd = ['git', 'clone', base_repo_dir, dest_dir]
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        return output

    @staticmethod
    def execute_cmd_in_dir(under_test_dir, args):
        """Extecute the checkout command in the appropriate repo dir with the
        specified additional args

        Note that we are calling the command line processing and main
        routines and not using a subprocess call so that we get code
        coverage results!

        """
        cwd = os.getcwd()
        os.chdir(under_test_dir)
        cmdline = ['--externals', CFG_NAME, ]
        cmdline += args
        options = checkout.commandline_arguments(cmdline)
        status = checkout.main(options)
        os.chdir(cwd)
        return status

    def test_container_simple_required(self):
        """Verify that 'full' container with simple and mixed subrepos
        generates the correct initial status.

        """
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_required(under_test_dir)
        args = ['--status']
        status = self.execute_cmd_in_dir(under_test_dir, args)
        self.assertEqual(status, 0)
        status = self.execute_cmd_in_dir(under_test_dir, [])
        self.assertEqual(status, 0)
        status = self.execute_cmd_in_dir(under_test_dir, args)
        self.assertEqual(status, 0)

    def test_container_simple_optional(self):
        """Verify that 'full' container with simple and mixed subrepos
        generates the correct initial status.

        """
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_simple_optional(under_test_dir)
        args = ['--status']
        status = self.execute_cmd_in_dir(under_test_dir, args)
        self.assertEqual(status, 0)
        status = self.execute_cmd_in_dir(under_test_dir, [])
        self.assertEqual(status, 0)
        status = self.execute_cmd_in_dir(under_test_dir, args)
        self.assertEqual(status, 0)

    @unittest.skip('repo development inprogress')
    def test_container_full(self):
        """Verify that 'full' container with simple and mixed subrepos
        generates the correct initial status.

        """
        under_test_dir = self.setup_test_repo(CONTAINER_REPO_NAME)
        self._generator.container_full(under_test_dir)
        args = ['--status']
        status = self.execute_cmd_in_dir(under_test_dir, args)
        self.assertEqual(status, 0)
        status = self.execute_cmd_in_dir(under_test_dir, [])
        self.assertEqual(status, 0)
        status = self.execute_cmd_in_dir(under_test_dir, args)
        self.assertEqual(status, 0)


if __name__ == '__main__':
    unittest.main()
