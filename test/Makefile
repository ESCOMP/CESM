PYTHON=python
PYPATH=PYTHONPATH=..:${PYTHONPATH}
TEST_ARGS=-m unittest --buffer

utest : FORCE
	$(PYPATH) $(PYTHON) $(TEST_ARGS) test_cm_unit


stest : FORCE
	$(PYPATH) $(PYTHON) $(TEST_ARGS) test_cm_system.py


test : FORCE
	$(PYPATH) $(PYTHON) -m unittest discover --buffer --pattern 'test_cm_*.py'


clean : FORCE
	-rm -rf *~

FORCE : 
