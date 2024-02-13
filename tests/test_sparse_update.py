import pytest
from shutil import rmtree
from pathlib import Path
from git_fleximod.gitinterface import GitInterface

def test_sparse_checkout(git_fleximod, test_repo_base):
    # Prepare a simple .gitmodules
    gitmodules_content = (test_repo_base / ".gitmodules").read_text() + """
    [submodule "test_sparse_submodule"]
        path = modules/sparse_test
        url = https://github.com/ESMCI/mpi-serial.git
        fxtag = MPIserial_2.5.0
        fxurl = https://github.com/ESMCI/mpi-serial.git
        fxsparse = ../.sparse_file_list
    """
    (test_repo_base / ".gitmodules").write_text(gitmodules_content)

    # Add the sparse checkout file
    sparse_content = """m4
"""
    (test_repo_base / "modules" / ".sparse_file_list").write_text(sparse_content)

    result = git_fleximod("update")
    
    # Assertions
    assert result.returncode == 0
    assert Path(test_repo_base / "modules/sparse_test").exists()   # Did the submodule directory get created?
    assert Path(test_repo_base /  "modules/sparse_test/m4").exists()   # Did the submodule sparse directory get created?
    assert not Path(test_repo_base /  "modules/sparse_test/README").exists()   # Did only the submodule sparse directory get created?
    status = git_fleximod("status test_sparse_submodule")

    assert "test_sparse_submodule at tag MPIserial_2.5.0" in status.stdout

