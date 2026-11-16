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

rtk_formula="rtk"

fail() {
  echo "setup-rtk: $1" >&2
  exit 1
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

require_rtk_for_uninstall() {
  has_command rtk && return
  fail "reinstall rtk before uninstalling its integrations"
}

install_rtk() {
  has_command brew || fail "rtk is not installed and homebrew is not available to install it"
  brew install "$rtk_formula" || fail "failed to install $rtk_formula"
}

upgrade_homebrew_rtk() {
  has_command brew || return 0
  brew list --versions "$rtk_formula" >/dev/null 2>&1 || return 0
  brew upgrade "$rtk_formula" || fail "failed to upgrade $rtk_formula"
}

ensure_current_rtk() {
  if has_command rtk; then
    upgrade_homebrew_rtk
    return
  fi
  install_rtk
}

if [ "$mode" = "--uninstall" ]; then
  require_rtk_for_uninstall
else
  ensure_current_rtk
fi

settings="$HOME/.claude/settings.json"
backup="$settings.bak"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
original_archive="$backup.$timestamp.pre-rtk"
rtk_archive="$backup.$timestamp.rtk"
child_pid=""

for destination in "$original_archive" "$rtk_archive"; do
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    echo "setup-rtk: $destination already exists; resolve it before rerunning" >&2
    exit 1
  fi
done

archive_backup() {
  local source="$1" destination="$2"
  if ! python3 - "$source" "$destination" <<'PY'
import os
import sys

try:
    os.link(sys.argv[1], sys.argv[2], follow_symlinks=False)
    os.unlink(sys.argv[1])
except OSError as error:
    print(f"setup-rtk: cannot archive {sys.argv[1]}: {error}", file=sys.stderr)
    sys.exit(1)
PY
  then
    echo "setup-rtk: backup retained at $source" >&2
    return 1
  fi
  echo "setup-rtk: preserved $destination"
}

finalize_backups() {
  local status="$?"
  trap - EXIT INT TERM
  if [ -e "$backup" ] || [ -L "$backup" ]; then
    if ! archive_backup "$backup" "$rtk_archive"; then
      [ "$status" -ne 0 ] || status=1
    fi
  fi
  exit "$status"
}

interrupt_init() {
  local signal_name="$1" status="$2"
  trap '' INT TERM
  if [ -n "$child_pid" ]; then
    kill -s "$signal_name" "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
  exit "$status"
}

run_init() {
  local status=0
  rtk init "$@" &
  child_pid="$!"
  wait "$child_pid" || status="$?"
  child_pid=""
  return "$status"
}

if [ -e "$backup" ] || [ -L "$backup" ]; then
  archive_backup "$backup" "$original_archive"
fi

trap finalize_backups EXIT
trap 'interrupt_init INT 130' INT
trap 'interrupt_init TERM 143' TERM

if [ "$mode" = "--uninstall" ]; then
  run_init --global --uninstall
else
  run_init --global --hook-only --auto-patch --agent claude
  run_init --global --opencode --hook-only --auto-patch
fi
