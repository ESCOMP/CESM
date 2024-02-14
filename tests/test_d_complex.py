import pytest
from pathlib import Path
from git_fleximod.gitinterface import GitInterface

def test_complex_checkout(git_fleximod, complex_repo, logger):
    status = git_fleximod(complex_repo, "status")
    print(status)
