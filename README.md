-- AUTOMATICALLY GENERATED FILE. DO NOT EDIT --

[![Build Status](https://travis-ci.org/NCAR/manage_externals.svg?branch=master)](https://travis-ci.org/NCAR/manage_externals)

[![Coverage Status](https://coveralls.io/repos/github/NCAR/manage_externals/badge.svg?branch=master)](https://coveralls.io/github/NCAR/manage_externals?branch=master)
```

usage: checkout_externals.py [-h] [-m [MODEL]] [-o] [-S] [-v] [--backtrace]
                             [-d]

checkout_externals.py manages checking out CESM externals from revision control
based on a externals description file. By default only the required
components of the model are checkout out.

NOTE: checkout_externals.py *MUST* be run from the root of the source tree.

Running checkout_externals.py without the '--status' option will always attempt to
synchronize the working copy with the externals description.

optional arguments:
  -h, --help            show this help message and exit
  -m [MODEL], --model [MODEL]
                        The externals description filename. Default: CESM.cfg.
  -o, --optional        By default only the required model components are
                        checked out. This flag will also checkout the optional
                        componets of the model.
  -S, --status          Output status of the repositories managed by
                        checkout_externals.py. By default only summary
                        information is provided. Use verbose output to see
                        details.
  -v, --verbose         Output additional information to the screen and log
                        file.
  --backtrace           DEVELOPER: show exception backtraces as extra
                        debugging output
  -d, --debug           DEVELOPER: output additional debugging information to
                        the screen and log file.

```
NOTE: checkout_externals.py *MUST* be run from the root of the source tree it
is managing. For example, if you cloned CLM with:

    $ git clone git@github.com/ncar/clm clm-dev

Then the root of the source tree is /path/to/clm-dev. If you obtained
CLM via a checkout of CESM:

    $ git clone git@github.com/escomp/cesm cesm-dev

and you need to checkout the CLM externals, then the root of the
source tree is /path/to/cesm-dev. Do *NOT* run checkout_externals.py
from within /path/to/cesm-dev/components/clm.

The root of the source tree will be referred to as `${SRC_ROOT}` below.

# Supported workflows

  * Checkout all required components from the default model
    description file:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals.py

  * To update all required components to the current values in the
    externals description file, re-run checkout_externals.py:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals.py

    If there are *any* modifications to *any* working copy according
    to the git or svn 'status' command, checkout_externals.py
    will not update any repositories in the model. Modifications
    include: modified files, added files, removed files, missing
    files or untracked files,

  * Checkout all required components from a user specified model
    description file:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals.py --model myCESM.xml

  * Status summary of the repositories managed by checkout_externals.py:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals.py --status

              ./cime
          m   ./components/cism
              ./components/mosart
          e-o ./components/rtm
           M  ./src/fates
          e-o ./tools/PTCLM

    where:
      * column one indicates the status of the repository in relation
        to the externals description file.
      * column two indicates whether the working copy has modified files.
      * column three shows how the repository is managed, optional or required

    Colunm one will be one of these values:
      * m : modified : repository is modefied compared to the externals description
      * e : empty : directory does not exist - checkout_externals.py has not been run
      * ? : unknown : directory exists but .git or .svn directories are missing

    Colunm two will be one of these values:
      * M : Modified : untracked, modified, added, deleted or missing files
      *   : blank / space : clean
      * - : dash : no meaningful state, for empty repositories

    Colunm three will be one of these values:
      * o : optional : optionally repository
      *   : blank / space : required repository

  * Detailed git or svn status of the repositories managed by checkout_externals.py:

        $ cd ${SRC_ROOT}
        $ ./manage_externals/checkout_externals.py --status --verbose

# Model description file

  The externals description contains a list of the model components that
  are used and their version control locations. Each component has:

  * name (string) : component name, e.g. cime, cism, clm, cam, etc.

  * required (boolean) : whether the component is a required checkout

  * local_path (string) : component path *relative* to where
    checkout_externals.py is called.

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
    component local_path. For example, the CESM externals description will
    load clm. CLM has additional externals that must be downloaded to
    be complete. Those additional externals are managed from the clm
    source root by the file pointed to by 'externals'.
