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

EXE = ../checkout_externals.py

TEST_DIR = .

utest : FORCE
	$(PYPATH) $(PYTHON) -m unittest discover --buffer --pattern 'test_unit_*.py'

stest : FORCE
	$(PYPATH) $(PYTHON) -m unittest discover --buffer --pattern 'test_sys_*.py'

test : utest

readme : FORCE
	echo '-- AUTOMATICALLY GENERATED FILE. DO NOT EDIT --\n' > ../README
	$(EXE) --help >> ../README

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
	. $@_$(PYTHON)/bin/activate; pip install 'pyaml>=17.10.0'
	. $@_$(PYTHON)/bin/activate; pip install 'pylint>=1.7.0'
	. $@_$(PYTHON)/bin/activate; pip install 'autopep8>=1.3.0'
	. $@_$(PYTHON)/bin/activate; pip install 'coverage>=4.4.0'

clean : FORCE
	-rm -rf *~ *.pyc

clobber : clean
	-rm -rf env_* htmlcov

FORCE : 
