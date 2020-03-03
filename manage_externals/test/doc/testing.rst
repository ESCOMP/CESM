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
required to provide lint and code coverage metrics and generate
documentation. The requirements are maintained in the requirements.txt
file, and can be automatically installed into an isolated environment
via Makefile.

Bootstrap requirements:

* python2 - version 2.7.x or later

* python3 - version 3.6 tested other versions may work

* pip and virtualenv for python2 and python3

Note: all make rules can be of the form ``make python=pythonX rule``
or ``make rule`` depending if you want to use the default system
python or specify a specific version.

The Makefile in the test directory has the following rules:

* ``make python=pythonX env`` - create a python virtual environment
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
