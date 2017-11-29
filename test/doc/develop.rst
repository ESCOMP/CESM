Developer Guidelines
====================

The manage externals utilities are a light weight replacement for svn
externals that will work with git repositories pulling in a mixture of
git and svn dependencies.

Given an externals description and a working copy:

* *checkout_externals* attempts to make the working copy agree with the
  externals description

* *generate_externals* attempts to make the externals description agree
  with the working copy.

For these operations utilities should:

* consistently across git and svn

* operate simply with minimal user complexity

* robustly across a wide range of repository states

* provide explicit error messages when a problem occurs

* leave the working copy in a valid state
  
The utilities in manage externals are **NOT** generic wrappers around
revision control operations or a replacement for common tasks. Users
are expected to:

* create branches prior to starting development
  
* add remotes and push changes

* create tags
  
* delete branches

These types of tasks are often highly workflow dependent, e.g. branch
naming conventions may vary between repositories, have the potential
to destroy user data, introduce significant code complexit and 'edge
cases' that are extremely difficult to detect and test, and often
require subtle decision making, especially if a problem occurs.

Users who want to automate these types are encouraged to create their
own tools. The externals description files are explicitly versioned
and the internal APIs are intended to be stable for these purposes.

Core Design Principles
-----------------------

1. Users can, and are actively encouraged to, modify the externals
   directories using revision control outside of manage_externals
   tools. You can't make any assumptions about the state of the
   working copy. Examples: adding a remote, creating a branch,
   switching to a branch, deleting the directory entirely.
      
2. Give that the user can do anything, the manage externals library
   can not preserve state between calls. The only information it can
   rely on is what it expectes based on the content of the externals
   description file, and what the actual state of the directory tree
   is.

3. Do *not* do anything that will possibly destroy user data!

   a. Do not remove files from the file system. We are operating on
      user supplied input. If you don't call 'rm', you can't
      accidentally remove the user's data. Thinking of calling
      ``shutil.rmtree(user_input)``? What if the user accidentally
      specified user_input such that it resolves to their home
      directory.... Yeah. Don't go there.

   b. Rely on git and svn to do their job as much as possible. Don't
      duplicate functionality. Examples:

      i. We require the working copies to be 'clean' as reported by
         ``git status`` and ``svn status``. What if there are misc
         editor files floating around that prevent an update? Use the
         git and svn ignore functionality so they are not
         reported. Don't try to remove them from manage_externals or
         determine if they are 'safe' to ignore.

      ii. There are often multiple ways to obtain a particular piece
          of information from git. Scraping screen output is brittle
          and generally not considered a stable API across different
          versions of git. Given a choice between:
          
            1. high level git command that produces a bunch of output
               that must be processed.

            2. a lower level git 'plumbing' command that processes a
               specific request and returns a sucess/failure status.

           We always prefer the latter. It almost always involves
           writing and maintaining less code and is more likely to be
           stable.


4. Backward compatibility is critical. We have *nested*
   repositories. They are trivially easy to change versions. They may
   have very different versions of the top level manage_externals. The
   ability to read and work with old model description files is
   critical to avoid problems for users. We also have automated tools
   (testdb) that must generate and read external description
   files. Backward compatibility will make staging changes vastly
   simpler.
   
Model Users
-----------

Consider the needs of the following model userswhen developing manage_externals:

* Users who will checkout the code once, and never change versions.

* Users who will checkout the code once, then work for several years,
  never updating. before trying to update or request integration.

* Users develope code but do not use revision control beyond the
  initial checkout. If they have modified or untracked files in the
  repo, they may be irreplacable. Don't destroy user data.

* Intermediate users who are working with multiple repos or branches
  on a regular basis. They may only use manage_externals weekly or
  monthly. Keep the user interface and documentation simple and
  explicit. The more command line options they have to remember or
  look up, the more frustrated they git.
  
* Software engineers who use the tools multiple times a day. It should
  get out of their way.

Repositories
------------

There are three basic types of repositories that must be considered:

* container repositories - repositories that are always top level
  repositories, and have a group of externals that must be managed.

* simple repositories - repositories that are externals to another
  repository, and do not have any of their own externals that will be
  managed.

* mixed use repositories - repositories that can act as a top level
  container repository or as an external to a top level
  container. They may also have their own sub-externals that are
  required. They may have different externals needs depening on
  whether they are top level or not.

Repositories must be able to checkout and switch to both branches and
tags.

Development
===========

The functionality to manage externals is broken into a library of core
functionality and applications built with the library.

The core library is called 'manic', pseduo-homophone of (man)age
(ex)ternals that is: short, pronounceable and spell-checkable. It is
also no more or less meaningful to an unfamiliar user than a random
jumble of letters forming an acronym.

The core architecture of manic is:

* externals description - an abstract description on an external,
  including of how to obtain it, where to obtain it, where it goes in
  the working tree.

* externals - the software object representing an external.
  
* source trees - collection of externals
  
* repository wrappers - object oriented wrappers around repository
  operations. So the higher level management of the soure tree and
  external does not have to be concerned with how a particular
  external is obtained and managed.
  
Testing
=======

The manage_externals package has an automated test suite. All pull
requests are expected to pass 100% of the automated tests, as well as
be pep8 and lint 'clean' and maintain approximately constant (at a
minimum) level of code coverage.

Quick Start
-----------

Do nothing approach
~~~~~~~~~~~~~~~~~~~

When you create a pull request on GitHub, Travis-CI continuous
integration testing will run the test suite in both python2 and
python3. Test results, lint results, and code coverage results are
available online.

Do something approach
~~~~~~~~~~~~~~~~~~~~~

In the test directory, run:

.. code-block:: shell

    make env
    make lint
    make test
    make coverage

 
Automated Testing
-----------------

The manage_externals manic library and executables are developed to be
python2 and python3 compatible using only the standard library. The
test suites meet the same requirements. But additional tools are
required to provide lint and code coverage metrics. The requirements
are maintained in the requirements.txt file, and can be automatically
installed into an isolated environment via Makefile.

Bootstrap requirements:

* python2 - version 2.7.x or later

* python3 - version 3.6 tested other versions may work

* pip and virtualenv for python2 and python3

Note: all make rules can be of the form ``make python=pythonX rule``
or ``make rule`` depending if you want to use the default system
python or specify a specific version.

The Makefile in the test directory has the following rules:

* ``make env`` - create a python virtual environment
  for python2 or python3 and install all required packages. These
  packages are required to run lint or coverage.

* ``make style`` - runs autopep8

* ``make lint`` - runs autopep8 and pylint

* ``make test`` - run the full test suite

* ``make utest`` - run jus the unit tests

* ``make stest`` - run jus the system integration tests

* ``make coverage`` - run the full test suite through the code
  coverage tool and generate an html report.

* ``make readme`` - automatically generate the README files.

* ``make clean`` - remove editor and pyc files

* ``make clobber`` - remove all generated test files, including
  virtual environments, coverage reports, and temporary test
  repository directories.

Unit Tests
----------

Unit tests are probably not 'true unit tests' for the pedantic, but
are pragmatic unit tests. They cover small practicle code blocks:
functions, class methods, and groups of functions and class methods.

System Integration Tests
------------------------

NOTE(bja, 2017-11) The systems integration tests currently do not include svn repositories.

The manage_externals package is extremely tedious and error prone to test manually.

Combinations that must be tested to ensure basic functionality are:

* container repository pulling in simple externals

* container repository pulling in mixed externals with sub-externals.

* mixed repository acting as a container, pulling in simple externals and sub-externals

Automatic system tests are handled the same way manual testing is done:

* clone a test repository

* create an externals description file for the test

* run the executable with the desired args

* check the results

* potentially modify the repo (checkout a different branch)

* rerun and test

* etc

The automated system stores small test repositories in the main repo
by adding them as bare repositories. These repos are cloned via a
subprocess call to git and manipulated during the tests. 
