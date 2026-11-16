import json
import pathlib
import shutil
import subprocess
import unittest

HOOKS_JSON = pathlib.Path(__file__).resolve().parents[1] / "codex/hooks.json"
REAL_RTK = shutil.which("rtk")


def hook_command() -> str:
    config = json.loads(HOOKS_JSON.read_text())
    return config["hooks"]["PreToolUse"][0]["hooks"][0]["command"]


def run_codex_hook(**extra) -> str:
    event = {
        "session_id": "plan-test",
        "hook_event_name": "PreToolUse",
        "cwd": "/tmp",
        "model": "test-model",
        "tool_name": "Bash",
        "tool_input": {"command": "git status"},
        **extra,
    }
    return subprocess.run(
        [REAL_RTK, "hook", "codex"],
        input=json.dumps(event),
        text=True,
        capture_output=True,
        check=True,
    ).stdout


class CommittedHookTests(unittest.TestCase):
    def test_committed_hook_calls_the_native_codex_processor(self):
        self.assertEqual(hook_command(), "rtk hook codex")

    def test_hook_command_is_bare_so_an_absent_rtk_is_unresolvable(self):
        self.assertTrue(
            hook_command().startswith("rtk "),
            "the hook command no longer invokes rtk directly; "
            "revisit tools/rtk/README.md",
        )


@unittest.skipUnless(REAL_RTK, "rtk not installed")
class CodexProcessorTests(unittest.TestCase):
    def test_native_codex_processor_rewrites_and_allows(self):
        output = json.loads(run_codex_hook(permission_mode="default"))
        decision = output["hookSpecificOutput"]
        self.assertEqual(decision["updatedInput"]["command"], "rtk git status")
        self.assertEqual(decision["permissionDecision"], "allow")

    def test_codex_processor_emits_nothing_without_permission_mode(self):
        self.assertEqual(
            run_codex_hook(),
            "",
            "codex processor now handles a payload without permission_mode; "
            "revisit tools/rtk/README.md",
        )


if __name__ == "__main__":
    unittest.main(argv=["codex_hook_contract_test.py"], verbosity=2)
