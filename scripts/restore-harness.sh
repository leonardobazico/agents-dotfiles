#!/usr/bin/env bash
set -euo pipefail

package_dir="${1:?usage: restore-harness.sh <package_dir> <target_dir>}"
target_dir="${2:?usage: restore-harness.sh <package_dir> <target_dir>}"

if [ ! -d "$package_dir" ]; then
	echo "restore-harness: no such package: $package_dir" >&2
	exit 1
fi

while IFS= read -r rel; do
	live="$target_dir/$rel"
	backup="$live.bak"

	[ -e "$backup" ] || [ -L "$backup" ] || continue

	if [ -e "$live" ] || [ -L "$live" ]; then
		echo "restore-harness: $live still exists; leaving $backup in place" >&2
		continue
	fi

	mv "$backup" "$live"
	echo "restore-harness: restored $backup -> $live"
done < <(cd "$package_dir" && find . \( -type f -o -type l \) -print | sed 's|^\./||')
