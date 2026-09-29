#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec uv run --quiet \
	--with "tiktoken>=0.8,<1" \
	--with "tokenizers>=0.20,<1" \
	python3 -m unittest discover \
	-s "$script_dir/tests" \
	-t "$script_dir"
