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

# Unstowing must hand the machine back its pre-migration files, or the harness
# silently falls back to its defaults.
plan="$(make -C "$repo_root" -n unlink-harnesses HARNESSES=claude TARGET_claude=/tmp/probe 2>&1)"
if printf '%s' "$plan" | grep -q 'restore-harness.sh'; then
	pass "unlink-harnesses restores backups after unstowing"
else
	fail "unlink-harnesses restores backups after unstowing"
fi

# A dry run of the meta targets must expand the recipes it delegates to, so the
# commands can be inspected before any of them run.
plan="$(make -C "$repo_root" -n link-all HARNESSES=claude TARGET_claude=/tmp/probe 2>&1)"
if printf '%s' "$plan" | grep -q 'adopt-harness.sh'; then
	pass "make -n link-all expands the harness commands"
else
	fail "make -n link-all expands the harness commands"
fi

# rtk setup runs through the script that guards settings.json.bak, never by
# calling `rtk init` from the recipe directly.
for target in setup-rtk teardown-rtk; do
	plan="$(make -C "$repo_root" -n "$target" 2>&1)"
	if printf '%s' "$plan" | grep -q 'scripts/setup-rtk.sh'; then
		pass "$target runs through setup-rtk.sh"
	else
		fail "$target runs through setup-rtk.sh"
	fi
done

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

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all makefile target cases passed"
