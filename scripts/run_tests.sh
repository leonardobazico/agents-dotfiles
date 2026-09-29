#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

status=0
for t in "$script_dir"/tests/*_test.sh; do
	echo "== $(basename "$t")"
	bash "$t" || status=1
done
exit $status
