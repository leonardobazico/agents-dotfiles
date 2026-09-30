#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
failures=0
case_number=0
invocation=0

pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

mkdir -p "$test_root/bin"
cat > "$test_root/bin/rtk" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "${PROBE_FAIL:-0}" != 0 ]; then
	exit "$PROBE_FAIL"
fi
case "$*" in
	*--opencode*)
		mkdir -p "$HOME/.config/opencode/plugins"
		printf 'plugin\n' > "$HOME/.config/opencode/plugins/rtk.ts"
		;;
	*--uninstall*)
		cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.bak"
		rm -f "$HOME/.config/opencode/plugins/rtk.ts"
		;;
	*) cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.bak" ;;
esac
SH
cat > "$test_root/bin/date" <<'SH'
#!/bin/sh
printf '%s\n' "$PROBE_STAMP"
SH
cat > "$test_root/bin/brew" <<'SH'
#!/bin/sh
printf 'unexpected\n' > "$PROBE_UNEXPECTED"
exit 99
SH
chmod +x "$test_root/bin/rtk" "$test_root/bin/date" "$test_root/bin/brew"

new_case() {
	case_number=$((case_number + 1))
	work="$test_root/case-$case_number"
	case_home="$work/home"
	codex_target="$work/custom-codex"
	output="$work/output"
	probe_fail=0
	mkdir -p "$case_home/.claude" "$codex_target" "$work/unrelated-claude" "$work/unrelated-opencode"
	printf '{"hooks":{}}\n' > "$case_home/.claude/settings.json"
	printf 'CLAUDE SENTINEL\n' > "$work/unrelated-claude/settings.json"
	printf 'OPENCODE SENTINEL\n' > "$work/unrelated-opencode/opencode.json"
}

run_make() {
	invocation=$((invocation + 1))
	HOME="$case_home" PATH="$test_root/bin:$PATH" PROBE_FAIL="$probe_fail" \
		PROBE_STAMP="20260930T1200$(printf '%02d' "$invocation")Z" \
		PROBE_UNEXPECTED="$work/unexpected" \
		make -C "$repo_root" TOOLS=rtk "$@" "TARGET_rtk_codex=$codex_target" \
		"TARGET_claude=$work/unrelated-claude" "TARGET_opencode=$work/unrelated-opencode" \
		> "$output" 2>&1
}

has_owned_links() {
	[ -L "$codex_target/hooks.json" ] \
		&& [ "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$codex_target/hooks.json")" = "$repo_root/tools/rtk/codex/hooks.json" ]
}

new_case
if run_make setup-rtk && has_owned_links \
	&& run_make teardown-rtk && [ ! -e "$codex_target/hooks.json" ] \
	&& run_make setup-rtk && has_owned_links; then
	pass "setup-teardown-setup manages only the Codex package"
else
	fail "setup-teardown-setup manages only the Codex package"
fi

new_case
printf '{"user":"original"}\n' > "$codex_target/hooks.json"
cp "$codex_target/hooks.json" "$work/original"
if run_make setup-rtk && has_owned_links && cmp -s "$work/original" "$codex_target/hooks.json.bak" \
	&& run_make teardown-rtk && [ ! -L "$codex_target/hooks.json" ] \
	&& cmp -s "$work/original" "$codex_target/hooks.json" && [ ! -e "$codex_target/hooks.json.bak" ]; then
	pass "teardown restores adopted hooks byte for byte"
else
	fail "teardown restores adopted hooks byte for byte"
fi

for conflict in symlink backup; do
	new_case
	if [ "$conflict" = symlink ]; then
		ln -s /etc/hosts "$codex_target/hooks.json"
	else
		printf 'LIVE\n' > "$codex_target/hooks.json"
		printf 'OLDER\n' > "$codex_target/hooks.json.bak"
	fi
	if ! run_make setup-rtk && grep -qi 'partial' "$output" \
		&& [ ! -e "$codex_target/hooks" ]; then
		if [ "$conflict" = symlink ] && [ "$(readlink "$codex_target/hooks.json")" = /etc/hosts ]; then
			pass "foreign hook symlink is preserved with partial-setup diagnostic"
		elif [ "$conflict" = backup ] && [ "$(cat "$codex_target/hooks.json")" = LIVE ] \
			&& [ "$(cat "$codex_target/hooks.json.bak")" = OLDER ]; then
			pass "existing hook backup is preserved with partial-setup diagnostic"
		else
			fail "$conflict conflict preserves existing files"
		fi
	else
		fail "$conflict conflict fails setup"
	fi
done

new_case
probe_fail=23
if ! run_make setup-rtk && [ ! -L "$codex_target/hooks.json" ]; then
	pass "failed rtk setup does not link Codex"
else
	fail "failed rtk setup does not link Codex"
fi
probe_fail=0
if run_make setup-rtk && has_owned_links; then
	probe_fail=23
	if ! run_make teardown-rtk && has_owned_links; then
		pass "failed rtk uninstall does not unlink Codex"
	else
		fail "failed rtk uninstall does not unlink Codex"
	fi
else
	fail "prepare failed-uninstall case"
fi

new_case
if run_make setup-rtk && has_owned_links && [ ! -e "$case_home/.codex" ] \
	&& [ "$(cat "$work/unrelated-claude/settings.json")" = 'CLAUDE SENTINEL' ] \
	&& [ "$(cat "$work/unrelated-opencode/opencode.json")" = 'OPENCODE SENTINEL' ] \
	&& [ -f "$case_home/.config/opencode/plugins/rtk.ts" ]; then
	pass "Codex override leaves default Codex and unrelated sentinels unchanged"
else
	fail "Codex override leaves default Codex and unrelated sentinels unchanged"
fi

new_case
printf 'LIVE\n' > "$codex_target/hooks.json"
printf 'BACKUP\n' > "$codex_target/hooks.json.bak"
if "$repo_root/scripts/restore-harness.sh" "$repo_root/tools/rtk/codex" "$codex_target" > "$output" 2>&1 \
	&& [ "$(cat "$codex_target/hooks.json")" = LIVE ] && [ "$(cat "$codex_target/hooks.json.bak")" = BACKUP ] \
	&& grep -q 'leaving' "$output"; then
	pass "direct restoration preserves occupied live path and backup"
else
	fail "direct restoration preserves occupied live path and backup"
fi

new_case
printf 'ORIGINAL\n' > "$codex_target/hooks.json"
if run_make setup-rtk && has_owned_links; then
	mv "$codex_target" "$work/displaced-codex"
	printf 'OBSTRUCTION\n' > "$codex_target"
	if ! run_make teardown-rtk && grep -qi 'partial' "$output" \
		&& [ "$(cat "$work/displaced-codex/hooks.json.bak")" = ORIGINAL ]; then
		pass "failed unstow preserves adopted backup and reports partial teardown"
	else
		fail "failed unstow preserves adopted backup"
		cat "$output"
	fi
else
	fail "prepare unstow failure case"
fi

new_case
if run_make setup-rtk && run_make teardown-rtk; then
	cat > "$work/refuse-rtk" <<'SH'
#!/bin/sh
printf 'unexpected\n' > "$PROBE_UNEXPECTED"
exit 99
SH
	chmod +x "$work/refuse-rtk"
	ln -sf "$work/refuse-rtk" "$test_root/bin/rtk"
	if run_make link-all HARNESSES=claude "AGENTS_MD_TARGETS=$work/agents" "SKILLS_TARGETS=$work/skills" \
		&& [ ! -e "$codex_target/hooks.json" ] && [ ! -e "$work/unexpected" ]; then
		pass "link-all leaves the rtk tool package unlinked"
	else
		fail "link-all leaves the rtk tool package unlinked"
	fi
else
	fail "prepare link-all case"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all rtk lifecycle cases passed"
