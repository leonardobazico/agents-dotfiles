#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
script="$repo_root/scripts/install-dependencies.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
failures=0

pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }

# A stub brew records every invocation so the package lists can be asserted
# without installing anything.
make_brew_stub() {
	local dir="$1" exit_code="$2"
	mkdir -p "$dir"
	cat > "$dir/brew" <<SH
#!/bin/sh
printf '%s\n' "\$*" >> "\$BREW_LOG"
exit $exit_code
SH
	chmod +x "$dir/brew"
}

bin="$test_root/bin"
make_brew_stub "$bin" 0
log="$test_root/brew.log"

if BREW_LOG="$log" PATH="$bin:$PATH" "$script" > "$test_root/out" 2>&1; then
	pass "install-dependencies.sh exits 0 when brew succeeds"
else
	fail "install-dependencies.sh exits 0 when brew succeeds"
	cat "$test_root/out"
fi

for formula in opencode stow gitleaks pre-commit; do
	if grep -q "^install .*\\b$formula\\b" "$log" && ! grep -q "^install --cask .*\\b$formula\\b" "$log"; then
		pass "$formula is installed as a formula"
	else
		fail "$formula is installed as a formula"
	fi
done

for cask in claude-code codex; do
	if grep -q "^install --cask .*\\b$cask\\b" "$log"; then
		pass "$cask is installed as a cask"
	else
		fail "$cask is installed as a cask"
	fi
done

if [ "$(grep -c '^install' "$log")" -eq 2 ]; then
	pass "brew is invoked once per kind"
else
	fail "brew is invoked once per kind (got $(grep -c '^install' "$log"))"
fi

# A real brew failure must not be swallowed.
failing_bin="$test_root/failing-bin"
make_brew_stub "$failing_bin" 1
if BREW_LOG="$test_root/failing.log" PATH="$failing_bin:$PATH" "$script" >/dev/null 2>&1; then
	fail "a brew failure propagates"
else
	pass "a brew failure propagates"
fi

# Homebrew absent must name Homebrew, not exit 127 from a bare command.
empty_bin="$test_root/empty-bin"
mkdir -p "$empty_bin"
for tool in env bash sh grep; do
	ln -sf "$(command -v "$tool")" "$empty_bin/$tool" 2>/dev/null || true
done
out="$(PATH="$empty_bin" "$script" 2>&1)"
if [ "$?" -ne 0 ] && printf '%s' "$out" | grep -qi 'homebrew'; then
	pass "a missing brew fails naming Homebrew"
else
	fail "a missing brew fails naming Homebrew (got: $out)"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all install-dependencies cases passed"
