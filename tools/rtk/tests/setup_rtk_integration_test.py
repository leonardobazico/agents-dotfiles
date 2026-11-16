import json
import subprocess
import unittest

from setup_rtk_fixture import REAL_RTK, SetupRtkCase


class IntegrationTests(SetupRtkCase):
    @unittest.skipUnless(REAL_RTK, "real rtk not installed")
    def test_real_rtk_install_rerun_and_uninstall(self):
        print(
            "integration rtk:",
            subprocess.check_output([REAL_RTK, "--version"], text=True).strip(),
        )
        cases = [
            ("20260930T120000Z", ()),
            ("20260930T120001Z", ()),
            ("20260930T120002Z", ("--uninstall",)),
        ]
        for stamp, args in cases:
            self.executable("date", '#!/bin/sh\nprintf "%s\\n" ' + stamp + "\n")
            result = self.run_setup(*args, real=True)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn(
                "SessionStart", json.loads(self.settings.read_text())["hooks"]
            )
            self.assertEqual(
                0 if args else 1, self.settings.read_text().count("rtk hook claude")
            )
            self.assertEqual(
                not bool(args), (self.root / ".config/opencode/plugins/rtk.ts").exists()
            )


if __name__ == "__main__":
    unittest.main(argv=["setup_rtk_integration_test.py"], verbosity=2)
