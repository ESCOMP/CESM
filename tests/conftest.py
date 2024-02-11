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

@pytest.fixture(params=[
    {"subrepo_path": "modules/test", "submodule_name": "test_submodule", "gitmodules_content" : """
    [submodule "test_submodule"]
    path = modules/test
    url = https://github.com/ESMCI/mpi-serial.git
    fxtag = MPIserial_2.4.0
    fxurl = https://github.com/ESMCI/mpi-serial.git
    fxrequired = ToplevelOnlyRequired
"""},
    {"subrepo_path": "modules/test_optional", "submodule_name": "test_optional", "gitmodules_content": """
    [submodule "test_optional"]
    path = modules/test_optional
    url = https://github.com/ESMCI/mpi-serial.git
    fxtag = MPIserial_2.4.0
    fxurl = https://github.com/ESMCI/mpi-serial.git
    fxrequired = ToplevelOnlyRequired
"""},
    {"subrepo_path": "modules/test_alwaysoptional", "submodule_name": "test_alwaysoptional", "gitmodules_content": """
    [submodule "test_alwaysoptional"]
    path = modules/test_alwaysoptional
    url = https://github.com/ESMCI/mpi-serial.git
    fxtag = MPIserial_2.3.0
    fxurl = https://github.com/ESMCI/mpi-serial.git
    fxrequired = AlwaysOptional
"""},    
    {"subrepo_path": "modules/test_sparse", "submodule_name": "test_sparse", "gitmodules_content": """
    [submodule "test_sparse"]
    path = modules/test_sparse
    url = https://github.com/ESMCI/mpi-serial.git
    fxtag = MPIserial_2.5.0
    fxurl = https://github.com/ESMCI/mpi-serial.git
    fxrequired = AlwaysRequired
    fxsparse = ../.sparse_file_list
"""},
])

def shared_repos(request):
    return request.param

@pytest.fixture
def test_repo(shared_repos, test_repo_base, logger): 
    subrepo_path = shared_repos["subrepo_path"]
    submodule_name = shared_repos["submodule_name"]

    gitp = GitInterface(str(test_repo_base), logger)
    gitp.git_operation("submodule", "add", "--depth","1","--name", submodule_name, "https://github.com/ESMCI/mpi-serial.git", subrepo_path)
    assert test_repo_base.joinpath(".gitmodules").is_file()
    return test_repo_base

@pytest.fixture
def test_repo_base(tmp_path, logger):
    test_dir = tmp_path / "testrepo"
    test_dir.mkdir()
    str_path = str(test_dir)
    gitp = GitInterface(str_path, logger)
    assert test_dir.joinpath(".git").is_dir()
    (test_dir / "modules").mkdir()
    return test_dir
    
@pytest.fixture
def git_fleximod(test_repo_base):
    def _run_fleximod(args, input=None):
        cmd = ["git", "fleximod"] + args.split()
        result = subprocess.run(cmd, cwd=test_repo_base, input=input, 
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
                                text=True)
        return result
    return _run_fleximod

