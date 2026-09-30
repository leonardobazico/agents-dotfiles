#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
setup="$repo_root/scripts/setup-rtk.sh"
failures=0

fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }

if [ ! -x "$setup" ]; then
	echo "FAIL: $setup is missing or not executable"
	exit 1
fi

if ! command -v rtk >/dev/null 2>&1; then
	echo "skip: rtk is not installed; cannot exercise setup-rtk.sh"
	exit 0
fi

# Written literally rather than copied from harnesses/claude/settings.json: that
# file carries the rtk hook once setup has run, which would turn the install case
# into a tautology.
new_home() {
	home="$(mktemp -d)"
	mkdir -p "$home/.claude"
	cat > "$home/.claude/settings.json" <<-'JSON'
		{
		  "model": "opus",
		  "hooks": {
		    "SessionStart": [
		      {
		        "matcher": "startup|clear|compact",
		        "hooks": [
		          {
		            "type": "command",
		            "command": "$HOME/.claude/hooks/superpowers-overrides"
		          }
		        ]
		      }
		    ]
		  }
		}
	JSON
}

run_setup() { HOME="$home" "$setup" >/dev/null 2>&1; }

# The RTK hook is what earns the token savings, so it has to reach settings.json.
new_home
if run_setup && grep -q 'rtk hook claude' "$home/.claude/settings.json"; then
	pass "installs the RTK hook into settings.json"
else
	fail "installs the RTK hook into settings.json"
fi

# RTK patches the same hooks object this repo already uses for SessionStart.
new_home
if run_setup && grep -q 'superpowers-overrides' "$home/.claude/settings.json"; then
	pass "leaves the existing SessionStart hook intact"
else
	fail "leaves the existing SessionStart hook intact"
fi

# `rtk init` writes its own settings.json.bak. The backup already sitting there is
# the pre-stow-migration original that restore-harness.sh hands back on unlink, so
# losing it would strand the machine on this repo's config.
new_home
printf 'PRE-MIGRATION\n' > "$home/.claude/settings.json.bak"
if run_setup && [ "$(cat "$home/.claude/settings.json.bak")" = "PRE-MIGRATION" ]; then
	pass "preserves an existing settings.json.bak"
else
	fail "preserves an existing settings.json.bak"
fi

# Nothing should be left behind for restore-harness.sh to misread as a backup.
new_home
if run_setup && [ ! -e "$home/.claude/settings.json.bak" ]; then
	pass "leaves no stray backup when there was none"
else
	fail "leaves no stray backup when there was none"
fi

# Reruns happen on every machine re-provision; a second pass must not stack hooks.
new_home
run_setup
if run_setup && [ "$(grep -c 'rtk hook claude' "$home/.claude/settings.json")" = "1" ]; then
	pass "rerunning leaves a single hook entry"
else
	fail "rerunning leaves a single hook entry"
fi

# OpenCode reads plugins from its own config dir, not from ~/.opencode.
new_home
if run_setup && [ -f "$home/.config/opencode/plugins/rtk.ts" ]; then
	pass "installs the OpenCode plugin"
else
	fail "installs the OpenCode plugin"
fi

# Without rtk and without a way to install it, say so instead of half-running.
new_home
out="$(PATH="/usr/bin:/bin" HOME="$home" "$setup" 2>&1)"
if [ $? -ne 0 ] && printf '%s' "$out" | grep -qi 'homebrew'; then
	pass "missing rtk and missing brew fails with a homebrew message"
else
	fail "missing rtk and missing brew fails with a homebrew message"
fi

# Teardown has to undo the hook, or an uninstalled rtk leaves a dead command
# rewriting every Bash call.
new_home
run_setup
if HOME="$home" "$setup" --uninstall >/dev/null 2>&1 \
	&& ! grep -q 'rtk hook claude' "$home/.claude/settings.json" \
	&& [ ! -f "$home/.config/opencode/plugins/rtk.ts" ]; then
	pass "--uninstall removes the hook and the OpenCode plugin"
else
	fail "--uninstall removes the hook and the OpenCode plugin"
fi

# `rtk init --uninstall` rewrites settings.json.bak too, so the guard has to hold
# on the way out as well.
new_home
run_setup
printf 'PRE-MIGRATION\n' > "$home/.claude/settings.json.bak"
if HOME="$home" "$setup" --uninstall >/dev/null 2>&1 \
	&& [ "$(cat "$home/.claude/settings.json.bak")" = "PRE-MIGRATION" ]; then
	pass "--uninstall preserves an existing settings.json.bak"
else
	fail "--uninstall preserves an existing settings.json.bak"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "all setup-rtk cases passed"
