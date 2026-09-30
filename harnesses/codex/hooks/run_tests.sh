#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

exec python3 -B -m unittest discover -s "$script_dir/tests" -p 'test_*.py' -v
