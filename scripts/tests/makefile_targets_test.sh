#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
failures=0

fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }

# Adopt-before-stow and restore-after-unstow are stow-package.sh's contract,
# covered by scripts/tests/stow_package_test.sh. What the Makefile owes is the
# wiring: each recipe hands that script the right action, package, and target.
for action in link relink; do
	plan="$(make -C "$repo_root" -n "$action-harnesses" HARNESSES=claude TARGET_claude=/tmp/probe 2>&1)"
	if printf '%s' "$plan" | grep -q "stow-package.sh $action .*harnesses/claude /tmp/probe"; then
		pass "$action-harnesses delegates to stow-package.sh with the claude package"
	else
		fail "$action-harnesses delegates to stow-package.sh with the claude package"
	fi
done

plan="$(make -C "$repo_root" -n unlink-harnesses HARNESSES=claude TARGET_claude=/tmp/probe 2>&1)"
if printf '%s' "$plan" | grep -q 'stow-package.sh unlink .*harnesses/claude /tmp/probe'; then
	pass "unlink-harnesses delegates to stow-package.sh with the claude package"
else
	fail "unlink-harnesses delegates to stow-package.sh with the claude package"
fi

# A dry run of the meta targets must expand the recipes it delegates to, so the
# commands can be inspected before any of them run.
plan="$(make -C "$repo_root" -n link-all HARNESSES=claude TARGET_claude=/tmp/probe 2>&1)"
if printf '%s' "$plan" | grep -q 'stow-package.sh link .*harnesses/claude'; then
	pass "make -n link-all expands the harness commands"
else
	fail "make -n link-all expands the harness commands"
fi

# rtk setup runs through the script that guards settings.json.bak, never by
# calling `rtk init` from the recipe directly.

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/claude" "$test_root/agents" "$test_root/skills"
for command_name in rtk brew; do
	cat > "$test_root/bin/$command_name" <<'SH'
#!/bin/sh
printf '%s\n' unexpected > "$PROBE_UNEXPECTED"
exit 99
SH
	chmod +x "$test_root/bin/$command_name"
done
if PATH="$test_root/bin:$PATH" PROBE_UNEXPECTED="$test_root/unexpected" \
	make -C "$repo_root" link-all HARNESSES=claude TARGET_claude="$test_root/claude" \
	AGENTS_MD_TARGETS="$test_root/agents" SKILLS_TARGETS="$test_root/skills" >/dev/null 2>&1 \
	&& [ -L "$test_root/claude/settings.json" ] \
	&& grep -q 'rtk hook claude' "$test_root/claude/settings.json" \
	&& [ ! -e "$test_root/unexpected" ]; then
	pass "link-all links the committed hook without installing rtk or running init"
else
	fail "link-all links the committed hook without installing rtk or running init"
fi

for target in link-tools unlink-tools relink-tools; do
	plan="$(make -C "$repo_root" -n "$target" TOOLS=rtk TARGET_rtk_codex=/tmp/probe 2>&1)"
	if printf '%s' "$plan" | grep -q "stow-package.sh ${target%%-*} .*tools/rtk/codex /tmp/probe"; then
		pass "$target stows the rtk codex package"
	else
		fail "$target stows the rtk codex package"
	fi
done

for probe in "TOOLS=rtk TOOL_TARGETS_rtk=" "TOOLS=bogus"; do
	# shellcheck disable=SC2086
	if plan="$(make -C "$repo_root" -n link-tools $probe 2>&1)"; then
		fail "link-tools fails loudly for $probe (exited 0: $plan)"
	elif printf '%s' "$plan" | grep -q 'TOOL_TARGETS'; then
		pass "link-tools fails loudly for $probe and names the missing variable"
	else
		fail "link-tools failure for $probe names TOOL_TARGETS (got: $plan)"
	fi
done

plan="$(make -C "$repo_root" -n link-all HARNESSES=claude TARGET_claude=/tmp/probe 2>&1)"
if printf '%s' "$plan" | grep -q 'tools/'; then
	fail "link-all leaves tool packages alone"
else
	pass "link-all leaves tool packages alone"
fi

for target in setup-rtk teardown-rtk; do
	plan="$(make -C "$repo_root" -n "$target" 2>&1)"
	if printf '%s' "$plan" | grep -q 'tools/rtk/setup-rtk.sh'; then
		pass "$target runs through the relocated setup script"
	else
		fail "$target runs through the relocated setup script"
	fi
done

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all makefile target cases passed"
