"""Base class representation of a repository
"""

from .externals_description import ExternalsDescription
from .utils import fatal_error
from .global_constants import EMPTY_STR


class Repository(object):
    """
    Class to represent and operate on a repository description.
    """

    def __init__(self, component_name, repo):
        """
        Parse repo externals description
        """
        self._name = component_name
        self._protocol = repo[ExternalsDescription.PROTOCOL]
        self._tag = repo[ExternalsDescription.TAG]
        self._branch = repo[ExternalsDescription.BRANCH]
        self._url = repo[ExternalsDescription.REPO_URL]

        if self._url is EMPTY_STR:
            fatal_error('repo must have a URL')

        if self._tag is EMPTY_STR and self._branch is EMPTY_STR:
            fatal_error('repo must have either a branch or a tag element')

        if self._tag is not EMPTY_STR and self._branch is not EMPTY_STR:
            fatal_error('repo cannot have both a tag and a branch element')

    def checkout(self, base_dir_path, repo_dir_name, verbosity):  # pylint: disable=unused-argument
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        msg = ('DEV_ERROR: checkout method must be implemented in all '
               'repository classes! {0}'.format(self.__class__.__name__))
        fatal_error(msg)

    def status(self, stat, repo_dir_path):  # pylint: disable=unused-argument
        """Report the status of the repo

        """
        msg = ('DEV_ERROR: status method must be implemented in all '
               'repository classes! {0}'.format(self.__class__.__name__))
        fatal_error(msg)

    def url(self):
        """Public access of repo url.
        """
        return self._url

    def tag(self):
        """Public access of repo tag
        """
        return self._tag

    def branch(self):
        """Public access of repo branch.
        """
        return self._branch
