#!/usr/bin/env bash
set -euo pipefail

usage() {
	echo "usage: $(basename "$0") <claude|codex> <plugin> <source>" >&2
	exit 2
}

[ "$#" -eq 3 ] || usage
harness="$1"
plugin="$2"
source_ref="$3"

case "$harness" in
claude | codex) ;;
*)
	echo "install-plugin.sh: unsupported harness '$harness'" >&2
	exit 1
	;;
esac

repo="${source_ref%@*}"
case "$repo" in
*/*) ;;
*)
	echo "install-plugin.sh: source '$source_ref' is not an owner/repo reference" >&2
	exit 1
	;;
esac

if ! command -v "$harness" > /dev/null 2>&1; then
	echo "install-plugin.sh: $harness is not on PATH; run 'make install-dependencies' first" >&2
	exit 1
fi

marketplace="${repo##*/}"
selector="$plugin@$marketplace"

marketplace_present() {
	case "$harness" in
	claude) claude plugin marketplace list 2> /dev/null | grep -qF "($repo)" ;;
	codex) codex plugin marketplace list 2> /dev/null |
		awk -v m="$marketplace" 'NR > 1 && $1 == m { found = 1 } END { exit !found }' ;;
	esac
}

plugin_present() {
	case "$harness" in
	claude) claude plugin list 2> /dev/null | grep -qF "$selector" ;;
	codex) codex plugin list 2> /dev/null |
		awk -v s="$selector" '$1 == s && $0 !~ /not installed/ { found = 1 } END { exit !found }' ;;
	esac
}

# Neither CLI documents its exit code for an already-added marketplace or an
# already-installed plugin, so a reported failure is accepted only when the
# harness's own listing shows the state the step was meant to create.
ensure() {
	local state="$1"
	shift
	if "$@"; then
		return 0
	fi
	if "${state}_present"; then
		echo "install-plugin.sh: $harness $state already present, continuing" >&2
		return 0
	fi
	echo "install-plugin.sh: $harness $state step failed: $*" >&2
	return 1
}

case "$harness" in
claude)
	ensure marketplace claude plugin marketplace add "$source_ref" --scope user
	ensure plugin claude plugin install "$selector" --scope user --yes
	;;
codex)
	ensure marketplace codex plugin marketplace add "$source_ref"
	ensure plugin codex plugin add "$selector"
	;;
esac
