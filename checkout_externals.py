#!/usr/bin/env python

"""
Tool to assemble respositories represented in a model-description file.

If loaded as a module (e.g., in a component's buildcpp), it can be used
to check the validity of existing subdirectories and load missing sources.
"""
from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import argparse
import logging
import os
import os.path
import re
import sys
import textwrap
import traceback

if sys.hexversion < 0x02070000:
    print(70 * '*')
    print('ERROR: {0} requires python >= 2.7.x. '.format(sys.argv[0]))
    print('It appears that you are running python {0}'.format(
        '.'.join(str(x) for x in sys.version_info[0:3])))
    print(70 * '*')
    sys.exit(1)

from manic import read_model_description_file, ModelDescription
from manic import SourceTree
from manic import check_safe_to_update_repos
from manic import printlog, PPRINTER

# ---------------------------------------------------------------------
#
# Global variables
#
# ---------------------------------------------------------------------
RE_NAMESPACE = re.compile(r'{[^}]*}')


# ---------------------------------------------------------------------
#
# User input
#
# ---------------------------------------------------------------------
def commandline_arguments():
    """Process the command line arguments
    """
    description = '''
%(prog)s manages checking out CESM externals from revision control
based on a model description file. By default only the required
components of the model are checkout out.

NOTE: %(prog)s *MUST* be run from the root of the source tree.

Running %(prog)s without the '--status' option will always attempt to
synchronize the working copy with the model description.
'''

    epilog = '''
NOTE: %(prog)s *MUST* be run from the root of the source tree it
is managing. For example, if you cloned CLM with:

    $ git clone git@github.com/ncar/clm clm-dev

Then the root of the source tree is /path/to/clm-dev. If you obtained
CLM via an svn checkout of CESM and you need to checkout the CLM
externals, then the root of the source tree for CLM is:

    /path/to/cesm-dev/components/clm

The root of the source tree will be referred to as ${SRC_ROOT} below.


# Supported workflows:

  * Checkout all required components from the default model
    description file:

      $ cd ${SRC_ROOT}
      $ ./checkout_cesm/%(prog)s

  * To update all required components to the current values in the
    model description file, re-run %(prog)s:

      $ cd ${SRC_ROOT}
      $ ./checkout_cesm/%(prog)s

    If there are *any* modifications to *any* working copy according
    to the git or svn 'status' command, %(prog)s
    will not update any repositories in the model. Modifications
    include: modified files, added files, removed files, missing
    files or untracked files,

  * Checkout all required components from a user specified model
    description file:

      $ cd ${SRC_ROOT}
      $ ./checkout_cesm/%(prog)s --model myCESM.xml

  * Status summary of the repositories managed by %(prog)s:

      $ cd ${SRC_ROOT}
      $ ./checkout_cesm/%(prog)s --status

      m   components/cism
       M  src/fates
      e-o components/mosart
          cime
          components/rtm
      e-o tools/PTCLM

    where:
      * column one indicates the status of the repository in relation
        to the model description file.
      * column two indicates whether the working copy has modified files.
      * column three shows how the repository is managed, optional or required

    Colunm one will be one of these values:
      * m : modified : repository is modefied compared to the model description
      * e : empty : directory does not exist - %(prog)s has not been run
      * ? : unknown : directory exists but .git or .svn directories are missing

    Colunm two will be one of these values:
      * M : Modified : untracked, modified, added, deleted or missing files
      *   : blank / space : clean
      * - : dash : no meaningful state, for empty repositories

    Colunm three will be one of these values:
      * o : optional : optionally repository
      *   : blank / space : required repository

  * Detailed git or svn status of the repositories managed by %(prog)s:

      $ cd ${SRC_ROOT}
      $ ./checkout_cesm/%(prog)s --status --verbose

# Model description file:

  The model description contains a list of the model components that
  are used and their version control locations. Each component has:

  * name (string) : component name, e.g. cime, cism, clm, cam, etc.

  * required (boolean) : whether the component is a required checkout

  * local_path (string) : component path *relative* to where
    %(prog)s is called.

  * protoctol (string) : version control protocol that is used to
    manage the component.  Valid values are 'git', 'svn',
    'externals_only'.

    Note: 'externals_only' will only process the externals model
    description file without trying to manage a repository for the
    component. This is used for retreiving externals for standalone
    components like cam and clm.

  * repo_url (string) : URL for the repository location, examples:
    * svn - https://svn-ccsm-models.cgd.ucar.edu/glc
    * git - git@github.com:esmci/cime.git
    * local - /path/to/local/repository

  * tag (string) : tag to checkout

  * branch (string) : branch to checkout

  * externals (string) : relative path to the external model
    description file that should also be used. It is *relative* to the
    component local_path. For example, the CESM model description will
    load clm. CLM has additional externals that must be downloaded to
    be complete. Those additional externals are managed from the clm
    source root by the file pointed to by 'externals'.

'''

    parser = argparse.ArgumentParser(
        description=description, epilog=epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    #
    # user options
    #
    parser.add_argument('-m', '--model', nargs='?', default='CESM.cfg',
                        help='The model description filename. '
                        'Default: %(default)s.')

    parser.add_argument('-o', '--optional', action='store_true', default=False,
                        help='By default only the required model components '
                        'are checked out. This flag will also checkout the '
                        'optional componets of the model.')

    parser.add_argument('-S', '--status', action='store_true', default=False,
                        help='Output status of the repositories managed by '
                        '%(prog)s. By default only summary information '
                        'is provided. Use verbose output to see details.')

    parser.add_argument('-v', '--verbose', action='store_true', default=False,
                        help='Output additional information to '
                        'the screen and log file.')

    #
    # developer options
    #
    parser.add_argument('--backtrace', action='store_true',
                        help='DEVELOPER: show exception backtraces as extra '
                        'debugging output')

    parser.add_argument('-d', '--debug', action='store_true', default=False,
                        help='DEVELOPER: output additional debugging '
                        'information to the screen and log file.')

    options = parser.parse_args()
    return options


# ---------------------------------------------------------------------
#
# main
#
# ---------------------------------------------------------------------
def _main(args):
    """
    Function to call when module is called from the command line.
    Parse model file and load required repositories or all repositories if
    the --all option is passed.
    """
    logging.basicConfig(filename='manage_externals.log',
                        format='%(levelname)s : %(asctime)s : %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S',
                        level=logging.DEBUG)

    logging.info('Begining of checkout_externals')

    load_all = False
    if args.optional:
        load_all = True

    root_dir = os.path.abspath('.')
    model_format, model_data = read_model_description_file(
        root_dir, args.model)
    model = ModelDescription(model_format, model_data)
    if args.debug:
        PPRINTER.pprint(model)

    source_tree = SourceTree(root_dir, model)
    printlog('Checking status of components: ', end='')
    tree_status = source_tree.status()
    printlog('')

    if args.status:
        # user requested status-only
        for comp in sorted(tree_status.iterkeys()):
            msg = str(tree_status[comp])
            printlog(msg)
        if args.verbose:
            # user requested verbose status dump of the git/svn status commands
            source_tree.verbose_status()
    else:
        # checkout / update the model repositories.
        safe_to_update = check_safe_to_update_repos(tree_status, args.debug)
        if not safe_to_update:
            # print status
            for comp in sorted(tree_status.iterkeys()):
                msg = str(tree_status[comp])
                printlog(msg)
            # exit gracefully
            msg = textwrap.fill(
                'Model contains repositories that are not in a clean '
                'state. Please all external repositories are clean '
                'before updating.')
            printlog('-' * 70)
            printlog(msg)
            printlog('-' * 70)
        else:
            printlog('Checkout components: ', end='')
            source_tree.checkout(load_all)
            printlog('')

    logging.info('checkout_externals completed without exceptions.')
    return 0


if __name__ == '__main__':
    ARGS = commandline_arguments()
    try:
        RET_STATUS = _main(ARGS)
        sys.exit(RET_STATUS)
    except Exception as error:  # pylint: disable=broad-except
        printlog(str(error))
        if ARGS.backtrace:
            traceback.print_exc()
        sys.exit(1)
