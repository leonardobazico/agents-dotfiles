# agents-dotfiles

> `CLAUDE.md` in the same directory is a symlink to `AGENTS.md`. Edit `AGENTS.md` only; `CLAUDE.md` follows automatically.

AI agent workflow dotfiles managed via GNU Stow. This repo stores custom skills and prompt templates, and uses stow to distribute them to agent tool discovery paths.

## Repository Structure

```
agents-dotfiles/
├── AGENTS.md         - This file (repo maintenance guide)
├── Makefile          - GNU Stow-based distribution targets
├── scripts/          - Helper scripts called by the Makefile
├── shared/           - Packages stowed to many targets
│   ├── agents-md/    - Default agent instruction files
│   │   ├── AGENTS.md - Canonical default agent instructions
│   │   └── CLAUDE.md - Symlink alias to `AGENTS.md`
│   └── skills/       - Custom agent skills (source of truth)
│       └── <skill-name>/
│           ├── SKILL.md  - Skill instructions (required)
│           └── ...       - Supporting files (optional)
├── harnesses/        - Packages stowed to exactly one target each
│   └── <harness>/
├── templates/        - Prompt templates (not stowed, referenced by absolute path)
│   └── *.md
└── docs/
    ├── plans/        - Implementation plans
    └── specs/        - Design specifications
```

Packages are grouped by how they are distributed. `shared/` holds content that is
byte-identical across harnesses and fans out to several target directories.
`harnesses/<name>/` holds config unique to one tool and stows to exactly one target.

## Prerequisites

- [GNU Stow](https://www.gnu.org/software/stow/) (`brew install stow`)

## Repo Workflow

This is a trunk-based project. Work directly on `main` unless a task explicitly says otherwise.

## Makefile Usage

Run `make help` for the current list of targets, grouped by area. It is generated from
the Makefile itself, so it never drifts. Do not restate the target list here.

Adding a harness costs a directory plus two Makefile variables, with no new recipe:
append the name to `HARNESSES` and define `TARGET_<name>`.

## Pre-Commit

Install `pre-commit` with your preferred Python tool, then enable the hooks:

```bash
pre-commit install --install-hooks
```

That wires three stages, named by `default_install_hook_types`: `pre-commit` for the
formatters, linters, and test suites, `commit-msg` for the conventional-commit check,
and `pre-push` for a full-history secret scan.

Secret scanning runs at repo level rather than relying on a machine-global git hook, so
a fresh clone is protected: `gitleaks git --staged --no-banner` on every commit and
`gitleaks git --no-banner` over the whole history on every push. Install `gitleaks`
(`brew install gitleaks`) or both hooks fail.

Run the full repo pass when you first set it up or need to recheck everything:

```bash
pre-commit run --all-files
```

Markdown is auto-formatted by the hooks. The Makefile is validated, not auto-formatted, in this initial setup.

Two local hooks run the test suites: `shared/skills/count-tokens/scripts/run_tests.sh`
(Python) and `scripts/run_tests.sh` (shell).

Use `pre-commit autoupdate` when intentionally refreshing hook versions. Note that `additional_dependencies` pins (e.g. `mdformat-frontmatter`) are not touched by `autoupdate` and need to be bumped manually.

## Adding a New Skill

Invoke the `superpowers:writing-skills` skill first. It governs how a skill is written,
edited, and verified before deployment. The steps below are the repo-specific wrapper
around it: where the directory goes and how it reaches the discovery paths.

1. Create a directory in `shared/skills/` with a lowercase, hyphenated name:

   ```
   mkdir -p shared/skills/my-new-skill
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

## Skill Writing Standards

Skill and template content (`SKILL.md`, `shared/skills/templates/*.md`) is a prompt an agent executes, not documentation a human reads once. Keep it:

- **Concise**: state each rule once. Do not restate a rule already covered by an earlier section or a shared vocabulary list.
- **Unambiguous**: pin every term to one concrete definition (exact trigger conditions, exact tag/field names). Avoid "usually", "generally", "as needed" where a rule must hold every time.
- **Deterministic**: prefer explicit branches ("if X, do A; otherwise do B") over vague guidance that could be interpreted differently across runs. A table beats prose for multi-path logic.

When a skill grows through iteration, re-read it for duplicated phrasing before committing and compact it, the same way code gets refactored.

**Script mechanical steps** (git ranges, path lookups, template substitution): have the skill call a script instead of describing the procedure in prose. Scripts are testable and repeatable; prose is re-interpreted each run and drifts. Reserve prose for judgment calls. Reference: `subagent-driven-development`'s `scripts/` directory.

## Agent Config Distribution

- `shared/agents-md/AGENTS.md` is the canonical source for installed default agent instructions.
- `shared/agents-md/CLAUDE.md` is a symlink alias to `AGENTS.md`.
- `make link-agents-md` stows this package to `~/.agents`, `~/.claude`, and `~/.codex`.
- `make unlink-agents-md` removes those symlinks.
- `make relink-agents-md` refreshes those symlinks after edits.

This is separate from the repo-root `AGENTS.md` and `CLAUDE.md`, where `CLAUDE.md` remains a symlink that follows `AGENTS.md`.

## Harness Config Distribution

Each `harnesses/<name>/` package stows to exactly one target:

| Package | Target |
|---------|--------|
| `harnesses/claude` | `~/.claude` |
| `harnesses/opencode` | `~/.config/opencode` |

Targets are not derivable from the harness name: OpenCode reads `~/.config/opencode`,
not `~/.opencode`. Every harness stow runs with `--no-folding`, so a directory the
harness manages stays a real directory in the target rather than becoming a symlink
into this repo. Without it, stow folds `~/.claude/hooks` into a single link, and a
hook added there by another tool would land inside this working tree.

`make link-harnesses` calls `scripts/adopt-harness.sh` before stowing. For each file
in the package it inspects the live path and branches:

| Live path is | Action |
|--------------|--------|
| Absent | Nothing; stow creates the link |
| A real file | Moved to `<name>.bak`, then stowed |
| A symlink resolving to this package's own file | Left alone; already adopted |
| Anything else | Fails loudly and changes nothing |

Ownership is the package file itself, not the repository. A symlink to some other
file in this repo is refused here with a message naming both paths, rather than
surviving adoption and failing as a stow conflict a step later.

An existing `.bak` is never overwritten. If one is present while the live path is
still a real file, the target fails, because the older backup is the true
pre-migration state.

`make unlink-harnesses` reverses the migration: it unstows, then calls
`scripts/restore-harness.sh` to move each `<name>.bak` back to its live path. A
live path that something else already occupies keeps its `.bak`, and the script
says so on stderr instead of overwriting.

A harness package holds only what encodes that tool's own contract: its config schema,
its hook protocol. Content that any harness would use byte for byte stays in `shared/`.
`superpowers-overrides.md` ships from `shared/agents-md` for that reason, while the
SessionStart hook that injects it stays in `harnesses/claude`, because the JSON envelope
it emits is Claude Code's. The two are siblings only after stowing, since both packages
land in `~/.claude`; in this repo they sit in different directories.

When a file moves between packages, restow the package losing it before the one gaining
it. Stow will not create a link over a path another package still owns, and the losing
package's restow then removes what the gaining one could not place.

These config files are live. Claude Code writes through the symlink whenever
`/config` runs or a plugin is toggled, so those writes appear as a diff in this
repo. That is the point of versioning them. Secrets never belong here:
`~/.claude/settings.local.json` stays unmanaged and machine-local, and
`harnesses/claude/settings.local.json` is gitignored so a stray copy cannot be
committed.

## RTK

[rtk](https://github.com/rtk-ai/rtk) is a CLI proxy that condenses command output
before an agent reads it. `make setup-rtk` installs it via Homebrew when missing,
then runs `scripts/setup-rtk.sh`. `make teardown-rtk` removes rtk's integrations
but keeps the binary installed. These targets stay out of `link-all`; linking
the committed Claude settings nevertheless installs its RTK hook.

The script runs `rtk init --global --hook-only`, not plain `rtk init --global`.
Plain init appends an `@RTK.md` reference to `~/.claude/CLAUDE.md`, which is this
repo's hand-maintained `shared/agents-md/AGENTS.md`. The agent-facing rtk rules
live in that file's `Running Commands` section instead, written by hand and
committed, so rtk never edits it.

rtk patches `~/.claude/settings.json` through the stow symlink, so its
`PreToolUse` entry lands in `harnesses/claude/settings.json` and is committed like
any other Claude Code write. Uninstalling leaves `"PreToolUse": []` behind; drop
that hunk by hand if it matters.

The script exists for one reason beyond sequencing: `rtk init` overwrites
`~/.claude/settings.json.bak` unconditionally, and that path holds the
pre-migration original `scripts/restore-harness.sh` hands back on unlink. The
script archives it as `settings.json.bak.<UTC timestamp>.pre-rtk` and archives
rtk's snapshot as `settings.json.bak.<UTC timestamp>.rtk`. Both paths are printed,
including after failed or interrupted init. Archiving refuses overwrites; failure
retains the source and reports its location. These timestamped backups require
manual restoration: `unlink-harnesses` only restores the exact `.bak` name.
Teardown fails if rtk is absent; reinstall rtk first.

`rtk init --global --codex` is never run. Codex supports command hooks, but
this intermediate setup covers it through shared instructions. Additionally,
`codex debug prompt-input` confirms it does not expand `@` references in
`AGENTS.md`, absolute or relative, so the line that mode writes is text no agent
reads. Codex is covered by the `Running Commands` section instead, which reaches
it because `~/.codex/AGENTS.md` is stowed from `shared/agents-md`. That section
also covers Claude Code, where it is redundant but harmless: the hook leaves an
already-prefixed command alone. Verify a change to it with
`codex debug prompt-input`, which renders the model-visible prompt without an API
call.

If rtk is absent, the committed Claude hook reports a missing command. Its
non-blocking behavior is inferred from Claude's exit-code contract, not tested here.

## Skills Distribution

Skills are distributed to two paths via GNU Stow:

- **`~/.agents/skills/`**: Discovered by OpenCode, GitHub Copilot CLI, OpenAI Codex CLI, and Google Gemini CLI.
- **`~/.claude/skills/`**: Discovered by Claude Code (also by OpenCode and Copilot as a secondary path).

Each skill directory in `shared/skills/` becomes a symlink at the target paths. For example:

```
~/.agents/skills/ask-agents-for-feedback -> <repo>/shared/skills/ask-agents-for-feedback
~/.claude/skills/ask-agents-for-feedback -> <repo>/shared/skills/ask-agents-for-feedback
```

Templates in `templates/` are not stowed. Reference them by absolute path (`/Users/<user>/agents-dotfiles/templates/...`).
