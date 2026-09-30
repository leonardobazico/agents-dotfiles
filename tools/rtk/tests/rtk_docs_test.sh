#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"

status=0
pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1" >&2; status=1; }

section="$(python3 -c '
import sys
text = open(sys.argv[1], encoding="utf-8").read()
start = text.index("## Running Commands")
print(text[start:text.index("\n## ", start)])' "$repo_root/shared/agents-md/AGENTS.md")"

if printf '%s' "$section" | grep -qi 'not installed\|absent\|no-op'; then
	pass "Running Commands covers the machine where rtk is not installed"
else
	fail "Running Commands claims output is condensed without covering an rtk-less machine"
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
