"""

FIXME(bja, 2017-11) Source and SourceTree have a circular dependancy!
"""

import errno
import logging
import os

from .globals import EMPTY_STR
from .model_description import ModelDescription, read_model_description_file
from .repository_factory import create_repository
from .externalstatus import ExternalStatus
from .utils import fatal_error, printlog


class _Source(object):
    """
    _Source represents a <source> object in a <config_sourcetree>
    """

    def __init__(self, root_dir, name, source):
        """Parse an XML node for a <source> tag

        Input:

            root_dir : string - the root directory path where
            'local_path' is relative to.

            name : string - name of the source object. may or may not
            correspond to something in the path.

            source : dict - source ModelDescription object

        """
        self._name = name
        self._repo = None
        self._externals = EMPTY_STR
        self._externals_sourcetree = None
        # Parse the sub-elements

        # _path : local path relative to the containing source tree
        self._local_path = source[ModelDescription.PATH]
        # _repo_dir : full repository directory
        repo_dir = os.path.join(root_dir, self._local_path)
        self._repo_dir_path = os.path.abspath(repo_dir)
        # _base_dir : base directory *containing* the repository
        self._base_dir_path = os.path.dirname(self._repo_dir_path)
        # repo_dir_name : base_dir_path + repo_dir_name = rep_dir_path
        self._repo_dir_name = os.path.basename(self._repo_dir_path)
        assert(os.path.join(self._base_dir_path, self._repo_dir_name)
               == self._repo_dir_path)

        self._required = source[ModelDescription.REQUIRED]
        self._externals = source[ModelDescription.EXTERNALS]
        if self._externals:
            self._create_externals_sourcetree()
        repo = create_repository(name, source[ModelDescription.REPO])
        if repo:
            self._repo = repo

    def get_name(self):
        """
        Return the source object's name
        """
        return self._name

    def get_local_path(self):
        """
        Return the source object's path
        """
        return self._local_path

    def status(self):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        If load_all is True, also load all of the the sources sub-sources.
        """

        stat = ExternalStatus()
        stat.path = self.get_local_path()
        if not self._required:
            stat.source_type = ExternalStatus.OPTIONAL
        elif self._local_path == '.':
            # '.' paths are standalone component directories that are
            # not managed by checkout_externals.
            stat.source_type = ExternalStatus.STANDALONE
        else:
            # managed by checkout_externals
            stat.source_type = ExternalStatus.MANAGED

        ext_stats = {}

        if not os.path.exists(self._repo_dir_path):
            stat.sync_state = ExternalStatus.EMPTY
            msg = ('status check: repository directory for "{0}" does not '
                   'exist.'.format(self._name))
            logging.info(msg)
        else:
            if self._repo:
                self._repo.status(stat, self._repo_dir_path)

            if self._externals and self._externals_sourcetree:
                # we expect externals and they exist
                cwd = os.getcwd()
                # SourceTree expecteds to be called from the correct
                # root directory.
                os.chdir(self._repo_dir_path)
                ext_stats = self._externals_sourcetree.status(self._local_path)
                os.chdir(cwd)

        all_stats = {}
        # don't add the root component because we don't manage it
        # and can't provide useful info about it.
        if self._local_path != '.':
            # store the stats under tha local_path, not comp name so
            # it will be sorted correctly
            all_stats[stat.path] = stat

        if ext_stats:
            all_stats.update(ext_stats)

        return all_stats

    def verbose_status(self):
        """Display the verbose status to the user. This is just the raw output
        from the repository 'status' command.

        """
        if not os.path.exists(self._repo_dir_path):
            msg = ('status check: repository directory for "{0}" does not '
                   'exist!'.format(self._name))
            logging.info(msg)
        else:
            cwd = os.getcwd()
            os.chdir(self._repo_dir_path)
            if self._repo:
                self._repo.verbose_status(self._repo_dir_path)
            os.chdir(cwd)

    def checkout(self, load_all):
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

        if self._repo:
            self._repo.checkout(self._base_dir_path, self._repo_dir_name)

        if self._externals:
            if not self._externals_sourcetree:
                self._create_externals_sourcetree()
            self._externals_sourcetree.checkout(load_all)

    def _create_externals_sourcetree(self):
        """
        """
        if not os.path.exists(self._repo_dir_path):
            # NOTE(bja, 2017-10) repository has not been checked out
            # yet, can't process the externals file. Assume we are
            # checking status before code is checkoud out and this
            # will be handled correctly later.
            return

        cwd = os.getcwd()
        os.chdir(self._repo_dir_path)
        if not os.path.exists(self._externals):
            # NOTE(bja, 2017-10) this check is redundent with the one
            # in read_model_description_file!
            msg = ('External model description file "{0}" '
                   'does not exist! In directory: {1}'.format(
                       self._externals, self._repo_dir_path))
            fatal_error(msg)

        externals_root = self._repo_dir_path
        model_format, model_data = read_model_description_file(
            externals_root, self._externals)
        externals = ModelDescription(model_format, model_data)
        self._externals_sourcetree = SourceTree(externals_root, externals)
        os.chdir(cwd)


class SourceTree(object):
    """
    SourceTree represents a <config_sourcetree> object
    """

    def __init__(self, root_dir, model):
        """
        Parse a model file into a SourceTree object
        """
        self._root_dir = os.path.abspath(root_dir)
        self._all_components = {}
        self._required_compnames = []
        for comp in model:
            src = _Source(self._root_dir, comp, model[comp])
            self._all_components[comp] = src
            if model[comp][ModelDescription.REQUIRED]:
                self._required_compnames.append(comp)

    def status(self, relative_path_base='.'):
        """Report the status components

        FIXME(bja, 2017-10) what do we do about situations where the
        user checked out the optional components, but didn't add
        optional for running status? What do we do where the user
        didn't add optional to the checkout but did add it to the
        status. -- For now, we run status on all components, and try
        to do the right thing based on the results....

        """
        load_comps = self._all_components.keys()

        summary = {}
        for comp in load_comps:
            printlog('{0}, '.format(comp), end='')
            stat = self._all_components[comp].status()
            for comp in stat.keys():
                # check if we need to append the relative_path_base to
                # the path so it will be sorted in the correct order.
                if not stat[comp].path.startswith(relative_path_base):
                    stat[comp].path = os.path.join(relative_path_base,
                                                   stat[comp].path)
                    # store under key = updated path, and delete the
                    # old key.
                    comp_stat = stat[comp]
                    del stat[comp]
                    stat[comp_stat.path] = comp_stat
            summary.update(stat)

        return summary

    def verbose_status(self):
        """Display verbose status to the user. This is just the raw output of
        the git and svn status commands.

        """
        load_comps = self._all_components.keys()
        for comp in load_comps:
            self._all_components[comp].verbose_status()

    def checkout(self, load_all, load_comp=None):
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

        for comp in load_comps:
            printlog('{0}, '.format(comp), end='')
            self._all_components[comp].checkout(load_all)
