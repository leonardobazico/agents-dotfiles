#!/usr/bin/env bash
set -euo pipefail

package_dir="${1:?usage: list-harness-files.sh <package_dir>}"

cd "$package_dir"
find . \( -name tests -o -name run_tests.sh \) -prune -o \
	\( -type f -o -type l \) -print | sed 's|^\./||'
