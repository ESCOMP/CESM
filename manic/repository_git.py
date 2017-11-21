"""Class for interacting with git repositories
"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import os
import re
import string

from .global_constants import EMPTY_STR
from .repository import Repository
from .externals_status import ExternalStatus
from .utils import fatal_error, log_process_output
from .utils import execute_subprocess, check_output


class GitRepository(Repository):
    """Class to represent and operate on a repository description.

    For testing purpose, all system calls to git should:

    * be isolated in separate functions with no application logic
      * of the form:
         - cmd = []
         - value = check_output(cmd)
         - return value
      * be static methods (not rely on self)
      * name as git_subcommand_args(user_args)

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

    def _check_dir(self, chkdir, ref):
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
                head = self._git_revparse_head()
                if ref is not None:
                    refchk = self._git_revparse_ref(ref)

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

    def _determine_ref_type(self, ref):
        """
        Determine if 'ref' is a local branch, a remote branch, a tag, or a
        commit.
        Should probably use this command instead:
        git show-ref --verify --quiet refs/heads/<branch-name>
        """
        ref_type = self.GIT_REF_UNKNOWN
        # First check for local branch
        gitout = self._git_branch()
        if gitout is not None:
            branches = [x.lstrip('* ') for x in gitout.splitlines()]
            for branch in branches:
                if branch == ref:
                    ref_type = self.GIT_REF_LOCAL_BRANCH
                    break

        # Next, check for remote branch
        if ref_type == self.GIT_REF_UNKNOWN:
            gitout = self._git_branch_remotes()
            if gitout is not None:
                for branch in gitout.splitlines():
                    match = GitRepository.RE_REMOTEBRANCH.match(branch)
                    if (match is not None) and (match.group(1) == ref):
                        ref_type = self.GIT_REF_REMOTE_BRANCH
                        break

        # Next, check for a tag
        if ref_type == self.GIT_REF_UNKNOWN:
            gitout = self._git_tag()
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

        """
        url = self._url.split('/')
        repo_name = url[-1]
        base_name = url[-2]
        unsafe = '<>:"/\\|?*&$.'
        remove = string.maketrans(unsafe, '_' * len(unsafe))
        base_name = base_name.translate(remove)
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

    def _current_branch_and_hash(self):
        """
        Return the (current branch, sha1 hash) of working copy in wdir
        """
        branch = self._git_revparse_abbrev_head()
        sha_hash = self._git_revparse_head()
        if branch is not None:
            branch = branch.rstrip()

        if sha_hash is not None:
            sha_hash = sha_hash.rstrip()

        return (branch, sha_hash)

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

        self._git_fetch_all_tags()

        ref = ''
        if self._branch:
            ref = self._checkout_branch_command(repo_dir_path)
            self._git_checkout_ref(ref)
        elif self._tag:
            # For now, do a hail mary and hope tag can be checked out
            ref = self._tag
            self._git_checkout_ref(ref)
        else:
            msg = "DEV_ERROR: in git repo. Shouldn't be here!"
            fatal_error(msg)

        os.chdir(cwd)

    def _checkout_branch_command(self, repo_dir_path):
        """Construct the command for checking out the specified branch
        """
        ref = ''
        curr_branch = self._git_branch()
        ref_type = self._determine_ref_type(self._branch)
        if ref_type == self.GIT_REF_REMOTE_BRANCH:
            ref = 'origin/' + self._branch
        elif ref_type == self.GIT_REF_LOCAL_BRANCH:
            if curr_branch != self._branch:
                if not self._working_dir_clean(repo_dir_path):
                    msg = ('Working directory "{0}" not clean, '
                           'aborting'.format(repo_dir_path))
                    fatal_error(msg)
                else:
                    ref = self._branch
        if not ref:
            msg = ('Unable to determine ref to checkout out for '
                   'branch, "{0}"'.format(self._branch))
            fatal_error(msg)
        return ref

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

    def _working_dir_clean(self, wdir):
        """
        Return True if wdir is clean or False if there are modifications
        """
        mycurrdir = os.path.abspath('.')
        os.chdir(wdir)
        retcode = self._git_diff_quiet()
        os.chdir(mycurrdir)
        return retcode == 0

    # ----------------------------------------------------------------
    #
    # system call to git for information gathering
    #
    # ----------------------------------------------------------------
    @staticmethod
    def _git_diff_quiet():
        """Run git diff to obtain repository information
        """
        cmd = ['git', 'diff', '--quiet', '--exit-code']
        retcode = execute_subprocess(cmd, status_to_caller=True)
        return retcode

    @staticmethod
    def _git_revparse_head():
        """Run git ref-parse to obtain repository information
        """
        cmd = ['git', 'rev-parse', 'HEAD']
        git_hash = check_output(cmd)
        return git_hash

    @staticmethod
    def _git_revparse_abbrev_head():
        """Run git ref-parse to obtain repository information
        """
        cmd = ['git', 'rev-parse', '--abbrev-ref', 'HEAD']
        branch_name = check_output(cmd)
        return branch_name

    @staticmethod
    def _git_revparse_ref(ref):
        """Run git ref-parse to obtain repository information
        """
        cmd = ['git', 'rev-parse', ref]
        ref = check_output(cmd)
        return ref

    @staticmethod
    def _git_branch():
        """Run git branch to obtain repository information
        """
        cmd = ['git', 'branch']
        git_output = check_output(cmd)
        return git_output

    @staticmethod
    def _git_branch_remotes():
        """Run git branch to obtain repository information
        """
        cmd = ['git', 'branch', '--remotes']
        git_output = check_output(cmd)
        return git_output

    @staticmethod
    def _git_tag():
        """Run git tag to obtain repository information
        """
        cmd = ['git', 'tag']
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
    def _git_fetch_all_tags():
        """Run the git fetch command to for the side effect of updating the repo
        """
        cmd = ['git', 'fetch', '--all', '--tags']
        execute_subprocess(cmd)

    @staticmethod
    def _git_checkout_ref(ref):
        """Run the git checkout command to for the side effect of updating the repo

        Param: ref is a reference to a local or remote object in the
        form 'origin/my_feature', or 'tag1'.

        """
        cmd = ['git', 'checkout', ref]
        execute_subprocess(cmd)

    @staticmethod
    def _git_checkout_track_remote_ref(remote_ref):
        """Run the git checkout command to for the side effect of updating the repo

        Param: remote_ref is a reference to a remote in the form
        'remote/ref', e.g. 'origin/my_feature'

        """
        cmd = ['git', 'checkout', '--track', remote_ref]
        execute_subprocess(cmd)
