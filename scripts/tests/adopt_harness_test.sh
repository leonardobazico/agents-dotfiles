#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
adopt="$repo_root/scripts/adopt-harness.sh"
failures=0

fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }

if [ ! -x "$adopt" ]; then
	echo "FAIL: $adopt is missing or not executable"
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

# Case 1: nothing at the target is left alone and succeeds.
new_case
if "$adopt" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ ! -e "$target/settings.json" ] \
	&& [ ! -e "$target/settings.json.bak" ]; then
	pass "absent target is a no-op"
else
	fail "absent target is a no-op"
fi

# Case 2: a real file is moved aside.
new_case
printf 'live\n' > "$target/settings.json"
if "$adopt" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ ! -e "$target/settings.json" ] \
	&& [ "$(cat "$target/settings.json.bak")" = "live" ]; then
	pass "real file is backed up"
else
	fail "real file is backed up"
fi

# Case 3: a symlink already resolving into the repo is left alone.
new_case
ln -s "$repo_root/Makefile" "$target/settings.json"
if "$adopt" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ -L "$target/settings.json" ] \
	&& [ ! -e "$target/settings.json.bak" ]; then
	pass "adopted symlink is left alone"
else
	fail "adopted symlink is left alone"
fi

# Case 4: an existing backup is never overwritten.
new_case
printf 'older\n' > "$target/settings.json.bak"
printf 'live\n' > "$target/settings.json"
"$adopt" "$pkg" "$target" >/dev/null 2>&1
if [ $? -ne 0 ] \
	&& [ "$(cat "$target/settings.json.bak")" = "older" ] \
	&& [ "$(cat "$target/settings.json")" = "live" ]; then
	pass "existing backup is preserved"
else
	fail "existing backup is preserved"
fi

# Case 5: a symlink pointing outside the repo fails loudly.
new_case
ln -s /etc/hosts "$target/settings.json"
"$adopt" "$pkg" "$target" >/dev/null 2>&1
if [ $? -ne 0 ] && [ ! -e "$target/settings.json.bak" ]; then
	pass "foreign symlink fails loudly"
else
	fail "foreign symlink fails loudly"
fi

# Review Focus 1: a real directory at a package directory path is not adopted.
new_case
mkdir -p "$target/hooks"
printf 'other\n' > "$target/hooks/unrelated"
if "$adopt" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ -d "$target/hooks" ] \
	&& [ ! -e "$target/hooks.bak" ] \
	&& [ -f "$target/hooks/unrelated" ]; then
	pass "target directory is not adopted"
else
	fail "target directory is not adopted"
fi

# Review Focus 2: a dangling symlink fails loudly rather than being moved.
new_case
ln -s "$work/missing" "$target/settings.json"
"$adopt" "$pkg" "$target" >/dev/null 2>&1
if [ $? -ne 0 ] && [ ! -e "$target/settings.json.bak" ]; then
	pass "dangling symlink fails loudly"
else
	fail "dangling symlink fails loudly"
fi

# Review Focus 3: ownership is decided on the fully resolved path.
new_case
ln -s "$repo_root" "$work/alias"
ln -s "$work/alias/Makefile" "$target/settings.json"
if "$adopt" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ -L "$target/settings.json" ] \
	&& [ ! -e "$target/settings.json.bak" ]; then
	pass "multi-hop symlink into the repo is left alone"
else
	fail "multi-hop symlink into the repo is left alone"
fi

# A missing package directory is refused.
new_case
"$adopt" "$work/absent" "$target" >/dev/null 2>&1
if [ $? -ne 0 ]; then
	pass "missing package is refused"
else
	fail "missing package is refused"
fi

# A dangling backup symlink still counts as an existing backup.
new_case
printf 'live\n' > "$target/settings.json"
ln -s "$work/gone" "$target/settings.json.bak"
"$adopt" "$pkg" "$target" >/dev/null 2>&1
if [ $? -ne 0 ] \
	&& [ -L "$target/settings.json.bak" ] \
	&& [ "$(cat "$target/settings.json")" = "live" ]; then
	pass "dangling backup is not overwritten"
else
	fail "dangling backup is not overwritten"
fi

# A refusal anywhere in the package moves nothing at all (all-or-nothing).
new_case
printf 'live\n' > "$target/settings.json"
mkdir -p "$target/hooks"
ln -s /etc/hosts "$target/hooks/run"
"$adopt" "$pkg" "$target" >/dev/null 2>&1
if [ $? -ne 0 ] \
	&& [ -f "$target/settings.json" ] \
	&& [ "$(cat "$target/settings.json")" = "live" ] \
	&& [ ! -e "$target/settings.json.bak" ]; then
	pass "a refusal leaves every other file untouched"
else
	fail "a refusal leaves every other file untouched"
fi

# Ownership is decided against the physical repo root, not the logical one.
new_case
ln -s "$repo_root" "$work/alias"
ln -s "$repo_root/Makefile" "$target/settings.json"
if "$work/alias/scripts/adopt-harness.sh" "$pkg" "$target" >/dev/null 2>&1 \
	&& [ -L "$target/settings.json" ] \
	&& [ ! -e "$target/settings.json.bak" ]; then
	pass "reached through a symlinked repo path, an adopted link is still recognised"
else
	fail "reached through a symlinked repo path, an adopted link is still recognised"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all adopt-harness cases passed"
