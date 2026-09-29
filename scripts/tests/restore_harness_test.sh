#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
restore="$repo_root/scripts/restore-harness.sh"
failures=0

fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }

if [ ! -x "$restore" ]; then
	echo "FAIL: $restore is missing or not executable"
	exit 1
fi

new_case() {
	work="$(mktemp -d)"
	pkg="$work/pkg"
	target="$work/target"
	mkdir -p "$pkg/hooks" "$target"
	printf 'repo\n' > "$pkg/settings.json"
	printf '#!/bin/sh\n' > "$pkg/hooks/run"
}

# The whole point: after unstowing, the pre-migration file comes back.
new_case
printf 'live\n' > "$target/settings.json.bak"
if "$restore" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ "$(cat "$target/settings.json")" = "live" ] \
	&& [ ! -e "$target/settings.json.bak" ]; then
	pass "a backup is restored to its live path"
else
	fail "a backup is restored to its live path"
fi

# No backup at all is the ordinary case for a fresh machine.
new_case
if "$restore" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ ! -e "$target/settings.json" ]; then
	pass "no backup is a no-op"
else
	fail "no backup is a no-op"
fi

# Something already occupies the live path: the backup is left where it is.
new_case
printf 'live\n' > "$target/settings.json.bak"
printf 'newer\n' > "$target/settings.json"
if "$restore" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ "$(cat "$target/settings.json")" = "newer" ] \
	&& [ "$(cat "$target/settings.json.bak")" = "live" ]; then
	pass "an occupied live path keeps its backup untouched"
else
	fail "an occupied live path keeps its backup untouched"
fi

# A surviving stow symlink counts as occupying the path.
new_case
printf 'live\n' > "$target/settings.json.bak"
ln -s "$pkg/settings.json" "$target/settings.json"
if "$restore" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ -L "$target/settings.json" ] \
	&& [ "$(cat "$target/settings.json.bak")" = "live" ]; then
	pass "a surviving symlink keeps its backup untouched"
else
	fail "a surviving symlink keeps its backup untouched"
fi

# Every file in the package is considered, not just the top level.
new_case
mkdir -p "$target/hooks"
printf 'live-hook\n' > "$target/hooks/run.bak"
if "$restore" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ "$(cat "$target/hooks/run")" = "live-hook" ]; then
	pass "nested package files are restored too"
else
	fail "nested package files are restored too"
fi

# A missing package directory is refused.
new_case
"$restore" "$work/absent" "$target" >/dev/null 2>&1
if [ $? -ne 0 ]; then
	pass "missing package is refused"
else
	fail "missing package is refused"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all restore-harness cases passed"
