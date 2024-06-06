import pytest
from pathlib import Path
from git_fleximod.gitinterface import GitInterface

def test_complex_checkout(git_fleximod, complex_repo, logger):
    status = git_fleximod(complex_repo, "status")
    assert("ToplevelOptional not checked out, aligned at tag v5.3.2" in status.stdout)
    assert("ToplevelRequired not checked out, aligned at tag MPIserial_2.5.0" in status.stdout)
    assert("AlwaysRequired not checked out, aligned at tag MPIserial_2.4.0" in status.stdout)
    assert("Complex not checked out, aligned at tag testtag02" in status.stdout)
    assert("AlwaysOptional not checked out, out of sync at tag None, expected tag is MPIserial_2.3.0" in status.stdout)
    
    # This should checkout and update test_submodule and complex_sub
    result = git_fleximod(complex_repo, "update")    
    assert result.returncode == 0

    status = git_fleximod(complex_repo, "status")
    assert("ToplevelOptional not checked out, aligned at tag v5.3.2" in status.stdout)
    assert("ToplevelRequired at tag MPIserial_2.5.0" in status.stdout)
    assert("AlwaysRequired at tag MPIserial_2.4.0" in status.stdout)
    assert("Complex at tag testtag02" in status.stdout)

    # now check the complex_sub
    root = (complex_repo / "modules" / "complex")
    assert(not (root / "libraries" / "gptl" / ".git").exists())
    assert(not (root / "libraries" / "mpi-serial" / ".git").exists())
    assert((root / "modules" / "mpi-serial" / ".git").exists())
    assert(not (root / "modules" / "mpi-serial2" / ".git").exists())
    assert((root / "modules" / "mpi-sparse" / ".git").exists())
    assert((root / "modules" / "mpi-sparse" / "m4").exists())
    assert(not (root / "modules" / "mpi-sparse" / "README").exists())

    # update a single optional submodule

    result = git_fleximod(complex_repo, "update ToplevelOptional")
    assert result.returncode == 0

    status = git_fleximod(complex_repo, "status")
    assert("ToplevelOptional at tag v5.3.2" in status.stdout)
    assert("ToplevelRequired at tag MPIserial_2.5.0" in status.stdout)
    assert("AlwaysRequired at tag MPIserial_2.4.0" in status.stdout)
    assert("Complex at tag testtag02" in status.stdout)
    assert("AlwaysOptional not checked out, out of sync at tag None, expected tag is MPIserial_2.3.0" in status.stdout)

    # Finally update optional
    result = git_fleximod(complex_repo, "update --optional")
    assert result.returncode == 0

    status = git_fleximod(complex_repo, "status")
    assert("ToplevelOptional at tag v5.3.2" in status.stdout)
    assert("ToplevelRequired at tag MPIserial_2.5.0" in status.stdout)
    assert("AlwaysRequired at tag MPIserial_2.4.0" in status.stdout)
    assert("Complex at tag testtag02" in status.stdout)
    assert("AlwaysOptional at tag MPIserial_2.3.0" in status.stdout)
    
    # now check the complex_sub
    root = (complex_repo / "modules" / "complex" )
    assert(not (root / "libraries" / "gptl" / ".git").exists())
    assert(not (root / "libraries" / "mpi-serial" / ".git").exists())
    assert((root / "modules" / "mpi-serial" / ".git").exists())
    assert((root / "modules" / "mpi-serial2" / ".git").exists())
    assert((root / "modules" / "mpi-sparse" / ".git").exists())
    assert((root / "modules" / "mpi-sparse" / "m4").exists())
    assert(not (root / "modules" / "mpi-sparse" / "README").exists())


