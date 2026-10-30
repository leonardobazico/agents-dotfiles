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
| `opencode` | `git clone`/`git fetch` plus `git checkout <ref>` into `.cache/plugins/<repo>`, then two file copies |
| anything else | fails, naming the harness, changing nothing |

Codex accepts `owner/repo[@ref]` as its source argument, so the `@ref` suffix is passed verbatim and `--ref` is never
used. The suffix is stripped when deriving the marketplace name.

Neither CLI documents its exit code for an already-added marketplace or an already-installed plugin, so a step that
reports failure is accepted only when the harness's own `list` output shows the state that step was meant to create.
Anything else fails.

### OpenCode

OpenCode has no plugin CLI, and upstream's `package.json` is `"private": true` with no `main` and no `exports`, so a
`plugin` entry in `opencode.json` has nothing to import. The installer therefore uses upstream's copy route, which
installs the skill and the slash command and nothing else:

| Source in the checkout | Destination |
| -- | -- |
| `skills/<plugin>/SKILL.md` | `<config>/skills/<plugin>/SKILL.md` |
| `.opencode/command/<plugin>.md` | `<config>/commands/<plugin>.md` |

`<config>` is `${XDG_CONFIG_HOME:-$HOME/.config}/opencode`. The installer reads that variable because OpenCode does,
while `TARGET_opencode` in the Makefile hardcodes `$(HOME)/.config/opencode`.

The checkout is pinned by the manifest row's `@ref` and lives in `.cache/plugins/<repo>`, which is gitignored and sits
outside the config root so nothing unmanaged appears beside OpenCode's own files. Rerunning `make install-plugins`
fetches, resets to the pinned ref, and recopies, so updating is a manifest edit followed by a rerun.

Each file is written to a sibling `.tmp` path and renamed, so an interrupted run leaves no half-written skill. There is
no CLI listing to confirm against, so the post-condition is both destination files existing and matching the checkout.

Upstream's always-on mode is deliberately not installed: it needs the vendor-plus-loader route and a
`<config>/.i-have-adhd-always` flag, and this repo configures neither. OpenCode may still invoke an installed skill on
its own, which `permission.skill` in `harnesses/opencode/opencode.json` keeps visible by asking first.

## Named, not owned

These surfaces belong to the harnesses. Change them where they are.

| Surface | Location | Owner |
| -- | -- | -- |
| Claude marketplace registry | `~/.claude/plugins/known_marketplaces.json` | Claude Code; absolute paths and timestamps, machine-local |
| Codex plugin state | `~/.codex/config.toml` | Codex; unmanaged by this repo, and also holds per-project trust levels |
| `enabledPlugins` entries | `harnesses/claude/settings.json` | written by `claude plugin install`, committed |
| `extraKnownMarketplaces` entries | `harnesses/claude/settings.json` | written by `claude plugin marketplace add --scope user`, committed |
| `superpowers` Codex checkout | `~/.codex/superpowers` | superpowers' own installer; a git clone, unversioned |
| OpenCode skill copy | `<config>/skills/<plugin>/SKILL.md` | written by this installer; a copy, not a stow symlink |
| OpenCode command copy | `<config>/commands/<plugin>.md` | written by this installer; a copy, not a stow symlink |

`claude plugin marketplace add` and `claude plugin install` write `extraKnownMarketplaces` and `enabledPlugins` into
`~/.claude/settings.json`, which is the stow symlink into this repo, so installing a plugin produces a committed diff
here. That is the same write-through-the-symlink behavior `tools/rtk/README.md` records for `rtk init`, and it is why
the manifest can stay declarative for Claude Code while the registry stays machine-local.

## Why there is no uninstall

Every plugin here is a default. Removing one is a deliberate act done through the harness's own CLI, followed by
dropping its manifest row. OpenCode has no CLI for it, so there the deliberate act is deleting
`<config>/skills/<plugin>/` and `<config>/commands/<plugin>.md`, then dropping the row.

## Test seams

`scripts/install-plugins.sh` reads two environment variables so its tests never touch a harness CLI: `PLUGIN_MANIFEST`
overrides the manifest path, and `PLUGIN_INSTALLER` overrides the per-row installer. Production runs set neither.

`scripts/install-plugin.sh` reads `PLUGIN_CACHE_DIR` so its OpenCode cases clone into a temporary directory instead of
`.cache/plugins`. Production runs set it, like the other two, never.
