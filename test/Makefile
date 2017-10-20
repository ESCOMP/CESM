PYTHON=python
PYPATH=PYTHONPATH=..:${PYTHONPATH}
TEST_ARGS=-m unittest --buffer

AUTOPEP8=autopep8
AUTOPEP8_ARGS=--aggressive --in-place 

PYLINT=pylint
PYLINT_ARGS=--rcfile=../.pylint.rc

SRC = \
	../checkout_model.py

TEST_DIR = .

utest : FORCE
	$(PYPATH) $(PYTHON) -m unittest discover --buffer --pattern 'test_cm_unit*.py'


stest : FORCE
	$(PYPATH) $(PYTHON) -m unittest discover --buffer --pattern 'test_cm_sys*.py'

test : utestx

readme : FORCE
	echo '-- AUTOMATICALLY GENERATED FILE. DO NOT EDIT --\n' > ../README
	../checkout_model.py --help >> ../README

style : FORCE
	$(AUTOPEP8) $(AUTOPEP8_ARGS) --recursive $(SRC) $(TEST_DIR)

lint : style
	$(PYLINT) $(PYLINT_ARGS) $(SRC) $(TEST_DIR)/*.py

clean : FORCE
	-rm -rf *~ test/*~

FORCE : 
