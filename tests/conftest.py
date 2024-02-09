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

@pytest.fixture
def test_repo_base(tmp_path, logger):
    test_dir = tmp_path / "test_repo"
    test_dir.mkdir()
    str_path = str(test_dir)
    gitp = GitInterface(str_path, logger)
    #subprocess.run(["git", "init"], cwd=test_dir)
    assert test_dir.joinpath(".git").is_dir()
    return test_dir
    
@pytest.fixture(params=["modules/test"])
def test_repo(request, test_repo_base, logger):
    subrepo_path = request.param
    gitp = GitInterface(str(test_repo_base), logger)
    gitp.git_operation("submodule", "add", "--depth","1","--name","test_submodule", "https://github.com/ESMCI/mpi-serial.git", subrepo_path)
    #    subprocess.run(
    assert test_repo_base.joinpath(".gitmodules").is_file()
    return test_repo_base

@pytest.fixture
def git_fleximod(test_repo):
    def _run_fleximod(args, input=None):
        cmd = ["git", "fleximod"] + args.split()
        result = subprocess.run(cmd, cwd=test_repo, input=input, 
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
                                text=True)
        return result
    return _run_fleximod

    
@pytest.fixture
def deinit_submodule(test_repo, logger):
    def _deinit(submodule_path):
        gitp = GitInterface(str(test_repo), logger)
        gitp.git_operation( "submodule", "deinit", "-f", submodule_path) 
    yield _deinit 
