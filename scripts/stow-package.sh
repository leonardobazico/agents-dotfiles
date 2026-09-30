#!/usr/bin/env bash
set -euo pipefail

action="${1:?usage: stow-package.sh <link|unlink|relink> <package_dir> <target_dir>}"
package_dir="${2:?usage: stow-package.sh <link|unlink|relink> <package_dir> <target_dir>}"
target_dir="${3:?usage: stow-package.sh <link|unlink|relink> <package_dir> <target_dir>}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [ ! -d "$package_dir" ]; then
	echo "stow-package: no such package: $package_dir" >&2
	exit 1
fi

package_dir="$(cd "$package_dir" && pwd -P)"
package_name="$(basename "$package_dir")"
package_parent="$(dirname "$package_dir")"

# --no-folding keeps a directory the harness manages a real directory in the
# target. Without it stow folds it into one link and another tool's writes land
# inside this working tree.
run_stow() {
	stow --verbose --no-folding --dir="$package_parent" --target="$target_dir" "$1" "$package_name"
}

case "$action" in
	link|relink)
		mkdir -p "$target_dir"
		bash "$script_dir/adopt-harness.sh" "$package_dir" "$target_dir"
		if [ "$action" = link ]; then
			run_stow --stow
		else
			run_stow --restow
		fi
		;;
	unlink)
		run_stow --delete
		bash "$script_dir/restore-harness.sh" "$package_dir" "$target_dir"
		;;
	*)
		echo "stow-package: unknown action '$action'; expected link, unlink, or relink" >&2
		exit 1
		;;
esac
