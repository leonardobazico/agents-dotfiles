#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
manifest="${PLUGIN_MANIFEST:-$script_dir/../plugins/manifest.tsv}"
installer="${PLUGIN_INSTALLER:-$script_dir/install-plugin.sh}"

if [ ! -f "$manifest" ]; then
	echo "install-plugins.sh: no manifest at $manifest" >&2
	exit 1
fi

status=0
line_number=0
while IFS= read -r line || [ -n "$line" ]; do
	line_number=$((line_number + 1))
	case "$line" in '' | '#'*) continue ;; esac

	IFS=$'\t' read -r plugin harness source_ref install extra <<< "$line"
	if [ -n "${extra:-}" ] || [ -z "${install:-}" ]; then
		echo "$manifest:$line_number: expected 4 tab-separated columns" >&2
		exit 1
	fi

	case "$install" in
	auto) ;;
	manual | skip) continue ;;
	*)
		echo "$manifest:$line_number: unknown install value '$install'" >&2
		exit 1
		;;
	esac

	"$installer" "$harness" "$plugin" "$source_ref" || status=1
done < "$manifest"

exit "$status"
