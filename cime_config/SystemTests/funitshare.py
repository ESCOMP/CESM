"""
Implementation of the share code FUNIT test.

This "system" test runs the share code's Fortran unit tests. We're abusing the system test
infrastructure to run these, so that a run of the test suite can result in the unit tests
being run as well.

Grid and compset are irrelevant for this test type.
"""

import os
from CIME.SystemTests.funit import FUNIT
from CIME.XML.standard_module_setup import *

logger = logging.getLogger(__name__)


class FUNITSHARE(FUNIT):
    def __init__(self, case):
        FUNIT.__init__(self, case)

        # The CMake build for the share unit tests uses the MPISERIAL env var to find the
        # mpi-serial library. On derecho, MPISERIAL is not set even if the mpi-serial
        # module is loaded; instead, there is an NCAR_ROOT_MPI_SERIAL variable. Set the
        # needed MPISERIAL env var for this test.
        if "NCAR_ROOT_MPI_SERIAL" in os.environ:
            os.environ["MPISERIAL"] = os.environ["NCAR_ROOT_MPI_SERIAL"]

    def get_test_spec_dir(self):
        return os.path.join(self._case.get_value("SRCROOT"), "share")

    def get_extra_run_tests_args(self):
        return '--cmake-args " -DUNITTESTS=ON -DUSE_CIME_MACROS=ON"'
