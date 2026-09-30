# plugins

Plugin installation for every harness this repo manages. Plugin state is imperative: it lives in files the harness CLIs
own, with absolute paths and timestamps, so stow cannot own it. `make install-plugins` drives the CLIs instead, the same
way `make setup-rtk` drives `rtk init`.

## Owned

| File | Purpose |
| -- | -- |
| `manifest.tsv` | Every plugin and harness pair: source, and whether this repo installs it |

`scripts/install-plugins.sh` parses the manifest and delegates each `auto` row to `scripts/install-plugin.sh`, which
owns the per-harness CLI sequence.

## The manifest

Tab separated, four columns, `#` comments and blank lines ignored.

| Column | Meaning |
| -- | -- |
| `plugin` | Plugin name as its harness CLI names it |
| `harness` | `claude`, `codex`, or `opencode` |
| `source` | Marketplace or package reference, or `-` when unused |
| `install` | `auto`, `manual`, or `skip` |

`install` values:

- `auto`: `make install-plugins` installs this row.
- `manual`: a working install this repo does not automate. Recorded so the manifest is the full picture of what a
  harness runs.
- `skip`: deliberately not installed.

A `manual` or `skip` row's `source` is documentation only. The marketplace name is derived from the repo name of an
`owner/repo` source, so those rules apply to `auto` rows alone, which is why `superpowers` records a bare marketplace
name for Claude Code and a package spec for OpenCode.

A row separated by spaces instead of tabs, a row with the wrong column count, and an unknown `install` value each fail
naming the file and line rather than installing nothing quietly.

## Per-harness commands

| Harness | Commands |
| -- | -- |
| `claude` | `claude plugin marketplace add <source> --scope user`, then `claude plugin install <plugin>@<marketplace> --scope user --yes` |
| `codex` | `codex plugin marketplace add <source>`, then `codex plugin add <plugin>@<marketplace>` |
| anything else | fails, naming the harness, changing nothing |

Codex accepts `owner/repo[@ref]` as its source argument, so the `@ref` suffix is passed verbatim and `--ref` is never
used. The suffix is stripped when deriving the marketplace name.

Neither CLI documents its exit code for an already-added marketplace or an already-installed plugin, so a step that
reports failure is accepted only when the harness's own `list` output shows the state that step was meant to create.
Anything else fails.

## Named, not owned

These surfaces belong to the harnesses. Change them where they are.

| Surface | Location | Owner |
| -- | -- | -- |
| Claude marketplace registry | `~/.claude/plugins/known_marketplaces.json` | Claude Code; absolute paths and timestamps, machine-local |
| Codex plugin state | `~/.codex/config.toml` | Codex; unmanaged by this repo, and also holds per-project trust levels |
| `enabledPlugins` entries | `harnesses/claude/settings.json` | written by `claude plugin install`, committed |
| `extraKnownMarketplaces` entries | `harnesses/claude/settings.json` | written by `claude plugin marketplace add --scope user`, committed |
| `superpowers` Codex checkout | `~/.codex/superpowers` | superpowers' own installer; a git clone, unversioned |

`claude plugin marketplace add` and `claude plugin install` write `extraKnownMarketplaces` and `enabledPlugins` into
`~/.claude/settings.json`, which is the stow symlink into this repo, so installing a plugin produces a committed diff
here. That is the same write-through-the-symlink behavior `tools/rtk/README.md` records for `rtk init`, and it is why
the manifest can stay declarative for Claude Code while the registry stays machine-local.

## Why there is no uninstall

Every plugin here is a default. Removing one is a deliberate act done through the harness's own CLI, followed by
dropping its manifest row.

## Test seams

`scripts/install-plugins.sh` reads two environment variables so its tests never touch a harness CLI: `PLUGIN_MANIFEST`
overrides the manifest path, and `PLUGIN_INSTALLER` overrides the per-row installer. Production runs set neither.
