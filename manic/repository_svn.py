"""Class for interacting with svn repositories
"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import logging
import os
import re
import subprocess
import xml.etree.ElementTree as ET

from .repository import Repository
from .externals_status import ExternalStatus
from .utils import fatal_error, log_process_output
from .utils import check_output, execute_subprocess


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

    def status(self, stat, repo_dir_path):
        """
        Check and report the status of the repository
        """
        self.svn_check_sync(stat, repo_dir_path)
        if os.path.exists(repo_dir_path):
            self.svn_status(stat, repo_dir_path)
        return stat

    def verbose_status(self, repo_dir_path):
        """Display the raw repo status to the user.

        """
        if os.path.exists(repo_dir_path):
            self.svn_status_verbose(repo_dir_path)

    def checkout(self, base_dir_path, repo_dir_name):
        """Checkout or update the working copy

        If the repo destination directory exists, switch the sandbox to
        match the externals description.

        If the repo destination directory does not exist, checkout the
        correct branch or tag.

        """
        repo_dir_path = os.path.join(base_dir_path, repo_dir_name)
        if os.path.exists(repo_dir_path):
            self._svn_switch(repo_dir_path)
        else:
            self._svn_checkout(repo_dir_path)

    def _svn_checkout(self, repo_dir_path):
        """
        Checkout a subversion repository (repo_url) to checkout_dir.
        """
        cmd = ['svn', 'checkout', self._url, repo_dir_path]
        execute_subprocess(cmd)

    def _svn_switch(self, repo_dir_path):
        """
        Switch branches for in an svn sandbox
        """
        cwd = os.getcwd()
        os.chdir(repo_dir_path)
        cmd = ['svn', 'switch', self._url]
        execute_subprocess(cmd)
        os.chdir(cwd)

    @staticmethod
    def svn_info(repo_dir_path):
        """Return results of svn info command
        """
        cmd = ['svn', 'info', repo_dir_path]
        try:
            output = check_output(cmd)
            log_process_output(output)
        except subprocess.CalledProcessError as error:
            logging.info(error)
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
            status = ExternalStatus.UNKNOWN
        elif url == expected_url:
            status = ExternalStatus.STATUS_OK
        else:
            status = ExternalStatus.MODEL_MODIFIED
        return status

    def svn_check_sync(self, stat, repo_dir_path):
        """Check to see if repository directory exists and is at the expected
        url.  Return: status object

        """
        if not os.path.exists(repo_dir_path):
            # NOTE(bja, 2017-10) this state should have been recorded by
            # the source object and we never get here!
            stat.sync_state = ExternalStatus.STATUS_ERROR
        else:
            svn_output = self.svn_info(repo_dir_path)
            if not svn_output:
                # directory exists, but info returned nothing. .svn
                # directory removed or incomplete checkout?
                stat.sync_state = ExternalStatus.UNKNOWN
            else:
                stat.sync_state = self.svn_check_url(svn_output, self._url)

    @staticmethod
    def _svn_status_xml(repo_dir_path):
        """
        Get status of the subversion sandbox in repo_dir
        """
        cmd = ['svn', 'status', '--xml', repo_dir_path]
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

        The only acceptable state returned from svn is 'external'

        """
        # pylint: disable=invalid-name
        SVN_EXTERNAL = 'external'
        # pylint: enable=invalid-name

        is_dirty = False
        xml_status = ET.fromstring(svn_output)
        xml_target = xml_status.find('./target')
        entries = xml_target.findall('./entry')
        for entry in entries:
            status = entry.find('./wc-status')
            item = status.get('item')
            if item != SVN_EXTERNAL:
                is_dirty = True
        return is_dirty

    def svn_status(self, stat, repo_dir_path):
        """Report whether the svn repository is in-sync with the model
        description and whether the sandbox is clean or dirty.

        """
        svn_output = self._svn_status_xml(repo_dir_path)
        is_dirty = self.xml_status_is_dirty(svn_output)
        if is_dirty:
            stat.clean_state = ExternalStatus.DIRTY
        else:
            stat.clean_state = ExternalStatus.STATUS_OK

    @staticmethod
    def _svn_status_verbose(repo_dir_path):
        """capture the full svn status output
        """
        cmd = ['svn', 'status', repo_dir_path]
        svn_output = check_output(cmd)
        return svn_output

    def svn_status_verbose(self, repo_dir_path):
        """Display the raw svn status output to the user.

        """
        svn_output = self._svn_status_verbose(repo_dir_path)
        log_process_output(svn_output)
        print(svn_output)
