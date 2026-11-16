import subprocess
import unittest

from setup_rtk_fixture import SETUP, SetupRtkCase


class PreflightTests(SetupRtkCase):
    def test_homebrew_rtk_is_upgraded_before_install_initialization(self):
        result = self.run_setup()
        self.assertEqual(0, result.returncode, result.stderr)
        events = self.event_log.read_text().splitlines()
        self.assertIn("brew upgrade rtk", events)
        self.assertLess(
            events.index("brew upgrade rtk"),
            events.index("rtk init --global --hook-only --auto-patch --agent claude"),
        )

    def test_uninstall_does_not_upgrade_rtk(self):
        result = self.run_setup("--uninstall")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertNotIn("brew upgrade rtk", self.event_log.read_text().splitlines())

    def test_missing_rtk_installs_supported_formula_before_init(self):
        (self.bin / "rtk").unlink()
        self.env["BREW_INSTALLED"] = "0"
        self.env["PATH"] = str(self.bin)
        result = self.run_setup()
        self.assertEqual(0, result.returncode, result.stderr)
        events = self.event_log.read_text().splitlines()
        self.assertIn("brew install rtk", events)
        self.assertTrue((self.root / ".config/opencode/plugins/rtk.ts").exists())

    def test_non_homebrew_rtk_is_not_migrated_or_version_checked(self):
        self.env["BREW_INSTALLED"] = "0"
        result = self.run_setup()
        self.assertEqual(0, result.returncode, result.stderr)
        events = self.event_log.read_text().splitlines()
        self.assertFalse(any(event.startswith("brew upgrade ") for event in events))
        self.assertFalse(any(event.startswith("brew install ") for event in events))
        self.assertTrue((self.root / ".config/opencode/plugins/rtk.ts").exists())

    def test_brew_upgrade_failure_stops_before_init_or_settings_mutation(self):
        self.backup.write_bytes(b"ORIGINAL")
        self.env["BREW_UPGRADE_EXIT"] = "19"
        result = self.run_setup()
        self.assertEqual(1, result.returncode)
        self.assertIn("failed to upgrade", result.stderr)
        self.assertEqual(self.original, self.settings.read_bytes())
        self.assertEqual(b"ORIGINAL", self.backup.read_bytes())
        events = self.event_log.read_text().splitlines()
        self.assertIn("brew upgrade rtk", events)
        self.assertFalse(any(event.startswith("rtk ") for event in events))

    def test_brew_install_failure_stops_before_init_or_settings_mutation(self):
        (self.bin / "rtk").unlink()
        self.env["BREW_INSTALLED"] = "0"
        self.env["BREW_INSTALL_EXIT"] = "18"
        self.env["PATH"] = str(self.bin)
        result = self.run_setup()
        self.assertEqual(1, result.returncode)
        self.assertIn("failed to install", result.stderr)
        self.assertEqual(self.original, self.settings.read_bytes())
        events = self.event_log.read_text().splitlines()
        self.assertIn("brew install rtk", events)
        self.assertFalse(any(event.startswith("rtk ") for event in events))

    def test_missing_rtk_uninstall_fails_without_mutation(self):
        result = subprocess.run(
            [str(SETUP), "--uninstall"],
            env={**self.env, "PATH": "/usr/bin:/bin"},
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("reinstall", result.stderr.lower())
        self.assertEqual(self.original, self.settings.read_bytes())

    def test_missing_rtk_and_brew_fails(self):
        result = subprocess.run(
            [str(SETUP)],
            env={**self.env, "PATH": "/usr/bin:/bin"},
            text=True,
            capture_output=True,
        )
        self.assertEqual(1, result.returncode)
        self.assertIn("homebrew", result.stderr.lower())

    def test_invalid_mode_does_not_touch_backup(self):
        self.backup.write_bytes(b"ORIGINAL")
        result = self.run_setup("invalid")
        self.assertEqual(2, result.returncode)
        self.assertIn("usage:", result.stderr)
        self.assertEqual(b"ORIGINAL", self.backup.read_bytes())


if __name__ == "__main__":
    unittest.main(argv=["setup_rtk_preflight_test.py"], verbosity=2)
