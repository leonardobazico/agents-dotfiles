#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
failures=0

fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }

# Every harness target that stows must adopt first, or a live real file becomes a
# stow conflict instead of a backup.
for target in link-harnesses relink-harnesses; do
	plan="$(make -C "$repo_root" -n "$target" HARNESSES=claude TARGET_claude=/tmp/probe 2>&1)"
	if printf '%s' "$plan" | grep -q 'adopt-harness.sh'; then
		pass "$target adopts before stowing"
	else
		fail "$target adopts before stowing"
	fi
done

# A dry run of the meta targets must expand the recipes it delegates to, so the
# commands can be inspected before any of them run.
plan="$(make -C "$repo_root" -n link-all HARNESSES=claude TARGET_claude=/tmp/probe 2>&1)"
if printf '%s' "$plan" | grep -q 'adopt-harness.sh'; then
	pass "make -n link-all expands the harness commands"
else
	fail "make -n link-all expands the harness commands"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all makefile target cases passed"
