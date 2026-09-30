# Codex sandbox blocks Claude Code keychain auth

Date: 2026-09-30

## Question

Codex, running in its default macOS seatbelt sandbox from `/Users/bazico/agents-dotfiles`,
invoked `/opt/homebrew/bin/claude --permission-mode plan --print` and got
`Not logged in · Please run /login`, exit 1. The same command from an ordinary terminal
succeeds. No `HOME` override, no isolated Claude configuration. Why?

## Finding

Claude Code stores its OAuth credentials in the macOS login keychain, not on disk:

- `~/.claude/.credentials.json` is absent.
- Generic-password item `Claude Code-credentials` exists and is readable.

Reading a legacy login-keychain item requires a Mach lookup of `com.apple.SecurityServer`.
Codex's seatbelt policy is closed by default (`(deny default)`) and grants that global name
only in its **network** policy fragment. Strings in `/opt/homebrew/bin/codex` (codex-cli
0.159.0) show the fragment header "when network access is enabled, these policies are added
after those in seatbelt_base_policy.sbpl", and `com.apple.SecurityServer` appears exactly
once in the binary, inside that fragment. The base policy grants `dirhelper`,
`opendirectoryd`, `cfprefsd` and `PowerManagement`, nothing security-related.

Codex's default sandbox for a trusted project is `workspace-write` with
`network_access = false`. `~/.codex/config.toml` sets no override, so the network fragment is
never appended: securityd is unreachable, the keychain read fails, and Claude Code reports
"Not logged in" before it ever touches the API.

## Evidence

All tests read-only, `CLAUDE_CODE_*` env scrubbed so the nested process starts as Codex's
would, probe file `/private/tmp/claude-auth-probe.md` expecting `CLAUDE_AUTH_PROBE_OK`.

| Test | Sandbox | Result |
|------|---------|--------|
| A | none | `CLAUDE_AUTH_PROBE_OK`, exit 0 |
| B | `(allow default)` + `(deny network*)` | `API Error: Can't reach the API server ... (ENOTFOUND)` |
| C | `(allow default)` + `(deny mach-lookup (global-name "com.apple.SecurityServer"))`, network allowed | `Not logged in · Please run /login` |

Test C reproduces the reported message exactly. Test B shows a network-only block produces a
different message, so the failure is credential access, not connectivity.

## Ruled out

- `rtk` prefix: `rtk` only condenses output. Failure reproduces without it.
- Inherited `CLAUDE_CODE_*` env: scrubbed in every test.
- `HOME` or config isolation: credentials are not file-backed, so `HOME` is not the path.
- Keychain ACL or partition list: the same binary reads the item fine unsandboxed and under a
  sandbox that permits the Mach lookup.

## Fix

Give the Codex session network access. That appends the seatbelt network fragment and with it
the `com.apple.SecurityServer` allowance. Claude Code needs outbound HTTPS anyway, so this is
the minimum that makes the subprocess work at all.

Per invocation:

```
codex -c sandbox_workspace_write.network_access=true
```

Persisted, in `~/.codex/config.toml`:

```toml
[sandbox_workspace_write]
network_access = true
```

`~/.codex/config.toml` is not stowed from this repo (only `AGENTS.md`, `CLAUDE.md` and
`superpowers-overrides.md` are symlinked into `~/.codex`), so the change is machine-local and
unversioned. No file in `agents-dotfiles` changes.

The sandbox policy is fixed when the Codex session starts, so the setting must be in place at
launch. It cannot be applied to a single nested command mid-session. If enabling network for
the whole session is unwanted, approve that one `claude` call to run escalated instead.

## Verification

From a Codex session started with the setting above, in `/Users/bazico/agents-dotfiles`:

```
rtk claude --permission-mode plan --add-dir /Users/bazico/agents-dotfiles --print < /private/tmp/claude-auth-probe.md
```

Expected: `CLAUDE_AUTH_PROBE_OK`, exit 0.

To capture denials instead of guessing, run in another pane while the probe executes:

```
log stream --style ndjson --predicate '((processID == 0) AND (senderImagePath CONTAINS "/Sandbox")) OR (subsystem == "com.apple.sandbox.reporting")'
```
