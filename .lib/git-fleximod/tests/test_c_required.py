import pytest
from pathlib import Path
                
def test_required(git_fleximod, test_repo, shared_repos):
    file_path = (test_repo / ".gitmodules")
    gm = shared_repos["gitmodules_content"]
    repo_name = shared_repos["submodule_name"]
    if file_path.exists():
        with file_path.open("r") as f:
            gitmodules_content = f.read()
            # add the entry if it does not exist
            if repo_name not in gitmodules_content:
                file_path.write_text(gitmodules_content+gm)
            # or if it is incomplete
            elif gm not in gitmodules_content:
                file_path.write_text(gm)
    else:
        file_path.write_text(gm)
    result = git_fleximod(test_repo, "update")
    assert result.returncode == 0
    status = git_fleximod(test_repo, f"status {repo_name}")
    assert shared_repos["status3"] in status.stdout
    status = git_fleximod(test_repo, f"update --optional")
    assert result.returncode == 0
    status = git_fleximod(test_repo, f"status {repo_name}")
    assert shared_repos["status4"] in status.stdout
    status = git_fleximod(test_repo, f"update {repo_name}")
    assert result.returncode == 0
    status = git_fleximod(test_repo, f"status {repo_name}")
    assert shared_repos["status4"] in status.stdout
