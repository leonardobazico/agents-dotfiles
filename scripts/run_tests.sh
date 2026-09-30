#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd -P)"

status=0
for t in "$script_dir"/tests/*_test.sh "$repo_root"/tools/*/tests/*_test.sh; do
	[ -e "$t" ] || continue
	echo "== $(basename "$t")"
	bash "$t" || status=1
done
exit $status
