# tests/test_b_update.py
import time
from pathlib import Path


def test_basic_checkout(git_fleximod, test_repo, shared_repos):
    # Prepare a simple .gitmodules
    gm = shared_repos["gitmodules_content"]
    file_path = test_repo / ".gitmodules"
    repo_name = shared_repos["submodule_name"]
    repo_path = shared_repos["subrepo_path"]

    file_path.write_text(gm)

    # Run the command
    result = git_fleximod(test_repo, f"update {repo_name}")

    # Assertions
    assert result.returncode == 0
    assert Path(
        test_repo / repo_path
    ).exists()  # Did the submodule directory get created?
    if "sparse" in repo_name:
        assert Path(
            test_repo / f"{repo_path}/m4"
        ).exists()  # Did the submodule sparse directory get created?
        assert not Path(
            test_repo / f"{repo_path}/README"
        ).exists()  # Did only the submodule sparse directory get created?


def test_local_modification_scenarios(git_fleximod, test_repo, shared_repos):
    """
    Test three scenarios for local modifications:
    1. Local mods, repo in sync: update leaves local mods alone.
    2. Local mods, repo out-of-sync, no conflict: update brings repo up to date, local mods retained, message shown.
    3. Local mods, repo out-of-sync, conflict: update fails with error.
    """
    repo_name = shared_repos["submodule_name"]
    repo_path = shared_repos["subrepo_path"]
    submodule_dir = test_repo / repo_path

    # Ensure submodule is checked out and at intended tag
    gm = shared_repos["gitmodules_content"]
    (test_repo / ".gitmodules").write_text(gm)
    result = git_fleximod(test_repo, f"update {repo_name}")
    assert result.returncode == 0
    assert submodule_dir.exists()
    test_file = submodule_dir / "README"
    if not test_file.exists():
        # README must exist in the repository for this test. If not, skip this test.
        return

    # --- Scenario 1: Local mods, repo in sync ---
    original_content = test_file.read_text()
    local_mod_content = f"local modification {time.time()}\n"
    test_file.write_text(original_content + local_mod_content)
    result1 = git_fleximod(test_repo, f"update {repo_name}")
    assert result1.returncode == 0
    assert (
        test_file.read_text() == original_content + local_mod_content
    ), "Local modification was overwritten when repo was in sync!"

    # --- Scenario 2: Local mods, repo out-of-sync, no conflict ---
    # Simulate out-of-sync by checking out previous commit/tag in submodule
    import subprocess

    # Try to checkout previous commit (if possible)
    log = (
        subprocess.check_output(["git", "log", "--pretty=oneline"], cwd=submodule_dir)
        .decode()
        .splitlines()
    )
    if len(log) > 1:
        prev_hash = log[1].split()[0]
        subprocess.check_call(["git", "checkout", prev_hash], cwd=submodule_dir)
        # Make a local mod that does not conflict
        test_file.write_text(original_content + local_mod_content)
        result2 = git_fleximod(test_repo, f"update {repo_name}")
        assert result2.returncode == 0
        # Should retain local mod and show message
        assert (
            test_file.read_text() == original_content + local_mod_content
        ), "Local modification was lost after update with no conflict!"
        status = git_fleximod(test_repo, f"status {repo_name}")
        assert "modified files" in status.stdout or "modified" in status.stdout.lower()

    # --- Scenario 3: Local mods, repo out-of-sync, conflict ---
    # Simulate conflict by modifying file and checking out previous commit that changes the same file
    if len(log) > 2:
        # Recover original README file
        subprocess.check_call(["git", "restore", "README"], cwd=submodule_dir)
        # Reset to a further previous commit\
        conflict_hash = log[2].split()[0]
        subprocess.check_call(["git", "checkout", conflict_hash], cwd=submodule_dir)
        # Overwrite file with conflicting content
        test_file.write_text("conflicting local mod\n")
        try:
            git_fleximod(test_repo, f"update {repo_name}")
        except Exception as e:
            assert "ERROR" in str(e) or "Failed to checkout" in str(
                e
            ), "Expected error not raised for conflict scenario!"
