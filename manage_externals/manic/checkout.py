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
import sys

from manic.externals_description import create_externals_description
from manic.externals_description import read_externals_description_file
from manic.externals_status import check_safe_to_update_repos
from manic.sourcetree import SourceTree
from manic.utils import printlog
from manic.global_constants import VERSION_SEPERATOR, LOG_FILE_NAME

if sys.hexversion < 0x02070000:
    print(70 * '*')
    print('ERROR: {0} requires python >= 2.7.x. '.format(sys.argv[0]))
    print('It appears that you are running python {0}'.format(
        VERSION_SEPERATOR.join(str(x) for x in sys.version_info[0:3])))
    print(70 * '*')
    sys.exit(1)


# ---------------------------------------------------------------------
#
# User input
#
# ---------------------------------------------------------------------
def commandline_arguments(args=None):
    """Process the command line arguments

    Params: args - optional args. Should only be used during systems
    testing.

    Returns: processed command line arguments
    """
    description = '''
%(prog)s manages checking out CESM externals from revision control
based on a externals description file. By default only the required
externals are checkout out.

NOTE: %(prog)s *MUST* be run from the root of the source tree.

Running %(prog)s without the '--status' option will always attempt to
synchronize the working copy with the externals description.
'''

    epilog = '''
```
NOTE: %(prog)s *MUST* be run from the root of the source tree it
is managing. For example, if you cloned CLM with:

    $ git clone git@github.com/ncar/clm clm-dev

Then the root of the source tree is /path/to/clm-dev. If you obtained
CLM via a checkout of CESM:

    $ git clone git@github.com/escomp/cesm cesm-dev

and you need to checkout the CLM externals, then the root of the
source tree is /path/to/cesm-dev. Do *NOT* run %(prog)s
from within /path/to/cesm-dev/components/clm.

The root of the source tree will be referred to as `${SRC_ROOT}` below.


# Supported workflows

  * Checkout all required components from the default externals
    description file:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/%(prog)s

  * To update all required components to the current values in the
    externals description file, re-run %(prog)s:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/%(prog)s

    If there are *any* modifications to *any* working copy according
    to the git or svn 'status' command, %(prog)s
    will not update any external repositories. Modifications
    include: modified files, added files, removed files, or missing
    files.

  * Checkout all required components from a user specified externals
    description file:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/%(prog)s --excernals myCESM.xml

  * Status summary of the repositories managed by %(prog)s:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/%(prog)s --status

              ./cime
          s   ./components/cism
              ./components/mosart
          e-o ./components/rtm
           M  ./src/fates
          e-o ./tools/PTCLM


    where:
      * column one indicates the status of the repository in relation
        to the externals description file.
      * column two indicates whether the working copy has modified files.
      * column three shows how the repository is managed, optional or required

    Column one will be one of these values:
      * s : out-of-sync : repository is checked out at a different commit
            compared with the externals description
      * e : empty : directory does not exist - %(prog)s has not been run
      * ? : unknown : directory exists but .git or .svn directories are missing

    Column two will be one of these values:
      * M : Modified : modified, added, deleted or missing files
      *   : blank / space : clean
      * - : dash : no meaningful state, for empty repositories

    Column three will be one of these values:
      * o : optional : optionally repository
      *   : blank / space : required repository

  * Detailed git or svn status of the repositories managed by %(prog)s:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/%(prog)s --status --verbose

# Externals description file

  The externals description contains a list of the external
  repositories that are used and their version control locations. Each
  external has:

  * name (string) : component name, e.g. cime, cism, clm, cam, etc.

  * required (boolean) : whether the component is a required checkout

  * local_path (string) : component path *relative* to where
    %(prog)s is called.

  * protoctol (string) : version control protocol that is used to
    manage the component.  Valid values are 'git', 'svn',
    'externals_only'.

    Note: 'externals_only' will only process the external's own
    external description file without trying to manage a repository
    for the component. This is used for retreiving externals for
    standalone components like cam and clm.

  * repo_url (string) : URL for the repository location, examples:
    * https://svn-ccsm-models.cgd.ucar.edu/glc
    * git@github.com:esmci/cime.git
    * /path/to/local/repository

    If a repo url is determined to be a local path (not a network url)
    then user expansion, e.g. ~/, and environment variable expansion,
    e.g. $HOME or $REPO_ROOT, will be performed.

    Relative paths are difficult to get correct, especially for mixed
    use repos like clm. It is advised that local paths expand to
    absolute paths. If relative paths are used, they should be
    relative to one level above local_path. If local path is
    'src/foo', the the relative url should be relative to
    'src'.

  * tag (string) : tag to checkout

    This can also be a git SHA-1

  * branch (string) : branch to checkout

    Note: either tag or branch must be supplied, but not both.

  * externals (string) : relative path to the external's own external
    description file that should also be used. It is *relative* to the
    component local_path. For example, the CESM externals description
    will load clm. CLM has additional externals that must be
    downloaded to be complete. Those additional externals are managed
    from the clm source root by the file pointed to by 'externals'.

'''

    parser = argparse.ArgumentParser(
        description=description, epilog=epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    #
    # user options
    #
    parser.add_argument('-e', '--externals', nargs='?',
                        default='Externals.cfg',
                        help='The externals description filename. '
                        'Default: %(default)s.')

    parser.add_argument('-o', '--optional', action='store_true', default=False,
                        help='By default only the required externals '
                        'are checked out. This flag will also checkout the '
                        'optional externals.')

    parser.add_argument('-S', '--status', action='store_true', default=False,
                        help='Output status of the repositories managed by '
                        '%(prog)s. By default only summary information '
                        'is provided. Use verbose output to see details.')

    parser.add_argument('-v', '--verbose', action='count', default=0,
                        help='Output additional information to '
                        'the screen and log file. This flag can be '
                        'used up to two times, increasing the '
                        'verbosity level each time.')

    #
    # developer options
    #
    parser.add_argument('--backtrace', action='store_true',
                        help='DEVELOPER: show exception backtraces as extra '
                        'debugging output')

    parser.add_argument('-d', '--debug', action='store_true', default=False,
                        help='DEVELOPER: output additional debugging '
                        'information to the screen and log file.')

    parser.add_argument('--no-logging', action='store_true',
                        help='DEVELOPER: disable logging.')

    if args:
        options = parser.parse_args(args)
    else:
        options = parser.parse_args()
    return options


# ---------------------------------------------------------------------
#
# main
#
# ---------------------------------------------------------------------
def main(args):
    """
    Function to call when module is called from the command line.
    Parse externals file and load required repositories or all repositories if
    the --all option is passed.
    """
    if not args.no_logging:
        logging.basicConfig(filename=LOG_FILE_NAME,
                            format='%(levelname)s : %(asctime)s : %(message)s',
                            datefmt='%Y-%m-%d %H:%M:%S',
                            level=logging.DEBUG)

    program_name = os.path.basename(sys.argv[0])
    logging.info('Beginning of %s', program_name)

    load_all = False
    if args.optional:
        load_all = True

    root_dir = os.path.abspath(os.getcwd())
    external_data = read_externals_description_file(root_dir, args.externals)
    external = create_externals_description(external_data)

    source_tree = SourceTree(root_dir, external)
    printlog('Checking status of externals: ', end='')
    tree_status = source_tree.status()
    printlog('')

    if args.status:
        # user requested status-only
        for comp in sorted(tree_status.keys()):
            tree_status[comp].log_status_message(args.verbose)
    else:
        # checkout / update the external repositories.
        safe_to_update = check_safe_to_update_repos(tree_status)
        if not safe_to_update:
            # print status
            for comp in sorted(tree_status.keys()):
                tree_status[comp].log_status_message(args.verbose)
            # exit gracefully
            msg = """The external repositories labeled with 'M' above are not in a clean state.

The following are two options for how to proceed:

(1) Go into each external that is not in a clean state and issue either
    an 'svn status' or a 'git status' command. Either revert or commit
    your changes so that all externals are in a clean state. (Note,
    though, that it is okay to have untracked files in your working
    directory.) Then rerun {program_name}.

(2) Alternatively, you do not have to rely on {program_name}. Instead, you
    can manually update out-of-sync externals (labeled with 's' above)
    as described in the configuration file {config_file}.
""".format(program_name=program_name, config_file=args.externals)

            printlog('-' * 70)
            printlog(msg)
            printlog('-' * 70)
        else:
            source_tree.checkout(args.verbose, load_all)
            printlog('')

    logging.info('%s completed without exceptions.', program_name)
    # NOTE(bja, 2017-11) tree status is used by the systems tests
    return 0, tree_status
