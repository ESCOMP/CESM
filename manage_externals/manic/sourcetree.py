"""

FIXME(bja, 2017-11) External and SourceTree have a circular dependancy!
"""

import errno
import logging
import os

from .externals_description import ExternalsDescription
from .externals_description import read_externals_description_file
from .externals_description import create_externals_description
from .repository_factory import create_repository
from .repository_git import GitRepository
from .externals_status import ExternalStatus
from .utils import fatal_error, printlog
from .global_constants import EMPTY_STR, LOCAL_PATH_INDICATOR
from .global_constants import VERBOSITY_VERBOSE

class _External(object):
    """
    A single component hosted in an external repository (and any children).
    """

    # pylint: disable=R0902

    def __init__(self, root_dir, name, ext_description, svn_ignore_ancestry):
        """Parse an external description file into a dictionary of externals.

        Input:

            root_dir : string - the root directory path where
            'local_path' is relative to.

            name : string - name of the ext_description object. may or may not
            correspond to something in the path.

            ext_description : dict - source ExternalsDescription object

            svn_ignore_ancestry : bool - use --ignore-externals with svn switch

        """
        self._name = name
        self._repo = None  # Repository object.

        # Subcomponent externals file and data object, if any.
        self._externals_path = EMPTY_STR  # Can also be "none"
        self._externals_sourcetree = None
        
        self._stat = None  # Populated in status()
        self._sparse = None
        # Parse the sub-elements

        # _local_path : local path relative to the containing source tree, e.g.
        # "components/mom"
        self._local_path = ext_description[ExternalsDescription.PATH]
        # _repo_dir_path : full repository directory, e.g.
        # "<root_dir>/components/mom"
        repo_dir = os.path.join(root_dir, self._local_path)
        self._repo_dir_path = os.path.abspath(repo_dir)
        # _base_dir_path : base directory *containing* the repository, e.g.
        # "<root_dir>/components"
        self._base_dir_path = os.path.dirname(self._repo_dir_path)
        # _repo_dir_name : base_dir_path + repo_dir_name = rep_dir_path
        # e.g., "mom"
        self._repo_dir_name = os.path.basename(self._repo_dir_path)
        assert(os.path.join(self._base_dir_path, self._repo_dir_name)
               == self._repo_dir_path)

        self._required = ext_description[ExternalsDescription.REQUIRED]

        # Does this component have subcomponents aka an externals config?
        self._externals_path = ext_description[ExternalsDescription.EXTERNALS]
        # Treat a .gitmodules file as a backup externals config
        if not self._externals_path:
            if GitRepository.has_submodules(self._repo_dir_path):
                self._externals_path = ExternalsDescription.GIT_SUBMODULES_FILENAME

        repo = create_repository(
            name, ext_description[ExternalsDescription.REPO],
            svn_ignore_ancestry=svn_ignore_ancestry)
        if repo:
            self._repo = repo

        # Recurse into subcomponents, if any.
        if self._externals_path and (self._externals_path.lower() != 'none'):
            self._create_externals_sourcetree()

    def get_name(self):
        """
        Return the external object's name
        """
        return self._name

    def get_local_path(self):
        """
        Return the external object's path
        """
        return self._local_path

    def status(self, force=False, print_progress=False):
        """
        Returns status of this component and all subcomponents.

        Returns a dict mapping our local path (not component name!) to an
        ExternalStatus dict. Any subcomponents will have their own top-level
        path keys.  Note the return value includes entries for this and all 
        subcomponents regardless of whether they are locally installed or not.

        Side-effect: If self._stat is empty or force is True, calculates _stat.
        """
        calc_stat = force or not self._stat

        if calc_stat:
            self._stat = ExternalStatus()
            self._stat.path = self.get_local_path()
            if not self._required:
                self._stat.source_type = ExternalStatus.OPTIONAL
            elif self._local_path == LOCAL_PATH_INDICATOR:
                # LOCAL_PATH_INDICATOR, '.' paths, are standalone
                # component directories that are not managed by
                # checkout_subexternals.
                self._stat.source_type = ExternalStatus.STANDALONE
            else:
                # managed by checkout_subexternals
                self._stat.source_type = ExternalStatus.MANAGED

        subcomponent_stats = {}
        if not os.path.exists(self._repo_dir_path):
            if calc_stat:
                # No local repository.
                self._stat.sync_state = ExternalStatus.EMPTY
                msg = ('status check: repository directory for "{0}" does not '
                       'exist.'.format(self._name))
                logging.info(msg)
                self._stat.current_version = 'not checked out'
                # NOTE(bja, 2018-01) directory doesn't exist, so we cannot
                # use repo to determine the expected version. We just take
                # a best-guess based on the assumption that only tag or
                # branch should be set, but not both.
                if not self._repo:
                    self._stat.expected_version = 'unknown'
                else:
                    self._stat.expected_version = self._repo.tag() + self._repo.branch()
        else:
            # Merge local repository state (e.g. clean/dirty) into self._stat.
            if calc_stat and self._repo:
                self._repo.status(self._stat, self._repo_dir_path)

            # Status of subcomponents, if any.
            if self._externals_path and self._externals_sourcetree:
                cwd = os.getcwd()
                # SourceTree.status() expects to be called from the correct
                # root directory.
                os.chdir(self._repo_dir_path)
                subcomponent_stats = self._externals_sourcetree.status(self._local_path, force=force, print_progress=print_progress)
                os.chdir(cwd)

        # Merge our status + subcomponent statuses into one return dict keyed
        # by component path.
        all_stats = {}
        # don't add the root component because we don't manage it
        # and can't provide useful info about it.
        if self._local_path != LOCAL_PATH_INDICATOR:
            # store the stats under the local_path, not comp name so
            # it will be sorted correctly
            all_stats[self._stat.path] = self._stat

        if subcomponent_stats:
            all_stats.update(subcomponent_stats)

        return all_stats

    def checkout(self, verbosity):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the external.
        If the repo destination directory does not exist, checkout the correct
        branch or tag.
        Does not check out sub-externals, see checkout_subexternals().
        """
        # Make sure we are in correct location
        if not os.path.exists(self._repo_dir_path):
            # repository directory doesn't exist. Need to check it
            # out, and for that we need the base_dir_path to exist
            try:
                os.makedirs(self._base_dir_path)
            except OSError as error:
                if error.errno != errno.EEXIST:
                    msg = 'Could not create directory "{0}"'.format(
                        self._base_dir_path)
                    fatal_error(msg)

        if not self._stat:
            self.status()
            assert self._stat
            
        if self._stat.source_type != ExternalStatus.STANDALONE:
            if verbosity >= VERBOSITY_VERBOSE:
                # NOTE(bja, 2018-01) probably do not want to pass
                # verbosity in this case, because if (verbosity ==
                # VERBOSITY_DUMP), then the previous status output would
                # also be dumped, adding noise to the output.
                self._stat.log_status_message(VERBOSITY_VERBOSE)

        if self._repo:
            if self._stat.sync_state == ExternalStatus.STATUS_OK:
                # If we're already in sync, avoid showing verbose output
                # from the checkout command, unless the verbosity level
                # is 2 or more.
                checkout_verbosity = verbosity - 1
            else:
                checkout_verbosity = verbosity

            self._repo.checkout(self._base_dir_path, self._repo_dir_name,
                                checkout_verbosity, self.clone_recursive())

    def checkout_subexternals(self, verbosity, load_all):
        """Recursively checkout the sub-externals for this component, if any.

        See load_all documentation in SourceTree.checkout().
        """
        if self.load_externals():
            if self._externals_sourcetree:
                # NOTE(bja, 2018-02): the subtree externals objects
                # were created during initial status check. Updating
                # the external may have changed which sub-externals
                # are needed. We need to delete those objects and
                # re-read the potentially modified externals
                # description file.
                self._externals_sourcetree = None
            self._create_externals_sourcetree()
            self._externals_sourcetree.checkout(verbosity, load_all)

    def load_externals(self):
        'Return True iff an externals file exists (and therefore should be loaded)'
        load_ex = False
        if os.path.exists(self._repo_dir_path):
            if self._externals_path:
                if self._externals_path.lower() != 'none':
                    load_ex = os.path.exists(os.path.join(self._repo_dir_path,
                                                          self._externals_path))

        return load_ex

    def clone_recursive(self):
        'Return True iff any .gitmodules files should be processed'
        # Try recursive .gitmodules unless there is an externals entry
        recursive = not self._externals_path

        return recursive

    def _create_externals_sourcetree(self):
        """
        Note this only creates an object, it doesn't write to the file system.
        """
        if not os.path.exists(self._repo_dir_path):
            # NOTE(bja, 2017-10) repository has not been checked out
            # yet, can't process the externals file. Assume we are
            # checking status before code is checkoud out and this
            # will be handled correctly later.
            return

        cwd = os.getcwd()
        os.chdir(self._repo_dir_path)
        if self._externals_path.lower() == 'none':
            msg = ('Internal: Attempt to create source tree for '
                   'externals = none in {}'.format(self._repo_dir_path))
            fatal_error(msg)

        if not os.path.exists(self._externals_path):
            if GitRepository.has_submodules():
                self._externals_path = ExternalsDescription.GIT_SUBMODULES_FILENAME

        if not os.path.exists(self._externals_path):
            # NOTE(bja, 2017-10) this check is redundent with the one
            # in read_externals_description_file!
            msg = ('External externals description file "{0}" '
                   'does not exist! In directory: {1}'.format(
                       self._externals_path, self._repo_dir_path))
            fatal_error(msg)

        externals_root = self._repo_dir_path
        # model_data is a dict-like object which mirrors the file format.
        model_data = read_externals_description_file(externals_root,
                                                     self._externals_path)
        # ext_description is another dict-like object (see ExternalsDescription)
        ext_description = create_externals_description(model_data,
                                                       parent_repo=self._repo)
        self._externals_sourcetree = SourceTree(externals_root, ext_description)
        os.chdir(cwd)

class SourceTree(object):
    """
    SourceTree represents a group of managed externals
    """

    def __init__(self, root_dir, ext_description, svn_ignore_ancestry=False):
        """
        Build a SourceTree object from an ExternalDescription.
        """
        self._root_dir = os.path.abspath(root_dir)
        self._all_components = {}  # component_name -> _External
        self._required_compnames = []
        for comp in ext_description:
            src = _External(self._root_dir, comp, ext_description[comp],
                            svn_ignore_ancestry)
            self._all_components[comp] = src
            if ext_description[comp][ExternalsDescription.REQUIRED]:
                self._required_compnames.append(comp)

    def status(self, relative_path_base=LOCAL_PATH_INDICATOR,
               force=False, print_progress=False):
        """Return a dictionary of local path->ExternalStatus.

        Notes about the returned dictionary:
          * It is keyed by local path (e.g. 'components/mom'), not by
            component name (e.g. 'mom').
          * It contains top-level keys for all traversed components, whether
            discovered by recursion or top-level.
          * It contains entries for all components regardless of whether they
            are locally installed or not, or required or optional.
x        """
        load_comps = self._all_components.keys()

        summary = {}  # Holds merged statuses from all components.
        for comp in load_comps:
            if print_progress:
                printlog('{0}, '.format(comp), end='')
            stat = self._all_components[comp].status(force=force,
                                                     print_progress=print_progress)

            # Returned status dictionary is keyed by local path; prepend
            # relative_path_base if not already there.
            stat_final = {}
            for name in stat.keys():
                if stat[name].path.startswith(relative_path_base):
                    stat_final[name] = stat[name]
                else:
                    modified_path = os.path.join(relative_path_base,
                                                 stat[name].path)
                    stat_final[modified_path] = stat[name]
                    stat_final[modified_path].path = modified_path
            summary.update(stat_final)

        return summary

    def _find_installed_optional_components(self):
        """Returns a list of installed optional component names, if any."""
        installed_comps = []
        for comp_name, ext in self._all_components.items():
            if comp_name in self._required_compnames:
                continue
            # Note that in practice we expect this status to be cached.
            path_to_stat = ext.status()
            if any(stat.sync_state != ExternalStatus.EMPTY
                   for stat in path_to_stat.values()):
                installed_comps.append(comp_name)
        return installed_comps

    def checkout(self, verbosity, load_all, load_comp=None):
        """
        Checkout or update indicated components into the configured subdirs.

        If load_all is True, checkout all externals (required + optional), recursively.
        If load_all is False and load_comp is set, checkout load_comp (and any required subexternals, plus any optional subexternals that are already checked out, recursively)
        If load_all is False and load_comp is None, checkout all required externals, plus any optionals that are already checked out, recursively.
        """
        if load_all:
            tmp_comps = self._all_components.keys()
        elif load_comp is not None:
            tmp_comps = [load_comp]
        else:
            local_optional_compnames = self._find_installed_optional_components()
            tmp_comps = self._required_compnames + local_optional_compnames
            if local_optional_compnames:
                printlog('Found locally installed optional components: ' +
                         ', '.join(local_optional_compnames))

        if verbosity >= VERBOSITY_VERBOSE:
            printlog('Checking out externals: ')
        else:
            printlog('Checking out externals: ', end='')

        # Sort by path so that if paths are nested the
        # parent repo is checked out first.
        load_comps = sorted(tmp_comps, key=lambda comp: self._all_components[comp].get_local_path())

        # checkout.
        for comp in load_comps:
            if verbosity < VERBOSITY_VERBOSE:
                printlog('{0}, '.format(comp), end='')
            else:
                # verbose output handled by the _External object, just
                # output a newline
                printlog(EMPTY_STR)
            # Does not recurse.
            self._all_components[comp].checkout(verbosity)
            # Recursively check out subexternals, if any.
            self._all_components[comp].checkout_subexternals(verbosity,
                                                             load_all)
        printlog('')
