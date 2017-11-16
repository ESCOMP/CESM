python = not-set

ifneq ($(python), not-set)
PYTHON=$(python)
else
PYTHON=python
endif

PYPATH=PYTHONPATH=..:

TEST_ARGS=-m unittest --buffer

AUTOPEP8=autopep8
AUTOPEP8_ARGS=--aggressive --in-place 

PYLINT=pylint
PYLINT_ARGS=-j 2 --rcfile=.pylint.rc
PYLINT_3K_ARGS=--py3k

COVERAGE=coverage
COVERAGE_ARGS=--rcfile=.coveragerc

SRC = \
	../checkout_externals.py \
	../manic/*.py

CHECKOUT_EXE = ../checkout_externals.py

TEST_DIR = .

README = ../README.md

utest : FORCE
	$(PYPATH) $(PYTHON) -m unittest discover --buffer --pattern 'test_unit_*.py'

stest : FORCE
	$(PYPATH) $(PYTHON) -m unittest discover --buffer --pattern 'test_sys_*.py'

test : utest

readme : FORCE
	echo '-- AUTOMATICALLY GENERATED FILE. DO NOT EDIT --\n' > $(README)
	echo '[![Build Status](https://travis-ci.org/NCAR/manage_externals.svg?branch=master)](https://travis-ci.org/NCAR/manage_externals)\n' >> $(README)
	echo '```\n' >> $(README)
	$(CHECKOUT_EXE) --help >> $(README)

style : FORCE
	$(AUTOPEP8) $(AUTOPEP8_ARGS) --recursive $(SRC) $(TEST_DIR)/test_*.py

lint : style
	$(PYLINT) $(PYLINT_ARGS) $(SRC) $(TEST_DIR)/test_*.py

coverage : FORCE
	$(PYPATH) $(COVERAGE) run $(COVERAGE_ARGS) test_unit_*.py
	$(PYPATH) $(COVERAGE) html

py3 : 
	$(PYLINT) $(PYLINT_ARGS) $(PYLINT_3K_ARGS) $(SRC) $(TEST_DIR)/*.py

env : FORCE
	$(PYPATH) virtualenv --python $(PYTHON) $@_$(PYTHON)
	. $@_$(PYTHON)/bin/activate; pip install -r requirements.txt

clean : FORCE
	-rm -rf *~ *.pyc

clobber : clean
	-rm -rf env_* htmlcov

FORCE : 
