#!/usr/bin/env bash
set -euo pipefail

mode="${1:-install}"
case "$mode" in
	install | --uninstall) ;;
	*)
		echo "usage: setup-rtk.sh [--uninstall]" >&2
		exit 2
		;;
esac

if ! command -v rtk >/dev/null 2>&1; then
	if [ "$mode" = "--uninstall" ]; then
		echo "setup-rtk: rtk is not installed; nothing to remove" >&2
		exit 0
	fi
	if ! command -v brew >/dev/null 2>&1; then
		echo "setup-rtk: rtk is not installed and homebrew is not available to install it" >&2
		exit 1
	fi
	brew install rtk
fi

settings="$HOME/.claude/settings.json"
backup="$settings.bak"
stash="$settings.bak.pre-rtk"

# `rtk init` overwrites settings.json.bak unconditionally, on install and on
# uninstall alike. That file is the pre-stow-migration original that
# restore-harness.sh hands back on unlink, so it is moved out of rtk's way and
# put back afterwards.
stashed=0
if [ -e "$backup" ] || [ -L "$backup" ]; then
	if [ -e "$stash" ] || [ -L "$stash" ]; then
		echo "setup-rtk: $stash already exists; resolve it before rerunning" >&2
		exit 1
	fi
	mv "$backup" "$stash"
	stashed=1
fi

if [ "$mode" = "--uninstall" ]; then
	rtk init --global --uninstall
else
	rtk init --global --hook-only --auto-patch --agent claude
	rtk init --global --opencode
fi

rm -f "$backup"
if [ "$stashed" -eq 1 ]; then
	mv "$stash" "$backup"
fi
