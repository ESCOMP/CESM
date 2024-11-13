import pytest 
from git_fleximod.gitinterface import GitInterface
import os
import subprocess
import logging
from pathlib import Path

@pytest.fixture(scope='session')
def logger():
    logging.basicConfig(
        level=logging.INFO, format="%(name)s - %(levelname)s - %(message)s", handlers=[logging.StreamHandler()]
    )
    logger = logging.getLogger(__name__)
    return logger

all_repos=[
    {"subrepo_path": "modules/test",
     "submodule_name": "test_submodule",
     "status1" : "test_submodule MPIserial_2.5.0-3-gd82ce7c is out of sync with .gitmodules MPIserial_2.4.0",
     "status2" : "test_submodule at tag MPIserial_2.4.0",
     "status3" : "test_submodule at tag MPIserial_2.4.0",
     "status4" : "test_submodule at tag MPIserial_2.4.0",
     "gitmodules_content" : """
    [submodule "test_submodule"]
    path = modules/test
    url = https://github.com/ESMCI/mpi-serial.git
    fxtag = MPIserial_2.4.0
    fxDONOTUSEurl = https://github.com/ESMCI/mpi-serial.git
    fxrequired = ToplevelRequired
"""},
    {"subrepo_path": "modules/test_optional",
     "submodule_name": "test_optional",
     "status1" : "test_optional MPIserial_2.5.0-3-gd82ce7c is out of sync with .gitmodules MPIserial_2.4.0",
     "status2" : "test_optional at tag MPIserial_2.4.0",
     "status3" : "test_optional not checked out, out of sync at tag MPIserial_2.5.1, expected tag is MPIserial_2.4.0 (optional)",
     "status4" : "test_optional at tag MPIserial_2.4.0",
     "gitmodules_content": """
     [submodule "test_optional"]
    path = modules/test_optional
    url = https://github.com/ESMCI/mpi-serial.git
    fxtag = MPIserial_2.4.0
    fxDONOTUSEurl = https://github.com/ESMCI/mpi-serial.git
    fxrequired = ToplevelOptional
"""},
    {"subrepo_path": "modules/test_alwaysoptional",
     "submodule_name": "test_alwaysoptional",
     "status1" : "test_alwaysoptional MPIserial_2.3.0 is out of sync with .gitmodules e5cf35c",
     "status2" : "test_alwaysoptional at hash e5cf35c",
     "status3" : "out of sync at tag MPIserial_2.5.1, expected tag is e5cf35c",
     "status4" : "test_alwaysoptional at hash e5cf35c",
     "gitmodules_content": """
    [submodule "test_alwaysoptional"]
    path = modules/test_alwaysoptional
    url = https://github.com/ESMCI/mpi-serial.git
    fxtag = e5cf35c
    fxDONOTUSEurl = https://github.com/ESMCI/mpi-serial.git
    fxrequired = AlwaysOptional
"""},    
    {"subrepo_path": "modules/test_sparse",
     "submodule_name": "test_sparse",
     "status1" : "test_sparse at tag MPIserial_2.5.0",
     "status2" : "test_sparse at tag MPIserial_2.5.0",
     "status3" : "test_sparse at tag MPIserial_2.5.0",
     "status4" : "test_sparse at tag MPIserial_2.5.0",
     "gitmodules_content": """
    [submodule "test_sparse"]
    path = modules/test_sparse
    url = https://github.com/ESMCI/mpi-serial.git
    fxtag = MPIserial_2.5.0
    fxDONOTUSEurl = https://github.com/ESMCI/mpi-serial.git
    fxrequired = AlwaysRequired
    fxsparse = ../.sparse_file_list
"""},
]
@pytest.fixture(params=all_repos)

def shared_repos(request):
    return request.param

@pytest.fixture
def get_all_repos():
    return all_repos

def write_sparse_checkout_file(fp):
    sparse_content = """m4
"""
    fp.write_text(sparse_content)

@pytest.fixture
def test_repo(shared_repos, tmp_path, logger):
    subrepo_path = shared_repos["subrepo_path"]
    submodule_name = shared_repos["submodule_name"]
    test_dir = tmp_path / "testrepo"
    test_dir.mkdir()
    str_path = str(test_dir)
    gitp = GitInterface(str_path, logger)
    assert test_dir.joinpath(".git").is_dir()
    (test_dir / "modules").mkdir()
    if "sparse" in submodule_name:
        (test_dir / subrepo_path).mkdir()
        # Add the sparse checkout file
        write_sparse_checkout_file(test_dir / "modules" / ".sparse_file_list")
        gitp.git_operation("add","modules/.sparse_file_list")
    else:
        gitp = GitInterface(str(test_dir), logger)
        gitp.git_operation("submodule", "add", "--depth","1","--name", submodule_name, "https://github.com/ESMCI/mpi-serial.git", subrepo_path)
        assert test_dir.joinpath(".gitmodules").is_file()
        gitp.git_operation("add",subrepo_path)
    gitp.git_operation("commit","-a","-m","\"add submod\"")
    test_dir2 = tmp_path / "testrepo2"
    gitp.git_operation("clone",test_dir,test_dir2)
    return test_dir2    


@pytest.fixture
def complex_repo(tmp_path, logger):
    test_dir = tmp_path / "testcomplex"
    test_dir.mkdir()
    str_path = str(test_dir)
    gitp = GitInterface(str_path, logger)
    gitp.git_operation("remote", "add", "origin", "https://github.com/jedwards4b/fleximod-test2")
    gitp.git_operation("fetch", "origin")
    gitp.git_operation("checkout", "v0.0.1")
    return test_dir

@pytest.fixture
def complex_update(tmp_path, logger):
    test_dir = tmp_path / "testcomplex"
    test_dir.mkdir()
    str_path = str(test_dir)
    gitp = GitInterface(str_path, logger)
    gitp.git_operation("remote", "add", "origin", "https://github.com/jedwards4b/fleximod-test2")
    gitp.git_operation("fetch", "origin")
    gitp.git_operation("checkout", "v0.0.2")
    
    return test_dir
    
@pytest.fixture
def git_fleximod():
    def _run_fleximod(path, args, input=None):
        cmd = ["git", "fleximod"] + args.split()
        result = subprocess.run(cmd, cwd=path, input=input, 
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
                                text=True)
        if result.returncode:
            print(result.stdout)
            print(result.stderr)
        return result
    return _run_fleximod

