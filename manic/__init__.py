"""Public API for the manage_externals library
"""

from manic.utils import printlog, log_process_output, fatal_error
from manic.globals import PPRINTER
from manic.model_description import read_model_description_file
from manic.model_description import create_model_description
from manic.sourcetree import SourceTree
from manic.externalstatus import check_safe_to_update_repos

__all__ = ['PPRINTER',
           'printlog', 'log_process_output', 'fatal_error',
           'read_model_description_file', 'create_model_description',
           'SourceTree',
           ]
