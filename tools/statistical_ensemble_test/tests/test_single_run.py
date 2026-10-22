"""Tests for case namelist edits without invoking CIME or building CESM."""

import contextlib
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tools.statistical_ensemble_test import single_run


class TestSingleCase(unittest.TestCase):
    def setUp(self):
        temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(temp_dir.cleanup)
        self.addCleanup(os.chdir, os.getcwd())
        root = Path(temp_dir.name)
        self.stat_dir = root / "tools" / "statistical_ensemble_test"
        self.stat_dir.mkdir(parents=True)
        (root / "cime" / "scripts").mkdir(parents=True)
        self.case_dir = root / "case"
        self.case_dir.mkdir()
        (self.case_dir / "user_nl_cam").touch()
        self.pop_namelist = self.case_dir / "user_nl_pop"
        self.original_pop = "! Existing POP namelist\n"
        self.pop_namelist.write_text(self.original_pop)

    def run_case(self, ultrafast=False):
        opts = {
            "case": str(self.case_dir),
            "compset": "F2000climo",
            "res": "f19_f19",
            "ect": "cam",
            "uf": ultrafast,
            "pertlim": "0",
            "nb": True,
            "ns": True,
        }
        with mock.patch.object(single_run.os, "system", return_value=0) as system:
            with contextlib.redirect_stdout(io.StringIO()):
                single_run.single_case(
                    opts, " --case " + str(self.case_dir), str(self.stat_dir)
                )
        system.assert_any_call("./preview_namelists")
        self.assertNotIn(mock.call("./case.build"), system.call_args_list)
        self.assertNotIn(mock.call("./case.submit"), system.call_args_list)

    def check_pop_namelist(self, ultrafast):
        self.run_case(ultrafast=ultrafast)
        text = self.pop_namelist.read_text()
        self.assertTrue(text.startswith(self.original_pop))
        settings = text[len(self.original_pop):].strip().splitlines()
        self.assertEqual(settings[0], "n_tavg_streams = 1")
        self.assertIn("tavg_freq_opt = 'once', 'never', 'never'", settings)
        self.assertIn("tavg_file_freq_opt = 'once', 'never', 'never'", settings)

    def test_cam_pop_namelist(self):
        self.check_pop_namelist(ultrafast=False)

    def test_ultrafast_cam_pop_namelist(self):
        self.check_pop_namelist(ultrafast=True)

    def test_cam_without_pop_namelist(self):
        self.pop_namelist.unlink()
        self.run_case()
        self.assertFalse(self.pop_namelist.exists())


if __name__ == "__main__":
    unittest.main()
