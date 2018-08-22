"""Class for interacting with git repositories
"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import copy
import os

from .global_constants import EMPTY_STR, LOCAL_PATH_INDICATOR
from .global_constants import VERBOSITY_VERBOSE
from .repository import Repository
from .externals_status import ExternalStatus
from .utils import expand_local_url, split_remote_url, is_remote_url
from .utils import fatal_error, printlog
from .utils import execute_subprocess


class GitRepository(Repository):
    """Class to represent and operate on a repository description.

    For testing purpose, all system calls to git should:

    * be isolated in separate functions with no application logic
      * of the form:
         - cmd = ['git', ...]
         - value = execute_subprocess(cmd, output_to_caller={T|F},
                                      status_to_caller={T|F})
         - return value
      * be static methods (not rely on self)
      * name as _git_subcommand_args(user_args)

    This convention allows easy unit testing of the repository logic
    by mocking the specific calls to return predefined results.

    """

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
    def checkout(self, base_dir_path, repo_dir_name, verbosity):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        repo_dir_path = os.path.join(base_dir_path, repo_dir_name)
        repo_dir_exists = os.path.exists(repo_dir_path)
        if (repo_dir_exists and not os.listdir(
                repo_dir_path)) or not repo_dir_exists:
            self._clone_repo(base_dir_path, repo_dir_name, verbosity)
        self._checkout_ref(repo_dir_path, verbosity)

    def status(self, stat, repo_dir_path):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correct
        branch or tag.
        """
        self._check_sync(stat, repo_dir_path)
        if os.path.exists(repo_dir_path):
            self._status_summary(stat, repo_dir_path)

    # ----------------------------------------------------------------
    #
    # Internal work functions
    #
    # ----------------------------------------------------------------
    def _clone_repo(self, base_dir_path, repo_dir_name, verbosity):
        """Prepare to execute the clone by managing directory location
        """
        cwd = os.getcwd()
        os.chdir(base_dir_path)
        self._git_clone(self._url, repo_dir_name, verbosity)
        os.chdir(cwd)

    def _current_ref(self):
        """Determine the *name* associated with HEAD.

        If we're on a branch, then returns the branch name; otherwise,
        if we're on a tag, then returns the tag name; otherwise, returns
        the current hash. Returns an empty string if no reference can be
        determined (e.g., if we're not actually in a git repository).
        """
        ref_found = False

        # If we're on a branch, then use that as the current ref
        branch_found, branch_name = self._git_current_branch()
        if branch_found:
            current_ref = branch_name
            ref_found = True

        if not ref_found:
            # Otherwise, if we're exactly at a tag, use that as the
            # current ref
            tag_found, tag_name = self._git_current_tag()
            if tag_found:
                current_ref = tag_name
                ref_found = True

        if not ref_found:
            # Otherwise, use current hash as the current ref
            hash_found, hash_name = self._git_current_hash()
            if hash_found:
                current_ref = hash_name
                ref_found = True

        if not ref_found:
            # If we still can't find a ref, return empty string. This
            # can happen if we're not actually in a git repo
            current_ref = ''

        return current_ref

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
                self._check_sync_logic(stat, repo_dir_path)

    def _check_sync_logic(self, stat, repo_dir_path):
        """Compare the underlying hashes of the currently checkout ref and the
        expected ref.

        Output: sets the sync_state as well as the current and
        expected ref in the input status object.

        """
        def compare_refs(current_ref, expected_ref):
            """Compare the current and expected ref.

            """
            if current_ref == expected_ref:
                status = ExternalStatus.STATUS_OK
            else:
                status = ExternalStatus.MODEL_MODIFIED
            return status

        cwd = os.getcwd()
        os.chdir(repo_dir_path)

        # get the full hash of the current commit
        _, current_ref = self._git_current_hash()

        if self._branch:
            if self._url == LOCAL_PATH_INDICATOR:
                expected_ref = self._branch
            else:
                remote_name = self._determine_remote_name()
                if not remote_name:
                    # git doesn't know about this remote. by definition
                    # this is a modified state.
                    expected_ref = "unknown_remote/{0}".format(self._branch)
                else:
                    expected_ref = "{0}/{1}".format(remote_name, self._branch)
        elif self._hash:
            expected_ref = self._hash
        elif self._tag:
            expected_ref = self._tag
        else:
            msg = 'In repo "{0}": none of branch, hash or tag are set'.format(
                self._name)
            fatal_error(msg)

        # record the *names* of the current and expected branches
        stat.current_version = self._current_ref()
        stat.expected_version = copy.deepcopy(expected_ref)

        if current_ref == EMPTY_STR:
            stat.sync_state = ExternalStatus.UNKNOWN
        else:
            # get the underlying hash of the expected ref
            revparse_status, expected_ref_hash = self._git_revparse_commit(
                expected_ref)
            if revparse_status:
                # We failed to get the hash associated with
                # expected_ref. Maybe we should assign this to some special
                # status, but for now we're just calling this out-of-sync to
                # remain consistent with how this worked before.
                stat.sync_state = ExternalStatus.MODEL_MODIFIED
            else:
                # compare the underlying hashes
                stat.sync_state = compare_refs(current_ref, expected_ref_hash)

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
            data = line.strip()
            if not data:
                continue
            data = data.split()
            name = data[0].strip()
            url = data[1].strip()
            if self._url == url:
                remote_name = name
                break
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
        url = url.split('/')
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

    def _checkout_ref(self, repo_dir, verbosity):
        """Checkout the user supplied reference
        """
        # import pdb; pdb.set_trace()
        cwd = os.getcwd()
        os.chdir(repo_dir)
        if self._url.strip() == LOCAL_PATH_INDICATOR:
            self._checkout_local_ref(verbosity)
        else:
            self._checkout_external_ref(verbosity)
        os.chdir(cwd)

    def _checkout_local_ref(self, verbosity):
        """Checkout the reference considering the local repo only. Do not
        fetch any additional remotes or specify the remote when
        checkout out the ref.

        """
        if self._tag:
            ref = self._tag
        elif self._branch:
            ref = self._branch
        else:
            ref = self._hash

        self._check_for_valid_ref(ref)
        self._git_checkout_ref(ref, verbosity)

    def _checkout_external_ref(self, verbosity):
        """Checkout the reference from a remote repository
        """
        if self._tag:
            ref = self._tag
        elif self._branch:
            ref = self._branch
        else:
            ref = self._hash

        remote_name = self._determine_remote_name()
        if not remote_name:
            remote_name = self._create_remote_name()
            self._git_remote_add(remote_name, self._url)
        self._git_fetch(remote_name)

        # NOTE(bja, 2018-03) we need to send seperate ref and remote
        # name to check_for_vaild_ref, but the combined name to
        # checkout_ref!
        self._check_for_valid_ref(ref, remote_name)

        if self._branch:
            ref = '{0}/{1}'.format(remote_name, ref)
        self._git_checkout_ref(ref, verbosity)

    def _check_for_valid_ref(self, ref, remote_name=None):
        """Try some basic sanity checks on the user supplied reference so we
        can provide a more useful error message than calledprocess
        error...

        """
        is_tag = self._ref_is_tag(ref)
        is_branch = self._ref_is_branch(ref, remote_name)
        is_hash = self._ref_is_hash(ref)

        is_valid = is_tag or is_branch or is_hash
        if not is_valid:
            msg = ('In repo "{0}": reference "{1}" does not appear to be a '
                   'valid tag, branch or hash! Please verify the reference '
                   'name (e.g. spelling), is available from: {2} '.format(
                       self._name, ref, self._url))
            fatal_error(msg)

        if is_tag:
            is_unique_tag, msg = self._is_unique_tag(ref, remote_name)
            if not is_unique_tag:
                msg = ('In repo "{0}": tag "{1}" {2}'.format(
                    self._name, self._tag, msg))
                fatal_error(msg)

        return is_valid

    def _is_unique_tag(self, ref, remote_name):
        """Verify that a reference is a valid tag and is unique (not a branch)

        Tags may be tag names, or SHA id's. It is also possible that a
        branch and tag have the some name.

        Note: values returned by git_showref_* and git_revparse are
        shell return codes, which are zero for success, non-zero for
        error!

        """
        is_tag = self._ref_is_tag(ref)
        is_branch = self._ref_is_branch(ref, remote_name)
        is_hash = self._ref_is_hash(ref)

        msg = ''
        is_unique_tag = False
        if is_tag and not is_branch:
            # unique tag
            msg = 'is ok'
            is_unique_tag = True
        elif is_tag and is_branch:
            msg = ('is both a branch and a tag. git may checkout the branch '
                   'instead of the tag depending on your version of git.')
            is_unique_tag = False
        elif not is_tag and is_branch:
            msg = ('is a branch, and not a tag. If you intended to checkout '
                   'a branch, please change the externals description to be '
                   'a branch. If you intended to checkout a tag, it does not '
                   'exist. Please check the name.')
            is_unique_tag = False
        else:  # not is_tag and not is_branch:
            if is_hash:
                # probably a sha1 or HEAD, etc, we call it a tag
                msg = 'is ok'
                is_unique_tag = True
            else:
                # undetermined state.
                msg = ('does not appear to be a valid tag, branch or hash! '
                       'Please check the name and repository.')
                is_unique_tag = False

        return is_unique_tag, msg

    def _ref_is_tag(self, ref):
        """Verify that a reference is a valid tag according to git.

        Note: values returned by git_showref_* and git_revparse are
        shell return codes, which are zero for success, non-zero for
        error!
        """
        is_tag = False
        value = self._git_showref_tag(ref)
        if value == 0:
            is_tag = True
        return is_tag

    def _ref_is_branch(self, ref, remote_name=None):
        """Verify if a ref is any kind of branch (local, tracked remote,
        untracked remote).

        """
        local_branch = False
        remote_branch = False
        if remote_name:
            remote_branch = self._ref_is_remote_branch(ref, remote_name)
        local_branch = self._ref_is_local_branch(ref)

        is_branch = False
        if local_branch or remote_branch:
            is_branch = True
        return is_branch

    def _ref_is_local_branch(self, ref):
        """Verify that a reference is a valid branch according to git.

        show-ref branch returns local branches that have been
        previously checked out. It will not necessarily pick up
        untracked remote branches.

        Note: values returned by git_showref_* and git_revparse are
        shell return codes, which are zero for success, non-zero for
        error!

        """
        is_branch = False
        value = self._git_showref_branch(ref)
        if value == 0:
            is_branch = True
        return is_branch

    def _ref_is_remote_branch(self, ref, remote_name):
        """Verify that a reference is a valid branch according to git.

        show-ref branch returns local branches that have been
        previously checked out. It will not necessarily pick up
        untracked remote branches.

        Note: values returned by git_showref_* and git_revparse are
        shell return codes, which are zero for success, non-zero for
        error!

        """
        is_branch = False
        value = self._git_lsremote_branch(ref, remote_name)
        if value == 0:
            is_branch = True
        return is_branch

    def _ref_is_commit(self, ref):
        """Verify that a reference is a valid commit according to git.

        This could be a tag, branch, sha1 id, HEAD and potentially others...

        Note: values returned by git_showref_* and git_revparse are
        shell return codes, which are zero for success, non-zero for
        error!
        """
        is_commit = False
        value, _ = self._git_revparse_commit(ref)
        if value == 0:
            is_commit = True
        return is_commit

    def _ref_is_hash(self, ref):
        """Verify that a reference is a valid hash according to git.

        Git doesn't seem to provide an exact way to determine if user
        supplied reference is an actual hash. So we verify that the
        ref is a valid commit and return the underlying commit
        hash. Then check that the commit hash begins with the user
        supplied string.

        Note: values returned by git_showref_* and git_revparse are
        shell return codes, which are zero for success, non-zero for
        error!

        """
        is_hash = False
        status, git_output = self._git_revparse_commit(ref)
        if status == 0:
            if git_output.strip().startswith(ref):
                is_hash = True
        return is_hash

    def _status_summary(self, stat, repo_dir_path):
        """Determine the clean/dirty status of a git repository

        """
        cwd = os.getcwd()
        os.chdir(repo_dir_path)
        git_output = self._git_status_porcelain_v1z()
        is_dirty = self._status_v1z_is_dirty(git_output)
        if is_dirty:
            stat.clean_state = ExternalStatus.DIRTY
        else:
            stat.clean_state = ExternalStatus.STATUS_OK

        # Now save the verbose status output incase the user wants to
        # see it.
        stat.status_output = self._git_status_verbose()
        os.chdir(cwd)

    @staticmethod
    def _status_v1z_is_dirty(git_output):
        """Parse the git status output from --porcelain=v1 -z and determine if
        the repo status is clean or dirty. Dirty means:

        * modified files
        * missing files
        * added files
        * removed
        * renamed
        * unmerged

        Whether untracked files are considered depends on how the status
        command was run (i.e., whether it was run with the '-u' option).

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
    def _git_current_hash():
        """Return the full hash of the currently checked-out version.

        Returns a tuple, (hash_found, hash), where hash_found is a
        logical specifying whether a hash was found for HEAD (False
        could mean we're not in a git repository at all). (If hash_found
        is False, then hash is ''.)
        """
        status, git_output = GitRepository._git_revparse_commit("HEAD")
        hash_found = not status
        if not hash_found:
            git_output = ''
        return hash_found, git_output

    @staticmethod
    def _git_current_branch():
        """Determines the name of the current branch.

        Returns a tuple, (branch_found, branch_name), where branch_found
        is a logical specifying whether a branch name was found for
        HEAD. (If branch_found is False, then branch_name is ''.)
        """
        cmd = ['git', 'symbolic-ref', '--short', '-q', 'HEAD']
        status, git_output = execute_subprocess(cmd,
                                                output_to_caller=True,
                                                status_to_caller=True)
        branch_found = not status
        if branch_found:
            git_output = git_output.strip()
        else:
            git_output = ''
        return branch_found, git_output

    @staticmethod
    def _git_current_tag():
        """Determines the name tag corresponding to HEAD (if any).

        Returns a tuple, (tag_found, tag_name), where tag_found is a
        logical specifying whether we found a tag name corresponding to
        HEAD. (If tag_found is False, then tag_name is ''.)
        """
        # git describe --exact-match --tags HEAD
        cmd = ['git', 'describe', '--exact-match', '--tags', 'HEAD']
        status, git_output = execute_subprocess(cmd,
                                                output_to_caller=True,
                                                status_to_caller=True)
        tag_found = not status
        if tag_found:
            git_output = git_output.strip()
        else:
            git_output = ''
        return tag_found, git_output

    @staticmethod
    def _git_showref_tag(ref):
        """Run git show-ref check if the user supplied ref is a tag.

        could also use git rev-parse --quiet --verify tagname^{tag}
        """
        cmd = ['git', 'show-ref', '--quiet', '--verify',
               'refs/tags/{0}'.format(ref), ]
        status = execute_subprocess(cmd, status_to_caller=True)
        return status

    @staticmethod
    def _git_showref_branch(ref):
        """Run git show-ref check if the user supplied ref is a local or
        tracked remote branch.

        """
        cmd = ['git', 'show-ref', '--quiet', '--verify',
               'refs/heads/{0}'.format(ref), ]
        status = execute_subprocess(cmd, status_to_caller=True)
        return status

    @staticmethod
    def _git_lsremote_branch(ref, remote_name):
        """Run git ls-remote to check if the user supplied ref is a remote
        branch that is not being tracked

        """
        cmd = ['git', 'ls-remote', '--exit-code', '--heads',
               remote_name, ref, ]
        status = execute_subprocess(cmd, status_to_caller=True)
        return status

    @staticmethod
    def _git_revparse_commit(ref):
        """Run git rev-parse to detect if a reference is a SHA, HEAD or other
        valid commit.

        """
        cmd = ['git', 'rev-parse', '--quiet', '--verify',
               '{0}^{1}'.format(ref, '{commit}'), ]
        status, git_output = execute_subprocess(cmd, status_to_caller=True,
                                                output_to_caller=True)
        git_output = git_output.strip()
        return status, git_output

    @staticmethod
    def _git_status_porcelain_v1z():
        """Run git status to obtain repository information.

        This is run with '--untracked=no' to ignore untracked files.

        The machine-portable format that is guaranteed not to change
        between git versions or *user configuration*.

        """
        cmd = ['git', 'status', '--untracked-files=no', '--porcelain', '-z']
        git_output = execute_subprocess(cmd, output_to_caller=True)
        return git_output

    @staticmethod
    def _git_status_verbose():
        """Run the git status command to obtain repository information.
        """
        cmd = ['git', 'status']
        git_output = execute_subprocess(cmd, output_to_caller=True)
        return git_output

    @staticmethod
    def _git_remote_verbose():
        """Run the git remote command to obtain repository information.
        """
        cmd = ['git', 'remote', '--verbose']
        git_output = execute_subprocess(cmd, output_to_caller=True)
        return git_output

    # ----------------------------------------------------------------
    #
    # system call to git for sideffects modifying the working tree
    #
    # ----------------------------------------------------------------
    @staticmethod
    def _git_clone(url, repo_dir_name, verbosity):
        """Run git clone for the side effect of creating a repository.
        """
        cmd = ['git', 'clone', '--quiet', url, repo_dir_name]
        if verbosity >= VERBOSITY_VERBOSE:
            printlog('    {0}'.format(' '.join(cmd)))
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
        cmd = ['git', 'fetch', '--quiet', '--tags', remote_name]
        execute_subprocess(cmd)

    @staticmethod
    def _git_checkout_ref(ref, verbosity):
        """Run the git checkout command to for the side effect of updating the repo

        Param: ref is a reference to a local or remote object in the
        form 'origin/my_feature', or 'tag1'.

        """
        cmd = ['git', 'checkout', '--quiet', ref]
        if verbosity >= VERBOSITY_VERBOSE:
            printlog('    {0}'.format(' '.join(cmd)))
        execute_subprocess(cmd)
