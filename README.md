-- AUTOMATICALLY GENERATED FILE. DO NOT EDIT --

-n [![Build Status](https://travis-ci.org/NCAR/manage_externals.svg?branch=master)](https://travis-ci.org/NCAR/manage_externals)
[![Coverage Status](https://coveralls.io/repos/github/NCAR/manage_externals/badge.svg?branch=master)](https://coveralls.io/github/NCAR/manage_externals?branch=master)
```

usage: checkout_externals [-h] [-e [EXTERNALS]] [-o] [-S] [-v] [--backtrace]
                          [-d] [--no-logging]

checkout_externals manages checking out CESM externals from revision control
based on a externals description file. By default only the required
externals are checkout out.

NOTE: checkout_externals *MUST* be run from the root of the source tree.

Running checkout_externals without the '--status' option will always attempt to
synchronize the working copy with the externals description.

optional arguments:
  -h, --help            show this help message and exit
  -e [EXTERNALS], --externals [EXTERNALS]
                        The externals description filename. Default:
                        Externals.cfg.
  -o, --optional        By default only the required externals are checked
                        out. This flag will also checkout the optional
                        externals.
  -S, --status          Output status of the repositories managed by
                        checkout_externals. By default only summary
                        information is provided. Use verbose output to see
                        details.
  -v, --verbose         Output additional information to the screen and log
                        file. This flag can be used up to two times,
                        increasing the verbosity level each time.
  --backtrace           DEVELOPER: show exception backtraces as extra
                        debugging output
  -d, --debug           DEVELOPER: output additional debugging information to
                        the screen and log file.
  --no-logging          DEVELOPER: disable logging.

```
NOTE: checkout_externals *MUST* be run from the root of the source tree it
is managing. For example, if you cloned CLM with:

    $ git clone git@github.com/ncar/clm clm-dev

Then the root of the source tree is /path/to/clm-dev. If you obtained
CLM via a checkout of CESM:

    $ git clone git@github.com/escomp/cesm cesm-dev

and you need to checkout the CLM externals, then the root of the
source tree is /path/to/cesm-dev. Do *NOT* run checkout_externals
from within /path/to/cesm-dev/components/clm.

The root of the source tree will be referred to as `${SRC_ROOT}` below.

# Supported workflows

  * Checkout all required components from the default externals
    description file:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals

  * To update all required components to the current values in the
    externals description file, re-run checkout_externals:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals

    If there are *any* modifications to *any* working copy according
    to the git or svn 'status' command, checkout_externals
    will not update any external repositories. Modifications
    include: modified files, added files, removed files, or missing
    files.

  * Checkout all required components from a user specified externals
    description file:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals --excernals myCESM.xml

  * Status summary of the repositories managed by checkout_externals:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals --status

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
      * e : empty : directory does not exist - checkout_externals has not been run
      * ? : unknown : directory exists but .git or .svn directories are missing

    Column two will be one of these values:
      * M : Modified : modified, added, deleted or missing files
      *   : blank / space : clean
      * - : dash : no meaningful state, for empty repositories

    Column three will be one of these values:
      * o : optional : optionally repository
      *   : blank / space : required repository

  * Detailed git or svn status of the repositories managed by checkout_externals:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals --status --verbose

# Externals description file

  The externals description contains a list of the external
  repositories that are used and their version control locations. Each
  external has:

  * name (string) : component name, e.g. cime, cism, clm, cam, etc.

  * required (boolean) : whether the component is a required checkout

  * local_path (string) : component path *relative* to where
    checkout_externals is called.

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
