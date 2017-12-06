# Testing for checkout_externals

NOTE: Python2 is the supported runtime environment. Python3 compatibility is
in progress, complicated by the different proposed input methods
(yaml, xml, cfg/ini, json) and their different handling of strings
(unicode vs byte) in python2. Full python3 compatibility will be
possible once the number of possible input formats has been narrowed.

## Setup development environment

Development environments should be setup for python2 and python3:

```SH
    cd checkout_externals/test
    make python=python2 env
    make python=python3 env
```

## Unit tests

Tests should be run for both python2 and python3. It is recommended
that you have seperate terminal windows open python2 and python3
testing to avoid errors activating and deactivating environments.

```SH
    cd checkout_externals/test
    . env_python2/bin/activate
    make utest
    deactivate
```

```SH
    cd checkout_externals/test
    . env_python2/bin/activate
    make utest
    deactivate
```

## System tests

Not yet implemented.

## Static analysis

checkout_externals is difficult to test thoroughly because it relies
on git and svn, and svn requires a live network connection and
repository. Static analysis will help catch bugs in code paths that
are not being executed, but it requires conforming to community
standards and best practices. autopep8 and pylint should be run
regularly for automatic code formatting and linting.

```SH
    cd checkout_externals/test
    . env_python2/bin/activate
    make lint
    deactivate
```

The canonical formatting for the code is whatever autopep8
generates. All issues identified by pylint should be addressed.


## Code coverage

All changes to the code should include maintaining existing tests and
writing new tests for new or changed functionality. To ensure test
coverage, run the code coverage tool:

```SH
    cd checkout_externals/test
    . env_python2/bin/activate
    make coverage
    open -a Firefox.app htmlcov/index.html
    deactivate
```


