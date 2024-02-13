import pytest
from pathlib import Path
from git_fleximod.gitinterface import GitInterface

def test_complex_checkout(git_fleximod, get_all_repos, test_repo, request, logger):
    gitp = None
    for repo in get_all_repos:
        repo_name = repo["submodule_name"]
        gm = repo["gitmodules_content"]
        if "shared_repos0" in request.node.name:
            if not gitp:
                gitp = GitInterface(str(test_repo), logger)
            file_path = (test_repo / ".gitmodules")
            if file_path.exists():
                with file_path.open("r") as f:
                    gitmodules_content = f.read()
                    print(f"content={gitmodules_content}")
                    print(f"gm={gm}")
                    # add the entry if it does not exist
                    if repo_name not in gitmodules_content:
                        file_path.write_text(gitmodules_content+gm)
                    # or if it is incomplete
                    elif gm not in gitmodules_content:
                        file_path.write_text(gm)
                        
            else:
                file_path.write_text(gm)
            if "sparse" in repo_name:
                print(f"writing sparse_file_list in {test_repo}")
                write_sparse_checkout_file(test_repo / "modules" / ".sparse_file_list")
                gitp.git_operation("add","modules/.sparse_file_list")
            gitp.git_operation("commit","-a","-m","\"add submod\"")

            
    assert(False)
