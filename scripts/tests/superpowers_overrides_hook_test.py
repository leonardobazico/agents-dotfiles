import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

HOOK_SOURCE = (
    pathlib.Path(__file__).resolve().parents[2]
    / "harnesses/claude/hooks/superpowers-overrides"
)


class SuperpowersOverridesHookTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="superpowers-overrides-")
        self.addCleanup(temp.cleanup)
        self.root = pathlib.Path(temp.name)
        (self.root / "hooks").mkdir()
        self.hook = self.root / "hooks/superpowers-overrides"
        shutil.copy2(HOOK_SOURCE, self.hook)
        self.markdown = self.root / "superpowers-overrides.md"

    def run_hook(self, *command, env=None):
        return subprocess.run(
            [*command, str(self.hook)],
            env=env,
            capture_output=True,
        )

    def assert_silent_success(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_hook_source_is_executable(self):
        self.assertTrue(os.access(HOOK_SOURCE, os.X_OK))

    def test_emits_valid_json_preserving_the_markdown_exactly(self):
        expected = (
            "# Overrides\n\n"
            'A "quoted" phrase, a back\\slash, and non-ASCII: precedencia.\n\n'
            "- Tab:\there\n"
        )
        self.markdown.write_text(expected, encoding="utf-8")
        result = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)["hookSpecificOutput"]
        self.assertEqual(output["hookEventName"], "SessionStart")
        self.assertEqual(output["additionalContext"], expected)

    def test_exits_silently_when_the_markdown_is_missing(self):
        self.assert_silent_success(self.run_hook())

    def test_exits_silently_when_python3_is_unavailable(self):
        self.markdown.write_text("# Overrides\n")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        (bin_dir / "dirname").symlink_to(shutil.which("dirname"))
        result = self.run_hook(shutil.which("bash"), env={"PATH": str(bin_dir)})
        self.assert_silent_success(result)

    def test_exits_silently_when_the_markdown_is_not_valid_utf8(self):
        self.markdown.write_bytes(b"# Overrides\n\xff\xfe not utf-8\n")
        self.assert_silent_success(self.run_hook())


if __name__ == "__main__":
    unittest.main(argv=["superpowers_overrides_hook_test.py"], verbosity=2)
