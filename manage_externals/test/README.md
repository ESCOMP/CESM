# Testing for checkout_externals

## Unit tests

```SH
    cd checkout_externals/test
    make utest
```

## System tests

```SH
    cd checkout_externals/test
    make stest
```

Example to run a single test:
```SH
    cd checkout_externals
    python -m unittest test.test_sys_checkout.TestSysCheckout.test_container_simple_required
```

## Static analysis

checkout_externals is difficult to test thoroughly because it relies
on git and svn, and svn requires a live network connection and
repository. Static analysis will help catch bugs in code paths that
are not being executed, but it requires conforming to community
standards and best practices. autopep8 and pylint should be run
regularly for automatic code formatting and linting.

```SH
    cd checkout_externals/test
    make lint
```

The canonical formatting for the code is whatever autopep8
generates. All issues identified by pylint should be addressed.


## Code coverage

All changes to the code should include maintaining existing tests and
writing new tests for new or changed functionality. To ensure test
coverage, run the code coverage tool:

```SH
    cd checkout_externals/test
    make coverage
    open -a Firefox.app htmlcov/index.html
```


