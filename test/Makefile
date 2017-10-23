PYTHON=python
PYTHON3=python3
PYPATH=PYTHONPATH=..:${PYTHONPATH}
TEST_ARGS=-m unittest --buffer

AUTOPEP8=autopep8
AUTOPEP8_ARGS=--aggressive --in-place 

PYLINT=pylint
PYLINT_ARGS=-j 2 --py3k --rcfile=../.pylint.rc
PYLINT_3K_ARGS=--py3k

SRC = \
	../checkout_model.py

TEST_DIR = .

utest : FORCE
	$(PYPATH) $(PYTHON) -m unittest discover --buffer --pattern 'test_cm_unit*.py'


utest3 : FORCE
	$(PYPATH) $(PYTHON3) -m unittest discover --buffer --pattern 'test_cm_unit*.py'

stest : FORCE
	$(PYPATH) $(PYTHON) -m unittest discover --buffer --pattern 'test_cm_sys*.py'

test : utest

readme : FORCE
	echo '-- AUTOMATICALLY GENERATED FILE. DO NOT EDIT --\n' > ../README
	../checkout_model.py --help >> ../README

style : FORCE
	$(AUTOPEP8) $(AUTOPEP8_ARGS) --recursive $(SRC) $(TEST_DIR)

lint : style
	$(PYLINT) $(PYLINT_ARGS) $(SRC) $(TEST_DIR)/*.py

py3 : 
	$(PYLINT) $(PYLINT_ARGS) $(PYLINT_3K_ARGS) $(SRC) $(TEST_DIR)/*.py

clean : FORCE
	-rm -rf *~ test/*~

FORCE : 
