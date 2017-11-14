"""Public API for the manage_externals library
"""

from manageexternals.utils import printlog, log_process_output, fatal_error
from manageexternals.globals import EMPTY_STR, PPRINTER
from manageexternals.model_description import read_model_description_file, ModelDescription
from manageexternals.sourcetree import SourceTree
from manageexternals.externalstatus import check_safe_to_update_repos

__all__ = ['PPRINTER',
           'printlog', 'log_process_output', 'fatal_error',
           'read_model_description_file', 'ModelDescription',
           'SourceTree',
           ]
