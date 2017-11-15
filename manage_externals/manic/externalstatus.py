"""ExternalStatus

Class to store status and state information about repositories and
create a string representation.

"""
from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

from .globals import EMPTY_STR
from .utils import printlog


class ExternalStatus(object):
    """Class to represent the status of a given source repository or tree.

    Individual repositories determine their own status in the
    Repository objects. This object is just resposible for storing the
    information and passing it up to a higher level for reporting or
    global decisions.

    There are two states of concern:

    * If the repository is in-sync with the externals description file.

    * If the repostiory working copy is clean and there are no pending
    transactions (e.g. add, remove, rename, untracked files).

    """
    DEFAULT = '-'
    UNKNOWN = '?'
    EMPTY = 'e'
    MODEL_MODIFIED = 'm'
    DIRTY = 'M'

    STATUS_OK = ' '
    STATUS_ERROR = '!'

    # source types
    OPTIONAL = 'o'
    STANDALONE = 's'
    MANAGED = ' '

    def __init__(self):
        self.sync_state = self.DEFAULT
        self.clean_state = self.DEFAULT
        self.source_type = self.DEFAULT
        self.path = EMPTY_STR

    def __str__(self):
        msg = '{sync}{clean}{src_type} {path}'.format(
            sync=self.sync_state, clean=self.clean_state,
            src_type=self.source_type, path=self.path)
        return msg

    def safe_to_update(self):
        """Report if it is safe to update a repository. Safe is defined as:

        * If a repository is empty, it is safe to update.

        * If a repository exists and has a clean working copy state
        with no pending transactions.

        """
        safe_to_update = False
        repo_exists = self.exists()
        if not repo_exists:
            safe_to_update = True
        else:
            # If the repo exists, it must be in ok or modified
            # sync_state. Any other sync_state at this point
            # represents a logic error that should have been handled
            # before now!
            sync_safe = ((self.sync_state == ExternalStatus.STATUS_OK) or
                         (self.sync_state == ExternalStatus.MODEL_MODIFIED))
            if sync_safe:
                # The clean_state must be STATUS_OK to update. Otherwise we
                # are dirty or there was a missed error previously.
                if self.clean_state == ExternalStatus.STATUS_OK:
                    safe_to_update = True
        return safe_to_update

    def exists(self):
        """Determine if the repo exists. This is indicated by:

        * sync_state is not EMPTY

            * if the sync_state is empty, then the valid states for
              clean_state are default, empty or unknown. Anything else
              and there was probably an internal logic error.

        NOTE(bja, 2017-10) For the moment we are considering a
        sync_state of default or unknown to require user intervention,
        but we may want to relax this convention. This is probably a
        result of a network error or internal logic error but more
        testing is needed.

        """
        is_empty = (self.sync_state == ExternalStatus.EMPTY)
        clean_valid = ((self.clean_state == ExternalStatus.DEFAULT) or
                       (self.clean_state == ExternalStatus.EMPTY) or
                       (self.clean_state == ExternalStatus.UNKNOWN))

        if is_empty and clean_valid:
            exists = False
        else:
            exists = True
        return exists


def check_safe_to_update_repos(tree_status, debug):
    """Check if *ALL* repositories are in a safe state to update. We don't
    want to do a partial update of the repositories then die, leaving
    the model in an inconsistent state.

    Note: if there is an update to do, the repositories will by
    definiation be out of synce with the externals description, so we
    can't use that as criteria for updating.

    """
    safe_to_update = True
    for comp in tree_status:
        stat = tree_status[comp]
        if debug:
            printlog('{0} - {1} sync {2} clean {3}'.format(
                comp, stat.safe_to_update(), stat.sync_state,
                stat.clean_state))

        safe_to_update &= stat.safe_to_update()
    return safe_to_update
