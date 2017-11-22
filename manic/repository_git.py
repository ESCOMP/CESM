"""Class for interacting with git repositories
"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import copy
import os
import re

from .global_constants import EMPTY_STR
from .repository import Repository
from .externals_status import ExternalStatus
from .utils import expand_local_url, split_remote_url, is_remote_url
from .utils import log_process_output
from .utils import execute_subprocess, check_output


class GitRepository(Repository):
    """Class to represent and operate on a repository description.

    For testing purpose, all system calls to git should:

    * be isolated in separate functions with no application logic
      * of the form:
         - cmd = ['git', ...]
         - value = check_output(cmd)
         - return value
      * be static methods (not rely on self)
      * name as _git_subcommand_args(user_args)

    This convention allows easy unit testing of the repository logic
    by mocking the specific calls to return predefined results.

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

    # ----------------------------------------------------------------
    #
    # Public API, defined by Repository
    #
    # ----------------------------------------------------------------
    def checkout(self, base_dir_path, repo_dir_name):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        repo_dir_path = os.path.join(base_dir_path, repo_dir_name)
        if not os.path.exists(repo_dir_path):
            self._clone_repo(base_dir_path, repo_dir_name)
        self._checkout_external_ref(repo_dir_path)

    def status(self, stat, repo_dir_path):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        self._check_sync(stat, repo_dir_path)
        if os.path.exists(repo_dir_path):
            self._status_summary(stat, repo_dir_path)

    def verbose_status(self, repo_dir_path):
        """Display the raw repo status to the user.

        """
        if os.path.exists(repo_dir_path):
            self._status_verbose(repo_dir_path)

    # ----------------------------------------------------------------
    #
    # Internal work functions
    #
    # ----------------------------------------------------------------
    def _clone_repo(self, base_dir_path, repo_dir_name):
        """Prepare to execute the clone by managing directory location
        """
        cwd = os.getcwd()
        os.chdir(base_dir_path)
        self._git_clone(self._url, repo_dir_name)
        os.chdir(cwd)

    @staticmethod
    def _current_ref_from_branch_command(git_output):
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

    def _check_sync(self, stat, repo_dir_path):
        """Determine whether a git repository is in-sync with the model
        description.

        Because repos can have multiple remotes, the only criteria is
        whether the branch or tag is the same.

        """
        if not os.path.exists(repo_dir_path):
            # NOTE(bja, 2017-10) condition should have been determined
            # by _Source() object and should never be here!
            stat.sync_state = ExternalStatus.STATUS_ERROR
        else:
            git_dir = os.path.join(repo_dir_path, '.git')
            if not os.path.exists(git_dir):
                # NOTE(bja, 2017-10) directory exists, but no git repo
                # info.... Can't test with subprocess git command
                # because git will move up directory tree until it
                # finds the parent repo git dir!
                stat.sync_state = ExternalStatus.UNKNOWN
            else:
                cwd = os.getcwd()
                os.chdir(repo_dir_path)
                git_output = self._git_branch()
                ref = self._current_ref_from_branch_command(git_output)
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

    def _determine_remote_name(self):
        """Return the remote name.

        Note that this is for the *future* repo url and branch, not
        the current working copy!

        """
        git_output = self._git_remote_verbose()
        git_output = git_output.splitlines()
        remote_name = ''
        for line in git_output:
            if self._url in line:
                data = line.split()
                remote_name = data[0].strip()
        return remote_name

    def _create_remote_name(self):
        """The url specified in the externals description file was not known
        to git. We need to add it, which means adding a unique and
        safe name....

        The assigned name needs to be safe for git to use, e.g. can't
        look like a path 'foo/bar' and work with both remote and local paths.

        Remote paths include but are not limited to: git, ssh, https,
        github, gitlab, bitbucket, custom server, etc.

        Local paths can be relative or absolute. They may contain
        shell variables, e.g. ${REPO_ROOT}/repo_name, or username
        expansion, i.e. ~/ or ~someuser/.

        Relative paths must be at least one layer of redirection, i.e.
        container/../ext_repo, but may be many layers deep, e.g.
        container/../../../../../ext_repo

        NOTE(bja, 2017-11)

            The base name below may not be unique, for example if the
            user has local paths like:

            /path/to/my/repos/nice_repo
            /path/to/other/repos/nice_repo

            But the current implementation should cover most common
            use cases for remotes and still provide usable names.

        """
        url = copy.deepcopy(self._url)
        if is_remote_url(url):
            url = split_remote_url(url)
        else:
            url = expand_local_url(url, self._name)
        print(url)
        url = url.split('/')
        print(url)
        repo_name = url[-1]
        base_name = url[-2]
        # repo name should nominally already be something that git can
        # deal with. We need to remove other possibly troublesome
        # punctuation, e.g. /, $, from the base name.
        unsafe_characters = '!@#$%^&*()[]{}\\/,;~'
        for unsafe in unsafe_characters:
            base_name = base_name.replace(unsafe, '')
        remote_name = "{0}_{1}".format(base_name, repo_name)
        return remote_name

    def _checkout_external_ref(self, repo_dir):
        cwd = os.getcwd()
        os.chdir(repo_dir)
        remote_name = self._determine_remote_name()
        if not remote_name:
            remote_name = self._create_remote_name()
            self._git_remote_add(remote_name, self._url)
        self._git_fetch(remote_name)
        if self._tag:
            ref = self._tag
        else:
            ref = '{0}/{1}'.format(remote_name, self._branch)
        self._git_checkout_ref(ref)
        os.chdir(cwd)

    def _status_summary(self, stat, repo_dir_path):
        """Determine the clean/dirty status of a git repository

        """
        cwd = os.getcwd()
        os.chdir(repo_dir_path)
        git_output = self._git_status_porcelain_v1z()
        os.chdir(cwd)
        is_dirty = self._status_v1z_is_dirty(git_output)
        if is_dirty:
            stat.clean_state = ExternalStatus.DIRTY
        else:
            stat.clean_state = ExternalStatus.STATUS_OK

    def _status_verbose(self, repo_dir_path):
        """Display raw git status output to the user

        """
        cwd = os.getcwd()
        os.chdir(repo_dir_path)
        git_output = self._git_status_verbose()
        os.chdir(cwd)
        log_process_output(git_output)
        print(git_output)

    @staticmethod
    def _status_v1z_is_dirty(git_output):
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
        command on a clean checkout, and not some error
        condition... Could alse use 'git diff --quiet'.

        """
        is_dirty = False
        if git_output:
            is_dirty = True
        return is_dirty

    # ----------------------------------------------------------------
    #
    # system call to git for information gathering
    #
    # ----------------------------------------------------------------
    @staticmethod
    def _git_branch():
        """Run git branch to obtain repository information
        """
        cmd = ['git', 'branch']
        git_output = check_output(cmd)
        return git_output

    @staticmethod
    def _git_status_porcelain_v1z():
        """Run git status to obtain repository information.

        The machine parable format that is guarenteed not to change
        between git versions or *user configuration*.

        """
        cmd = ['git', 'status', '--porcelain', '-z']
        git_output = check_output(cmd)
        return git_output

    @staticmethod
    def _git_status_verbose():
        """Run the git status command to obtain repository information.
        """
        cmd = ['git', 'status']
        git_output = check_output(cmd)
        return git_output

    @staticmethod
    def _git_remote_verbose():
        """Run the git remote command to obtain repository information.
        """
        cmd = ['git', 'remote', '--verbose']
        git_output = check_output(cmd)
        return git_output

    # ----------------------------------------------------------------
    #
    # system call to git for sideffects modifying the working tree
    #
    # ----------------------------------------------------------------
    @staticmethod
    def _git_clone(url, repo_dir_name):
        """Run git clone for the side effect of creating a repository.
        """
        cmd = ['git', 'clone', url, repo_dir_name]
        execute_subprocess(cmd)

    @staticmethod
    def _git_remote_add(name, url):
        """Run the git remote command to for the side effect of adding a remote
        """
        cmd = ['git', 'remote', 'add', name, url]
        execute_subprocess(cmd)

    @staticmethod
    def _git_fetch(remote_name):
        """Run the git fetch command to for the side effect of updating the repo
        """
        cmd = ['git', 'fetch', remote_name]
        execute_subprocess(cmd)

    @staticmethod
    def _git_checkout_ref(ref):
        """Run the git checkout command to for the side effect of updating the repo

        Param: ref is a reference to a local or remote object in the
        form 'origin/my_feature', or 'tag1'.

        """
        cmd = ['git', 'checkout', ref]
        execute_subprocess(cmd)
