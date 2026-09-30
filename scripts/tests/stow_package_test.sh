#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
stow_package="$repo_root/scripts/stow-package.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
failures=0
case_number=0

pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }

new_case() {
	case_number=$((case_number + 1))
	work="$test_root/case-$case_number"
	package="$work/packages/demo"
	target="$work/target"
	output="$work/output"
	mkdir -p "$package/sub"
	package="$(cd "$package" && pwd -P)"
	printf 'OWNED A\n' > "$package/a.txt"
	printf 'OWNED B\n' > "$package/sub/b.txt"
}

resolves_to() {
	[ -L "$1" ] && [ "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1")" = "$2" ]
}

new_case
if "$stow_package" link "$package" "$target" > "$output" 2>&1 \
	&& resolves_to "$target/a.txt" "$package/a.txt" \
	&& resolves_to "$target/sub/b.txt" "$package/sub/b.txt"; then
	pass "link creates the target directory and links every package file"
else
	fail "link creates the target directory and links every package file"
	cat "$output"
fi

new_case
if "$stow_package" link "$package" "$target" > "$output" 2>&1 \
	&& [ -d "$target/sub" ] && [ ! -L "$target/sub" ]; then
	pass "link keeps package subdirectories as real directories in the target"
else
	fail "link keeps package subdirectories as real directories in the target"
	cat "$output"
fi

new_case
mkdir -p "$target"
printf 'LIVE\n' > "$target/a.txt"
if "$stow_package" link "$package" "$target" > "$output" 2>&1 \
	&& [ "$(cat "$target/a.txt.bak")" = LIVE ] \
	&& resolves_to "$target/a.txt" "$package/a.txt"; then
	pass "link adopts a real live file to .bak before stowing"
else
	fail "link adopts a real live file to .bak before stowing"
	cat "$output"
fi

new_case
mkdir -p "$target"
printf 'LIVE\n' > "$target/a.txt"
if "$stow_package" link "$package" "$target" > "$output" 2>&1 \
	&& "$stow_package" unlink "$package" "$target" > "$output" 2>&1 \
	&& [ ! -L "$target/a.txt" ] && [ "$(cat "$target/a.txt")" = LIVE ] \
	&& [ ! -e "$target/a.txt.bak" ]; then
	pass "unlink removes the links and restores the adopted backup"
else
	fail "unlink removes the links and restores the adopted backup"
	cat "$output"
fi

new_case
if "$stow_package" link "$package" "$target" > "$output" 2>&1 \
	&& "$stow_package" relink "$package" "$target" > "$output" 2>&1 \
	&& resolves_to "$target/a.txt" "$package/a.txt"; then
	pass "relink leaves an already-linked package linked"
else
	fail "relink leaves an already-linked package linked"
	cat "$output"
fi

new_case
mkdir -p "$target"
ln -s /etc/hosts "$target/a.txt"
if ! "$stow_package" link "$package" "$target" > "$output" 2>&1 \
	&& [ "$(readlink "$target/a.txt")" = /etc/hosts ] \
	&& [ ! -e "$target/sub" ]; then
	pass "link refuses a foreign symlink and stows nothing"
else
	fail "link refuses a foreign symlink and stows nothing"
	cat "$output"
fi

new_case
if ! "$stow_package" resurrect "$package" "$target" > "$output" 2>&1 \
	&& grep -q 'resurrect' "$output"; then
	pass "an unknown action fails and names the action"
else
	fail "an unknown action fails and names the action"
	cat "$output"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all stow-package cases passed"
