import pytest
from pathlib import Path

@pytest.fixture(params=[
    {"subrepo_path": "modules/test", "submodule_name": "test_submodule", "gitmodules_content" : """                                                                                                                                                                                      [submodule "test_submodule"]
        path = modules/test
        url = https://github.com/ESMCI/mpi-serial.git
        fxtag = MPIserial_2.4.0
        fxurl = https://github.com/ESMCI/mpi-serial.git
        fxrequired = ToplevelOnlyRequired
"""},
])
def test_config(request):                
    return request.param
                
def test_basic_checkout(git_fleximod, test_repo, test_config):
    # Prepare a simple .gitmodules
    gm = test_config['gitmodules_content']
    file_path = (test_repo / ".gitmodules")
    if not file_path.exists():
        file_path.write_text(gm)
    
        # Run the command
        result = git_fleximod("checkout test_submodule")
        
        # Assertions
        assert result.returncode == 0
        assert Path(test_repo / "modules/test").exists()   # Did the submodule directory get created?
        
        status = git_fleximod("status")
        
        assert "test_submodule d82ce7c is out of sync with .gitmodules MPIserial_2.4.0" in status.stdout
        
        result = git_fleximod("update")
        assert result.returncode == 0
        
        status = git_fleximod("status")
        assert "test_submodule at tag MPIserial_2.4.0" in status.stdout
