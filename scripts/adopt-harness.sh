#!/usr/bin/env bash
set -euo pipefail

package_dir="${1:?usage: adopt-harness.sh <package_dir> <target_dir>}"
target_dir="${2:?usage: adopt-harness.sh <package_dir> <target_dir>}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -d "$package_dir" ]; then
	echo "adopt-harness: no such package: $package_dir" >&2
	exit 1
fi

resolve() {
	python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

while IFS= read -r rel; do
	live="$target_dir/$rel"

	if [ ! -L "$live" ] && [ ! -e "$live" ]; then
		continue
	fi

	if [ -L "$live" ]; then
		resolved="$(resolve "$live")"
		case "$resolved" in
			"$repo_root"/*)
				continue
				;;
			*)
				echo "adopt-harness: $live is a symlink to $resolved, outside $repo_root" >&2
				exit 1
				;;
		esac
	fi

	if [ -e "$live.bak" ]; then
		echo "adopt-harness: $live is a real file and $live.bak already exists" >&2
		exit 1
	fi

	mv "$live" "$live.bak"
	echo "adopt-harness: backed up $live -> $live.bak"
done < <(cd "$package_dir" && find . \( -type f -o -type l \) -print | sed 's|^\./||')
