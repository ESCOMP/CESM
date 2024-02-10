import pytest
from pathlib import Path

def test_basic_checkout(git_fleximod, test_repo):
    # Prepare a simple .gitmodules
    
    gitmodules_content = """
    [submodule "test_submodule"]
        path = modules/test
        url = https://github.com/ESMCI/mpi-serial.git
        fxtag = MPIserial_2.4.0
        fxurl = https://github.com/ESMCI/mpi-serial.git
        fxrequired = T:T
    """
    (test_repo / ".gitmodules").write_text(gitmodules_content)
    
    # Run the command
    result = git_fleximod("checkout")

    # Assertions
    assert result.returncode == 0
    assert Path(test_repo / "modules/test").exists()   # Did the submodule directory get created?

    status = git_fleximod("status")

    assert "test_submodule d82ce7c is out of sync with .gitmodules MPIserial_2.4.0" in status.stdout

    result = git_fleximod("update")
    assert result.returncode == 0

    status = git_fleximod("status")
    assert "test_submodule at tag MPIserial_2.4.0" in status.stdout
