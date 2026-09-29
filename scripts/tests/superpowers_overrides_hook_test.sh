#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
hook_src="$repo_root/harnesses/claude/hooks/superpowers-overrides"
failures=0

fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }

if [ ! -x "$hook_src" ]; then
	echo "FAIL: $hook_src is missing or not executable"
	exit 1
fi

work="$(mktemp -d)"
mkdir -p "$work/hooks"
cp "$hook_src" "$work/hooks/superpowers-overrides"
chmod +x "$work/hooks/superpowers-overrides"

# Review Focus 4: JSON-hostile characters survive intact.
printf '%s\n' \
	'# Overrides' \
	'' \
	'A "quoted" phrase, a back\slash, and non-ASCII: precedencia.' \
	'' \
	'- Tab:	here' > "$work/superpowers-overrides.md"

"$work/hooks/superpowers-overrides" > "$work/out.json" 2>/dev/null

check_json='
import json, sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
with open(sys.argv[2], encoding="utf-8") as handle:
    expected = handle.read()

out = payload["hookSpecificOutput"]
assert out["hookEventName"] == "SessionStart", "wrong event name"
assert out["additionalContext"] == expected, "context does not match the markdown byte for byte"
'

if python3 -c "$check_json" "$work/out.json" "$work/superpowers-overrides.md"; then
	pass "emits valid JSON preserving the markdown exactly"
else
	fail "emits valid JSON preserving the markdown exactly"
fi

# A missing markdown file must not break session start.
mv "$work/superpowers-overrides.md" "$work/elsewhere.md"
out="$("$work/hooks/superpowers-overrides" 2>/dev/null)"
status=$?
if [ $status -eq 0 ] && [ -z "$out" ]; then
	pass "exits 0 silently when the markdown is missing"
else
	fail "exits 0 silently when the markdown is missing"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all superpowers-overrides hook cases passed"
