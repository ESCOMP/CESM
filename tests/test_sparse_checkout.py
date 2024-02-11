import pytest
from shutil import rmtree
from pathlib import Path
from git_fleximod.gitinterface import GitInterface

def test_sparse_checkout(shared_repos, git_fleximod, test_repo_base):
    repo_name = shared_repos["submodule_name"]
    if repo_name == "test_sparse":
        gm = shared_repos["gitmodules_content"]
        (test_repo_base / ".gitmodules").write_text(gm)

        # Add the sparse checkout file
        sparse_content = """m4
"""

        (test_repo_base / "modules" / ".sparse_file_list").write_text(sparse_content)

        result = git_fleximod(f"checkout {repo_name}")
    
        # Assertions
        assert result.returncode == 0
        assert Path(test_repo_base / f"modules/{repo_name}").exists()   # Did the submodule directory get created?
        assert Path(test_repo_base /  f"modules/{repo_name}/m4").exists()   # Did the submodule sparse directory get created?
        assert not Path(test_repo_base /  f"modules/{repo_name}/README").exists()   # Did only the submodule sparse directory get created?
        status = git_fleximod(f"status {repo_name}")
        
        assert f"{repo_name} at tag MPIserial_2.5.0" in status.stdout
        
        result = git_fleximod(f"update {repo_name}")
        assert result.returncode == 0
        
        status = git_fleximod(f"status {repo_name}")
        assert f"{repo_name} at tag MPIserial_2.5.0" in status.stdout

