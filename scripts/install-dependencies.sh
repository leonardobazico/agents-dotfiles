#!/usr/bin/env bash
set -euo pipefail

formulae=(opencode stow gitleaks pre-commit ruff jscpd)
casks=(claude-code codex)

if ! command -v brew > /dev/null 2>&1; then
	echo "install-dependencies.sh: Homebrew is required; see https://brew.sh" >&2
	exit 1
fi

# brew install exits 0 for an already-installed formula or cask, so the lists
# are applied unconditionally and the target stays re-runnable.
brew install "${formulae[@]}"
brew install --cask "${casks[@]}"
# PyPI rather than Homebrew: the habit-hooks tap ships no bottle attestation,
# and deptry, its Python plugin's dependency checker, has no formula.
uv_tools=("habit-hooks[python]" deptry)
for tool in "${uv_tools[@]}"; do
	uv tool install "$tool"
done
