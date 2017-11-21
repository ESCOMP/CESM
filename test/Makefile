python = not-set

ifneq ($(python), not-set)
PYTHON=$(python)
else
PYTHON=python
endif

# we need the python path to point one level up to access the package
# and executables
PYPATH=PYTHONPATH=..:

# common args for running tests
TEST_ARGS=-m unittest discover --buffer

# auto reformat the code
AUTOPEP8=autopep8
AUTOPEP8_ARGS=--aggressive --in-place 

# run lint
PYLINT=pylint
PYLINT_ARGS=-j 2 --rcfile=.pylint.rc

# code coverage
COVERAGE=coverage
COVERAGE_ARGS=--rcfile=.coveragerc --append

# source files
SRC = \
	../checkout_externals.py \
	../manic/*.py

CHECKOUT_EXE = ../checkout_externals

TEST_DIR = .

README = ../README.md

#
# testing
#
.PHONY : utest
utest : FORCE
	$(PYPATH) $(PYTHON) $(TEST_ARGS) --pattern 'test_unit_*.py'

.PHONY : stest
stest : FORCE
	$(PYPATH) $(PYTHON) $(TEST_ARGS) --pattern 'test_sys_*.py'

.PHONY : test
test : utest stest

#
# documentation
#
.PHONY : readme
readme : $(CHECKOUT_EXE)
	echo '-- AUTOMATICALLY GENERATED FILE. DO NOT EDIT --\n' > $(README)
	echo -n '[![Build Status](https://travis-ci.org/NCAR/manage_externals.svg?branch=master)](https://travis-ci.org/NCAR/manage_externals)' >> $(README)
	echo '[![Coverage Status](https://coveralls.io/repos/github/NCAR/manage_externals/badge.svg?branch=master)](https://coveralls.io/github/NCAR/manage_externals?branch=master)' >> $(README)
	echo '```\n' >> $(README)
	$(CHECKOUT_EXE) --help >> $(README)

#
# coding standards
#
.PHONY : style
style : FORCE
	$(AUTOPEP8) $(AUTOPEP8_ARGS) --recursive $(SRC) $(TEST_DIR)/test_*.py

.PHONY : lint
lint : style
	$(PYLINT) $(PYLINT_ARGS) $(SRC) $(TEST_DIR)/test_*.py

.PHONY : coverage
coverage : FORCE
	$(PYPATH) $(COVERAGE) erase
	$(PYPATH) $(COVERAGE) run $(COVERAGE_ARGS) $(TEST_ARGS) --pattern 'test_*.py'
	$(PYPATH) $(COVERAGE) html

#
# virtual environment creation
#
.PHONY : env
env : FORCE
	$(PYPATH) virtualenv --python $(PYTHON) $@_$(PYTHON)
	. $@_$(PYTHON)/bin/activate; pip install -r requirements.txt

#
# utilites
#
.PHONY : clean
clean : FORCE
	-rm -rf *~ *.pyc

.PHONY : clobber
clobber : clean
	-rm -rf env_* htmlcov tmp fake

FORCE : 

