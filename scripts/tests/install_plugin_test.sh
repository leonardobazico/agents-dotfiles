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
out="$(PATH="$bin:$PATH" "$script" gemini i-have-adhd ayghri/i-have-adhd 2>&1)"
if [ "$?" -ne 0 ] && printf '%s' "$out" | grep -q gemini && [ ! -s "$log" ]; then
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

# OpenCode has no plugin CLI. The installer clones the pinned source and copies
# the skill and command into OpenCode's global directories, so these cases drive
# a stub git over a fixture checkout instead of a stub harness CLI.
new_opencode_case() {
	new_case
	fixture="$work/fixture"
	cache="$work/cache"
	home="$work/home"
	mkdir -p "$fixture/skills/i-have-adhd" "$fixture/.opencode/command" "$home"
	printf 'ruleset %s\n' "$case_number" > "$fixture/skills/i-have-adhd/SKILL.md"
	printf 'command %s\n' "$case_number" > "$fixture/.opencode/command/i-have-adhd.md"
	cat > "$bin/git" <<SH
#!/bin/sh
printf 'git %s\n' "\$*" >> "$log"
if [ "\$1" = clone ]; then
	[ "\${CLONE_EXIT:-0}" -eq 0 ] || exit "\${CLONE_EXIT}"
	for dest; do :; done
	mkdir -p "\$dest/.git" && cp -R "$fixture/." "\$dest/"
	exit 0
fi
if [ "\$1" = -C ]; then
	[ "\${GIT_C_EXIT:-0}" -eq 0 ] || exit "\${GIT_C_EXIT}"
	cp -R "$fixture/." "\$2/"
	exit 0
fi
exit 0
SH
	chmod +x "$bin/git"
}

run_opencode() {
	env PATH="${OPENCODE_PATH:-$bin:$PATH}" HOME="$home" PLUGIN_CACHE_DIR="$cache" \
		"$script" opencode i-have-adhd "${1:-ayghri/i-have-adhd@v0.4.1}" > "$work/out" 2>&1
}

skill_dest() { printf '%s' "$home/.config/opencode/skills/i-have-adhd/SKILL.md"; }
command_dest() { printf '%s' "$home/.config/opencode/commands/i-have-adhd.md"; }

new_opencode_case
if run_opencode \
	&& grep -q '^git clone --quiet https://github.com/ayghri/i-have-adhd ' "$log" \
	&& grep -q 'checkout --quiet --force v0.4.1$' "$log" \
	&& [ "$(cat "$(skill_dest)")" = "ruleset $case_number" ] \
	&& [ "$(cat "$(command_dest)")" = "command $case_number" ]; then
	pass "opencode clones the pinned source and copies the skill and command"
else
	fail "opencode clones the pinned source and copies the skill and command"
	cat "$work/out" "$log"
fi

new_opencode_case
mkdir -p "$cache/i-have-adhd/.git"
if run_opencode \
	&& ! grep -q '^git clone' "$log" \
	&& grep -q 'fetch' "$log" \
	&& [ "$(cat "$(skill_dest)")" = "ruleset $case_number" ]; then
	pass "an existing checkout is fetched and reset rather than cloned"
else
	fail "an existing checkout is fetched and reset rather than cloned"
	cat "$work/out" "$log"
fi

new_opencode_case
if XDG_CONFIG_HOME="$work/xdg" run_opencode \
	&& [ -f "$work/xdg/opencode/skills/i-have-adhd/SKILL.md" ] \
	&& [ -f "$work/xdg/opencode/commands/i-have-adhd.md" ] \
	&& [ ! -e "$(skill_dest)" ]; then
	pass "XDG_CONFIG_HOME redirects both destinations"
else
	fail "XDG_CONFIG_HOME redirects both destinations"
	cat "$work/out"
fi

new_opencode_case
if run_opencode \
	&& [ ! -e "$home/.config/opencode/.i-have-adhd-always" ] \
	&& [ ! -e "$home/.config/opencode/opencode.json" ]; then
	pass "no always-on flag and no opencode.json write"
else
	fail "no always-on flag and no opencode.json write"
	cat "$work/out"
fi

new_opencode_case
out="$(CLONE_EXIT=1 run_opencode; cat "$work/out")"
if [ ! -e "$(skill_dest)" ] && printf '%s' "$out" | grep -q clone; then
	pass "a clone failure names the stage and copies nothing"
else
	fail "a clone failure names the stage and copies nothing (got: $out)"
fi

new_opencode_case
mkdir -p "$cache/i-have-adhd/.git"
out="$(GIT_C_EXIT=1 run_opencode; cat "$work/out")"
if [ ! -e "$(skill_dest)" ] && printf '%s' "$out" | grep -qE 'fetch|checkout'; then
	pass "a failed update of an existing checkout names the stage and copies nothing"
else
	fail "a failed update of an existing checkout names the stage and copies nothing (got: $out)"
fi

# The stub git is removed by shadowing PATH entirely: a real git on PATH would
# turn this case into a network clone instead of the missing-binary check.
new_opencode_case
gitless_bin="$work/gitless-bin"
mkdir -p "$gitless_bin"
for tool in env bash sh grep awk cp mv mkdir dirname cmp; do
	ln -sf "$(command -v "$tool")" "$gitless_bin/$tool" 2>/dev/null || true
done
out="$(OPENCODE_PATH="$gitless_bin" run_opencode; cat "$work/out")"
if [ ! -e "$(skill_dest)" ] && printf '%s' "$out" | grep -q git; then
	pass "a missing git fails naming it"
else
	fail "a missing git fails naming it (got: $out)"
fi

new_opencode_case
rm -f "$fixture/.opencode/command/i-have-adhd.md"
out="$(run_opencode; cat "$work/out")"
if [ ! -e "$(command_dest)" ] && printf '%s' "$out" | grep -q 'i-have-adhd.md'; then
	pass "a source file missing from the checkout fails naming it"
else
	fail "a source file missing from the checkout fails naming it (got: $out)"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all install-plugin cases passed"
