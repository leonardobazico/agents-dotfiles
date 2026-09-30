#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
script="$repo_root/scripts/install-plugins.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
failures=0
case_number=0

pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }

# A stub installer records the arguments of every row acted on, so the manifest
# can be asserted without touching a harness CLI.
new_case() {
	case_number=$((case_number + 1))
	work="$test_root/case-$case_number"
	mkdir -p "$work"
	manifest="$work/manifest.tsv"
	log="$work/installer.log"
	installer="$work/install-plugin.sh"
	: > "$log"
	cat > "$installer" <<SH
#!/bin/sh
printf '%s\n' "\$*" >> "$log"
exit "\${INSTALLER_EXIT:-0}"
SH
	chmod +x "$installer"
}

run_script() { PLUGIN_MANIFEST="$manifest" PLUGIN_INSTALLER="$installer" "$script" 2>&1; }

new_case
printf '# plugin\tharness\tsource\tinstall\n' > "$manifest"
printf 'i-have-adhd\tclaude\tayghri/i-have-adhd\tauto\n' >> "$manifest"
printf '\n' >> "$manifest"
printf 'i-have-adhd\tcodex\tayghri/i-have-adhd@main\tauto\n' >> "$manifest"
out="$(run_script)"
if [ "$?" -eq 0 ] \
	&& grep -qx 'claude i-have-adhd ayghri/i-have-adhd' "$log" \
	&& grep -qx 'codex i-have-adhd ayghri/i-have-adhd@main' "$log" \
	&& [ "$(wc -l < "$log")" -eq 2 ]; then
	pass "auto rows are installed as harness, plugin, source, skipping comments and blanks"
else
	fail "auto rows are installed as harness, plugin, source (got: $out; log: $(cat "$log"))"
fi

new_case
printf 'superpowers\tclaude\tclaude-plugins-official\tmanual\n' > "$manifest"
printf 'i-have-adhd\topencode\t-\tskip\n' >> "$manifest"
out="$(run_script)"
if [ "$?" -eq 0 ] && [ ! -s "$log" ]; then
	pass "manual and skip rows are recorded without being installed"
else
	fail "manual and skip rows are recorded without being installed (got: $out)"
fi

new_case
printf 'i-have-adhd\tclaude\tauto\n' > "$manifest"
out="$(run_script)"
if [ "$?" -ne 0 ] && printf '%s' "$out" | grep -q 'manifest.tsv:1' \
	&& printf '%s' "$out" | grep -q '4 tab-separated columns' && [ ! -s "$log" ]; then
	pass "a three-column row fails naming the file and line"
else
	fail "a three-column row fails naming the file and line (got: $out)"
fi

new_case
printf 'i-have-adhd claude ayghri/i-have-adhd auto\n' > "$manifest"
out="$(run_script)"
if [ "$?" -ne 0 ] && printf '%s' "$out" | grep -q 'manifest.tsv:1' && [ ! -s "$log" ]; then
	pass "a space-separated row fails instead of installing nothing quietly"
else
	fail "a space-separated row fails instead of installing nothing quietly (got: $out)"
fi

new_case
printf 'i-have-adhd\tclaude\tayghri/i-have-adhd\tatuo\n' > "$manifest"
out="$(run_script)"
if [ "$?" -ne 0 ] && printf '%s' "$out" | grep -q 'atuo' && [ ! -s "$log" ]; then
	pass "an unknown install value fails naming the value"
else
	fail "an unknown install value fails naming the value (got: $out)"
fi

new_case
printf 'i-have-adhd\tclaude\tayghri/i-have-adhd\tauto\n' > "$manifest"
printf 'i-have-adhd\tcodex\tayghri/i-have-adhd@main\tauto\n' >> "$manifest"
if INSTALLER_EXIT=1 PLUGIN_MANIFEST="$manifest" PLUGIN_INSTALLER="$installer" "$script" >/dev/null 2>&1; then
	fail "a failing row fails the run"
else
	if [ "$(wc -l < "$log")" -eq 2 ]; then
		pass "a failing row fails the run after every other row is attempted"
	else
		fail "a failing row stops later rows (log: $(cat "$log"))"
	fi
fi

new_case
out="$(PLUGIN_MANIFEST="$work/absent.tsv" PLUGIN_INSTALLER="$installer" "$script" 2>&1)"
if [ "$?" -ne 0 ] && printf '%s' "$out" | grep -q 'absent.tsv'; then
	pass "a missing manifest fails naming the path"
else
	fail "a missing manifest fails naming the path (got: $out)"
fi

new_case
if PLUGIN_INSTALLER="$installer" "$script" >/dev/null 2>&1 \
	&& grep -qx 'claude i-have-adhd ayghri/i-have-adhd' "$log" \
	&& grep -qx 'codex i-have-adhd ayghri/i-have-adhd@main' "$log"; then
	pass "the committed manifest resolves by default and marks both i-have-adhd rows auto"
else
	fail "the committed manifest resolves by default (log: $(cat "$log"))"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all install-plugins cases passed"
