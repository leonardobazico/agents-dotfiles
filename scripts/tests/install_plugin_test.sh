#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
script="$repo_root/scripts/install-plugin.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
failures=0
case_number=0

pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }

# Each case gets its own stub directory and log. ADD_EXIT controls whether the
# marketplace-add step reports failure; LIST_MARKETPLACE and LIST_PLUGIN supply
# what the harness's own listing reports back.
new_case() {
	case_number=$((case_number + 1))
	work="$test_root/case-$case_number"
	bin="$work/bin"
	log="$work/cli.log"
	mkdir -p "$bin"
	: > "$log"
	for cli in claude codex; do
		cat > "$bin/$cli" <<SH
#!/bin/sh
printf '%s %s\n' "$cli" "\$*" >> "$log"
case "\$*" in
*"marketplace list"*) printf '%s\n' "\${LIST_MARKETPLACE:-}" ; exit 0 ;;
*"plugin list"*) printf '%s\n' "\${LIST_PLUGIN:-}" ; exit 0 ;;
*"marketplace add"*) exit "\${ADD_EXIT:-0}" ;;
*"plugin add"* | *"plugin install"*) exit "\${PLUGIN_EXIT:-0}" ;;
esac
exit 0
SH
		chmod +x "$bin/$cli"
	done
}

new_case
if PATH="$bin:$PATH" "$script" claude i-have-adhd ayghri/i-have-adhd > "$work/out" 2>&1 \
	&& grep -q '^claude plugin marketplace add ayghri/i-have-adhd --scope user$' "$log" \
	&& grep -q '^claude plugin install i-have-adhd@i-have-adhd --scope user --yes$' "$log"; then
	pass "claude gets marketplace add then install with the derived selector"
else
	fail "claude gets marketplace add then install with the derived selector"
	cat "$work/out" "$log"
fi

new_case
if PATH="$bin:$PATH" "$script" codex i-have-adhd ayghri/i-have-adhd@main > "$work/out" 2>&1 \
	&& grep -q '^codex plugin marketplace add ayghri/i-have-adhd@main$' "$log" \
	&& grep -q '^codex plugin add i-have-adhd@i-have-adhd$' "$log"; then
	pass "codex gets the source verbatim and a selector with the ref stripped"
else
	fail "codex gets the source verbatim and a selector with the ref stripped"
	cat "$work/out" "$log"
fi

new_case
out="$(PATH="$bin:$PATH" "$script" opencode i-have-adhd ayghri/i-have-adhd 2>&1)"
if [ "$?" -ne 0 ] && printf '%s' "$out" | grep -q opencode && [ ! -s "$log" ]; then
	pass "an unsupported harness fails naming it and runs no command"
else
	fail "an unsupported harness fails naming it and runs no command (got: $out)"
fi

for bad_source in not-a-repo owner/ a/b/c https://github.com/owner/repo.git /etc/passwd; do
	new_case
	out="$(PATH="$bin:$PATH" "$script" claude someplug "$bad_source" 2>&1)"
	if [ "$?" -ne 0 ] && printf '%s' "$out" | grep -qF "$bad_source" && [ ! -s "$log" ]; then
		pass "source '$bad_source' fails naming the source"
	else
		fail "source '$bad_source' fails naming the source (got: $out)"
	fi
done

new_case
empty_bin="$work/empty-bin"
mkdir -p "$empty_bin"
for tool in env bash sh grep awk; do
	ln -sf "$(command -v "$tool")" "$empty_bin/$tool" 2>/dev/null || true
done
out="$(PATH="$empty_bin" "$script" codex i-have-adhd ayghri/i-have-adhd@main 2>&1)"
if [ "$?" -ne 0 ] && printf '%s' "$out" | grep -q codex \
	&& printf '%s' "$out" | grep -q 'install-dependencies'; then
	pass "a missing harness CLI fails naming the harness and the setup target"
else
	fail "a missing harness CLI fails naming the harness and the setup target (got: $out)"
fi

new_case
if ADD_EXIT=1 LIST_MARKETPLACE='    Source: GitHub (ayghri/i-have-adhd)' \
	PATH="$bin:$PATH" "$script" claude i-have-adhd ayghri/i-have-adhd > "$work/out" 2>&1 \
	&& grep -q '^claude plugin install i-have-adhd@i-have-adhd --scope user --yes$' "$log"; then
	pass "a failed marketplace add is accepted when the listing shows it present"
else
	fail "a failed marketplace add is accepted when the listing shows it present"
	cat "$work/out" "$log"
fi

new_case
if ADD_EXIT=1 LIST_MARKETPLACE='' \
	PATH="$bin:$PATH" "$script" claude i-have-adhd ayghri/i-have-adhd >/dev/null 2>&1; then
	fail "a failed marketplace add absent from the listing fails the run"
else
	pass "a failed marketplace add absent from the listing fails the run"
fi

new_case
if PLUGIN_EXIT=1 LIST_PLUGIN='i-have-adhd@i-have-adhd  installed  0.3.0  src' \
	PATH="$bin:$PATH" "$script" codex i-have-adhd ayghri/i-have-adhd@main >/dev/null 2>&1; then
	pass "a failed codex install is accepted when the listing shows it installed"
else
	fail "a failed codex install is accepted when the listing shows it installed"
	cat "$log"
fi

# The status column is the whole point of the awk guard: a row that exists but
# reads "not installed" is not the state the install step was meant to create.
new_case
if PLUGIN_EXIT=1 LIST_PLUGIN='i-have-adhd@i-have-adhd  not installed  0.3.0  src' \
	PATH="$bin:$PATH" "$script" codex i-have-adhd ayghri/i-have-adhd@main >/dev/null 2>&1; then
	fail "a failed codex install listed as not installed fails the run"
else
	pass "a failed codex install listed as not installed fails the run"
fi

new_case
if PLUGIN_EXIT=1 LIST_PLUGIN='' \
	PATH="$bin:$PATH" "$script" claude i-have-adhd ayghri/i-have-adhd >/dev/null 2>&1; then
	fail "a failed claude install absent from the listing fails the run"
else
	pass "a failed claude install absent from the listing fails the run"
fi

# A plugin whose selector is a substring of an installed one is a different
# plugin, so a failed install of it must not be accepted.
new_case
if PLUGIN_EXIT=1 LIST_PLUGIN='  > i-have-adhd@i-have-adhd' \
	PATH="$bin:$PATH" "$script" claude adhd ayghri/i-have-adhd >/dev/null 2>&1; then
	fail "a failed claude install is not accepted on a substring match of another plugin"
else
	pass "a failed claude install is not accepted on a substring match of another plugin"
fi

new_case
if PLUGIN_EXIT=1 LIST_PLUGIN='  > i-have-adhd@i-have-adhd' \
	PATH="$bin:$PATH" "$script" claude i-have-adhd ayghri/i-have-adhd >/dev/null 2>&1; then
	pass "a failed claude install is accepted when the listing shows that selector"
else
	fail "a failed claude install is accepted when the listing shows that selector"
fi

new_case
if ADD_EXIT=1 LIST_MARKETPLACE="$(printf 'MARKETPLACE\tROOT\ni-have-adhd\t/tmp/x')" \
	PATH="$bin:$PATH" "$script" codex i-have-adhd ayghri/i-have-adhd@main > "$work/out" 2>&1 \
	&& grep -q '^codex plugin add i-have-adhd@i-have-adhd$' "$log"; then
	pass "a failed codex marketplace add is accepted when the listing shows the marketplace"
else
	fail "a failed codex marketplace add is accepted when the listing shows the marketplace"
	cat "$work/out" "$log"
fi

new_case
if ADD_EXIT=1 LIST_MARKETPLACE='MARKETPLACE	ROOT' \
	PATH="$bin:$PATH" "$script" codex i-have-adhd ayghri/i-have-adhd@main >/dev/null 2>&1; then
	fail "a codex listing holding only its header is not a present marketplace"
else
	pass "a codex listing holding only its header is not a present marketplace"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all install-plugin cases passed"
