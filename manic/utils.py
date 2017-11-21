#!/usr/bin/env python
"""
Common public utilities for manic package

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import logging
import os
import subprocess
import sys


# ---------------------------------------------------------------------
#
# screen and logging output
#
# ---------------------------------------------------------------------
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


# ---------------------------------------------------------------------
#
# error handling
#
# ---------------------------------------------------------------------
def fatal_error(message):
    """
    Error output function
    """
    logging.error(message)
    raise RuntimeError("{0}ERROR: {1}".format(os.linesep, message))


# ---------------------------------------------------------------------
#
# Data conversion / manipulation
#
# ---------------------------------------------------------------------
def str_to_bool(bool_str):
    """Convert a sting representation of as boolean into a true boolean.

    Conversion should be case insensitive.
    """
    value = None
    str_lower = bool_str.lower()
    if (str_lower == 'true') or (str_lower == 't'):
        value = True
    elif (str_lower == 'false') or (str_lower == 'f'):
        value = False
    if value is None:
        msg = ('ERROR: invalid boolean string value "{0}". '
               'Must be "true" or "false"'.format(bool_str))
        fatal_error(msg)
    return value


# ---------------------------------------------------------------------
#
# subprocess
#
# ---------------------------------------------------------------------
def check_output(commands):
    """
    Wrapper around subprocess.check_output to handle common exceptions.
    check_output runs a command with arguments and returns its output.
    On successful completion, check_output returns the command's output.
    """
    msg = 'In directory: {0}\ncheck_output running command:'.format(
        os.getcwd())
    logging.info(msg)
    logging.info(commands)
    try:
        output = subprocess.check_output(commands)
        output = output.decode('ascii')
        log_process_output(output)
    except OSError as error:
        printlog('Execution of "{0}" failed: {1}'.format(
            (' '.join(commands)), error), file=sys.stderr)
    except ValueError as error:
        printlog('ValueError in "{0}": {1}'.format(
            (' '.join(commands)), error), file=sys.stderr)
        output = None
    except subprocess.CalledProcessError as error:
        printlog('CalledProcessError in "{0}": {1}'.format(
            (' '.join(commands)), error), file=sys.stderr)
        output = None

    return output


def execute_subprocess(commands, status_to_caller=False):
    """Wrapper around subprocess.check_output to handle common
    exceptions.

    check_output runs a command with arguments and waits
    for it to complete.

    check_output raises an exception on a nonzero return code.  if
    status_to_caller is true, execute_subprocess returns the subprocess
    return code, otherwise execute_subprocess treats non-zero return
    status as an error and raises an exception.

    """
    msg = 'In directory: {0}\nexecute_subprocess running command:'.format(
        os.getcwd())
    logging.info(msg)
    logging.info(commands)
    status = -1
    try:
        logging.info(' '.join(commands))
        output = subprocess.check_output(commands, stderr=subprocess.STDOUT,
                                         universal_newlines=True)
        log_process_output(output)
        status = 0
    except OSError as error:
        msg = 'Execution of "{0}" failed'.format(
            ' '.join(commands))
        logging.error(error)
        fatal_error(msg)
    except ValueError as error:
        msg = 'ValueError in "{0}"'.format(
            ' '.join(commands))
        logging.error(error)
        fatal_error(msg)
    except subprocess.CalledProcessError as error:
        msg = 'CalledProcessError in "{0}"'.format(
            ' '.join(commands))
        logging.error(error)
        status_msg = 'Returned : {0}'.format(error.returncode)
        logging.error(status_msg)
        log_process_output(error.output)
        if not status_to_caller:
            fatal_error(msg)
        status = error.returncode
    return status
