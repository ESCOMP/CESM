"""Public API for the manage_externals library
"""

from manic.utils import printlog, log_process_output, fatal_error
from manic.globals import PPRINTER
from manic.externals_description import read_externals_description_file
from manic.externals_description import create_externals_description
from manic.sourcetree import SourceTree
from manic.externalstatus import check_safe_to_update_repos

__all__ = ['PPRINTER',
           'printlog', 'log_process_output', 'fatal_error',
           'read_externals_description_file', 'create_externals_description',
           'SourceTree', 'check_safe_to_update_repos'
           ]
