#!/usr/bin/env bash
set -euo pipefail

package_dir="${1:?usage: adopt-harness.sh <package_dir> <target_dir>}"
target_dir="${2:?usage: adopt-harness.sh <package_dir> <target_dir>}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if [ ! -d "$package_dir" ]; then
	echo "adopt-harness: no such package: $package_dir" >&2
	exit 1
fi

resolve() {
	python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

classify() {
	local live="$1"

	if [ ! -L "$live" ] && [ ! -e "$live" ]; then
		echo skip
		return
	fi

	if [ -L "$live" ]; then
		local resolved
		resolved="$(resolve "$live")"
		case "$resolved" in
			"$repo_root"/*) echo skip ;;
			*) echo "refuse $live is a symlink to $resolved, outside $repo_root" ;;
		esac
		return
	fi

	if [ -e "$live.bak" ] || [ -L "$live.bak" ]; then
		echo "refuse $live is a real file and $live.bak already exists"
		return
	fi

	echo adopt
}

adoptable=()
while IFS= read -r rel; do
	verdict="$(classify "$target_dir/$rel")"
	case "$verdict" in
		skip) ;;
		adopt) adoptable+=("$target_dir/$rel") ;;
		refuse\ *) echo "adopt-harness: ${verdict#refuse }" >&2; exit 1 ;;
	esac
done < <(cd "$package_dir" && find . \( -type f -o -type l \) -print | sed 's|^\./||')

for live in ${adoptable+"${adoptable[@]}"}; do
	mv "$live" "$live.bak"
	echo "adopt-harness: backed up $live -> $live.bak"
done
