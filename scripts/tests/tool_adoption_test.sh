#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
adopt="$repo_root/scripts/adopt-harness.sh"

status=0
pass() { echo "ok - $1"; }
fail() { echo "not ok - $1" >&2; status=1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/outgoing" "$work/incoming" "$work/target"
printf '{}\n' > "$work/outgoing/hooks.json"
printf '{}\n' > "$work/incoming/hooks.json"
ln -s "$work/outgoing/hooks.json" "$work/target/hooks.json"

if output="$("$adopt" "$work/incoming" "$work/target" 2>&1)"; then
	fail "adoption refuses a path owned by another package"
else
	if printf '%s' "$output" | grep -q 'is a symlink to' \
		&& printf '%s' "$output" | grep -q "$work/outgoing/hooks.json" \
		&& printf '%s' "$output" | grep -q "$work/incoming/hooks.json"; then
		pass "adoption refuses a path owned by another package and names both"
	else
		fail "adoption refusal names both paths (got: $output)"
	fi
fi

if [ -L "$work/target/hooks.json" ] && [ ! -e "$work/target/hooks.json.bak" ]; then
	pass "refusal changed nothing"
else
	fail "refusal changed nothing"
fi

rm "$work/target/hooks.json"
if "$adopt" "$work/incoming" "$work/target" >/dev/null 2>&1 \
	&& [ ! -e "$work/target/hooks.json" ]; then
	pass "adoption of an absent path is a no-op"
else
	fail "adoption of an absent path is a no-op"
fi

exit "$status"
