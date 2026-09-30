#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
hooks_json="$repo_root/tools/rtk/codex/hooks.json"

status=0
pass() { echo "ok - $1"; }
fail() { echo "not ok - $1" >&2; status=1; }

payload() {
	python3 -c '
import json, sys
event = {
    "session_id": "plan-test",
    "hook_event_name": "PreToolUse",
    "cwd": "/tmp",
    "model": "test-model",
    "tool_name": "Bash",
    "tool_input": {"command": "git status"},
}
if sys.argv[1] == "with-permission-mode":
    event["permission_mode"] = "default"
print(json.dumps(event))' "$1"
}

hook_command="$(python3 -c '
import json, sys
with open(sys.argv[1]) as handle:
    config = json.load(handle)
print(config["hooks"]["PreToolUse"][0]["hooks"][0]["command"])' "$hooks_json")"

if [ "$hook_command" = "rtk hook codex" ]; then
	pass "committed hook calls the native codex processor"
else
	fail "committed hook calls the native codex processor (got: $hook_command)"
fi

if printf '%s' "$hook_command" | grep -q '^rtk '; then
	pass "documented: the hook command is bare, so an absent rtk binary is unresolvable"
else
	fail "the hook command no longer invokes rtk directly; revisit tools/rtk/README.md"
fi

if ! command -v rtk >/dev/null 2>&1; then
	echo "# rtk not installed; skipping behavior assertions"
	exit "$status"
fi

rewritten="$(payload with-permission-mode | rtk hook codex)"
if printf '%s' "$rewritten" | python3 -c '
import json, sys
output = json.load(sys.stdin)["hookSpecificOutput"]
assert output["updatedInput"]["command"] == "rtk git status", output
assert output["permissionDecision"] == "allow", output'; then
	pass "native codex processor rewrites and allows"
else
	fail "native codex processor rewrites and allows"
fi

silent="$(payload without-permission-mode | rtk hook codex)"
if [ -z "$silent" ]; then
	pass "documented: codex processor emits nothing without permission_mode"
else
	fail "codex processor now handles a payload without permission_mode; revisit tools/rtk/README.md (got: $silent)"
fi

exit "$status"
