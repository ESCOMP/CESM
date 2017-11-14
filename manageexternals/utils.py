#!/usr/bin/env python
"""
Common public utilities for manage_externals

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import logging
import os


def log_process_output(output):
    """Log each line of process output at debug level so it can be
    filtered if necessary. By default, output is a single string, and
    logging.debug(output) will only put log info heading on the first
    line. This makes it hard to filter with grep.

    """
    output = output.split('\n')
    for line in output:
        logging.debug(line)


def printlog(msg, **kwargs):
    """Wrapper script around print to ensure that everything printed to
    the screen also gets logged.

    """
    logging.info(msg)
    if kwargs:
        print(msg, **kwargs)
    else:
        print(msg)


def fatal_error(message):
    """
    Error output function
    """
    logging.error(message)
    raise RuntimeError("{0}ERROR: {1}".format(os.linesep, message))
