# agents-dotfiles

AI agent workflow dotfiles managed via GNU Stow. This repo stores custom skills and prompt templates, and uses stow to distribute them to agent tool discovery paths.

## Repository Structure

```
agents-dotfiles/
├── AGENTS.md         — This file (repo maintenance guide)
├── Makefile          — GNU Stow-based skills distribution
├── skills/           — Custom agent skills (source of truth)
│   └── <skill-name>/
│       ├── SKILL.md  — Skill instructions (required)
│       └── ...       — Supporting files (optional)
├── templates/        — Prompt templates (not stowed, referenced by absolute path)
│   └── *.md
└── docs/
    ├── plans/        — Implementation plans
    └── specs/        — Design specifications
```

## Prerequisites

- [GNU Stow](https://www.gnu.org/software/stow/) (`brew install stow`)

## Repo Workflow

This is a trunk-based project. Work directly on `main` unless a task explicitly says otherwise.

## Makefile Usage

Run `make help` to see all available targets.

### Skills targets

| Target | Description |
|--------|-------------|
| `make link-skills` | Stow skills to `~/.agents/skills/` and `~/.claude/skills/` |
| `make unlink-skills` | Remove stowed skill symlinks |
| `make relink-skills` | Restow skills (run after adding/removing skills) |

### Meta targets

| Target | Description |
|--------|-------------|
| `make link-all` | Run all link targets |
| `make unlink-all` | Run all unlink targets |
| `make relink-all` | Run all relink targets |

## Pre-Commit

Install `pre-commit` with your preferred Python tool, then enable the hook:

```bash
pre-commit install
```

Run the full repo pass when you first set it up or need to recheck everything:

```bash
pre-commit run --all-files
```

Markdown is auto-formatted by the hooks. The Makefile is validated, not auto-formatted, in this initial setup.

Use `pre-commit autoupdate` when intentionally refreshing hook versions. Note that `additional_dependencies` pins (e.g. `mdformat-frontmatter`) are not touched by `autoupdate` and need to be bumped manually.

## Adding a New Skill

1. Create a directory in `skills/` with a lowercase, hyphenated name:

   ```
   mkdir -p skills/my-new-skill
   ```

2. Add a `SKILL.md` with required YAML frontmatter:

   ```yaml
   ---
   name: my-new-skill
   description: What the skill does and when to use it.
   ---

   Instructions for the agent...
   ```

3. Optionally add supporting files (scripts, templates, references) in the skill directory.

4. Run `make relink-skills` to update symlinks.

5. Commit the new skill.

## Adding Agent Config Files

_Planned for future work._ Each agent will get its own stow package directory at the repo root (e.g., `opencode/`, `claude/`) with `link-<agent>` / `unlink-<agent>` / `relink-<agent>` targets.

## Skills Distribution

Skills are distributed to two paths via GNU Stow:

- **`~/.agents/skills/`** — Discovered by OpenCode, GitHub Copilot CLI, OpenAI Codex CLI, and Google Gemini CLI.
- **`~/.claude/skills/`** — Discovered by Claude Code (also by OpenCode and Copilot as a secondary path).

Each skill directory in `skills/` becomes a symlink at the target paths. For example:

```
~/.agents/skills/ask-agents-for-feedback -> <repo>/skills/ask-agents-for-feedback
~/.claude/skills/ask-agents-for-feedback -> <repo>/skills/ask-agents-for-feedback
```

Templates in `templates/` are not stowed. Reference them by absolute path (`/Users/<user>/agents-dotfiles/templates/...`).
