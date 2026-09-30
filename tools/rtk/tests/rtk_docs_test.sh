#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"

status=0
pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1" >&2; status=1; }

# rtk's hook rewrites commands on its own and its truncated output carries its
# own `rtk recall` recovery path, so the installed instructions say nothing about
# running commands. A reinstated section would be prose no agent needs.
if grep -q '^## Running Commands' "$repo_root/shared/agents-md/AGENTS.md"; then
	fail "installed AGENTS.md carries a Running Commands section the rtk hook makes redundant"
else
	pass "installed AGENTS.md leaves command running to the rtk hook"
fi

readme="$repo_root/tools/rtk/README.md"

if grep -qi 'trust' "$readme" && grep -qi 'does not bypass\|until you approve\|inert until' "$readme"; then
	pass "README records that the Codex hook needs trust approval linking does not bypass"
else
	fail "README omits the Codex hook trust-approval requirement"
fi

if grep -q 'exit-code contract, not tested here' "$readme"; then
	fail "README still calls the Claude hook failure mode inferred rather than documented"
else
	pass "README states the Claude hook failure mode rather than inferring it"
fi

exit "$status"
