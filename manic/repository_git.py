"""Class for interacting with git repositories
"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import os
import re

from .global_constants import EMPTY_STR
from .repository import Repository
from .externals_status import ExternalStatus
from .utils import fatal_error, log_process_output
from .utils import execute_subprocess, check_output


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

    def checkout(self, base_dir_path, repo_dir_name):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        repo_dir_path = os.path.join(base_dir_path, repo_dir_name)
        if not os.path.exists(repo_dir_path):
            self.git_clone(base_dir_path, repo_dir_name)
        self._git_checkout(repo_dir_path)

    def status(self, stat, repo_dir_path):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        self.git_check_sync(stat, repo_dir_path)
        if os.path.exists(repo_dir_path):
            self.git_status(stat, repo_dir_path)

    def verbose_status(self, repo_dir_path):
        """Display the raw repo status to the user.

        """
        if os.path.exists(repo_dir_path):
            self.git_status_verbose(repo_dir_path)

    @staticmethod
    def _git_clone(url, repo_dir_name):
        """Execute clone subprocess
        """
        cmd = ['git', 'clone', url, repo_dir_name]
        execute_subprocess(cmd)

    def git_clone(self, base_dir_path, repo_dir_name):
        """Prepare to execute the clone by managing directory location
        """
        cwd = os.getcwd()
        os.chdir(base_dir_path)
        self._git_clone(self._url, repo_dir_name)
        os.chdir(cwd)

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

    def git_check_sync(self, stat, repo_dir_path):
        """Determine whether a git repository is in-sync with the model
        description.

        Because repos can have multiple remotes, the only criteria is
        whether the branch or tag is the same.

        """
        if not os.path.exists(repo_dir_path):
            # NOTE(bja, 2017-10) condition should have been checkoud
            # by _Source() object and should never be here!
            stat.sync_state = ExternalStatus.STATUS_ERROR
        else:
            git_dir = os.path.join(repo_dir_path, '.git')
            if not os.path.exists(git_dir):
                # NOTE(bja, 2017-10) directory exists, but no git repo
                # info....
                stat.sync_state = ExternalStatus.UNKNOWN
            else:
                cwd = os.getcwd()
                os.chdir(repo_dir_path)
                git_output = self.git_branch()
                ref = self.current_ref_from_branch_command(git_output)
                if ref == EMPTY_STR:
                    stat.sync_state = ExternalStatus.UNKNOWN
                elif self._tag:
                    if self._tag == ref:
                        stat.sync_state = ExternalStatus.STATUS_OK
                    else:
                        stat.sync_state = ExternalStatus.MODEL_MODIFIED
                else:
                    if self._branch == ref:
                        stat.sync_state = ExternalStatus.STATUS_OK
                    else:
                        stat.sync_state = ExternalStatus.MODEL_MODIFIED
                os.chdir(cwd)

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

    def _git_checkout(self, repo_dir_path):
        """
        Checkout 'branch' or 'tag' from 'repo_url'
        """
        if not os.path.exists(repo_dir_path):
            msg = ('DEV_ERROR: Repo not cloned correctly. Trying to '
                   'checkout a git repo for "{0}" in '
                   'an empty directory: {1}'.format(self._name, repo_dir_path))
            fatal_error(msg)

        cwd = os.getcwd()
        os.chdir(repo_dir_path)
        # We have a git repo, is it from the correct URL?
        cmd = ['git', 'config', 'remote.origin.url']
        check_url = check_output(cmd)
        if check_url is not None:
            check_url = check_url.rstrip()

        if check_url != self._url:
            msg = ("Invalid repository in {0}, url = {1}, "
                   "should be {2}".format(repo_dir_path, check_url,
                                          self._url))
            fatal_error(msg)
        cmd = ['git', 'fetch', '--all', '--tags']
        execute_subprocess(cmd)

        cmd = []
        if self._branch:
            cmd = self._checkout_branch_command(repo_dir_path)
        elif self._tag:
            # For now, do a hail mary and hope tag can be checked out
            cmd = ['git', 'checkout', self._tag]
        else:
            msg = "DEV_ERROR: in git repo. Shouldn't be here!"
            fatal_error(msg)

        if cmd:
            execute_subprocess(cmd)

        os.chdir(cwd)

    def _checkout_branch_command(self, repo_dir_path):
        """Construct the command for checking out the specified branch
        """
        cmd = []
        (curr_branch, _) = self._git_current_branch()
        ref_type = self._git_ref_type(self._branch)
        if ref_type == self.GIT_REF_REMOTE_BRANCH:
            cmd = ['git', 'checkout', '--track', 'origin/' + self._branch]
        elif ref_type == self.GIT_REF_LOCAL_BRANCH:
            if curr_branch != self._branch:
                # FIXME(bja, 2017-11) not sure what this branch logic
                # is accomplishing, but it can lead to cmd being
                # undefined without an error. Probably not what we
                # want!
                if not self._git_working_dir_clean(repo_dir_path):
                    msg = ('Working directory "{0}" not clean, '
                           'aborting'.format(repo_dir_path))
                    fatal_error(msg)
                else:
                    cmd = ['git', 'checkout', self._branch]
        else:
            msg = 'Unable to check out branch, "{0}"'.format(self._branch)
            fatal_error(msg)
        return cmd

    @staticmethod
    def git_status_porcelain_v1z():
        """Run the git status command on the cwd and report results in the
        machine parable format that is guarenteed not to change
        between version or user configuration.

        """
        cmd = ['git', 'status', '--porcelain', '-z']
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

    def git_status(self, stat, repo_dir_path):
        """Determine the clean/dirty status of a git repository

        """
        cwd = os.getcwd()
        os.chdir(repo_dir_path)
        git_output = self.git_status_porcelain_v1z()
        os.chdir(cwd)
        is_dirty = self.git_status_v1z_is_dirty(git_output)
        if is_dirty:
            stat.clean_state = ExternalStatus.DIRTY
        else:
            stat.clean_state = ExternalStatus.STATUS_OK

    @staticmethod
    def _git_status_verbose():
        """Run the git status command and capture the output
        """
        cmd = ['git', 'status']
        git_output = check_output(cmd)
        return git_output

    def git_status_verbose(self, repo_dir_path):
        """Display raw git status output to the user

        """
        cwd = os.getcwd()
        os.chdir(repo_dir_path)
        git_output = self._git_status_verbose()
        os.chdir(cwd)
        log_process_output(git_output)
        print(git_output)
