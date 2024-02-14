import pytest
from pathlib import Path
                
def test_basic_checkout(git_fleximod, test_repo, shared_repos):
    # Prepare a simple .gitmodules
    gm = shared_repos['gitmodules_content']
    file_path = (test_repo / ".gitmodules")
    repo_name = shared_repos["submodule_name"]
    repo_path = shared_repos["subrepo_path"]

    file_path.write_text(gm)
    
    # Run the command
    result = git_fleximod(test_repo, f"update {repo_name}")

    # Assertions
    assert result.returncode == 0 
    assert Path(test_repo / repo_path).exists()   # Did the submodule directory get created?
    if "sparse" in repo_name:
        assert Path(test_repo /  f"{repo_path}/m4").exists()   # Did the submodule sparse directory get created?
        assert not Path(test_repo /  f"{repo_path}/README").exists()   # Did only the submodule sparse directory get created?
    
    status = git_fleximod(test_repo, f"status {repo_name}")
        
    assert shared_repos["status2"] in status.stdout
        
