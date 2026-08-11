---
name: ask-agents-for-feedback
description: "Use ONLY when the user explicitly asks for AI peer review from multiple CLIs. Never invoke automatically or proactively. Orchestrates parallel readonly invocations, collects feedback, and hands off to consolidation."
---

# ask-agents-for-feedback

Run parallel, readonly peer review across multiple CLI agents and collect their independent feedback.

## When To Use

Run only when the user explicitly requests multi-CLI peer review. Never trigger automatically, proactively, or as a side effect of another task.

Use when you want independent review from multiple AI CLIs for an artifact such as:

- Documents
- Code
- Plans
- PRs
- Designs

## Inputs

- `artifact` — required; reference to what is being reviewed. Accepts a filesystem path, PR identifier, branch name, specific commit, design reference, or freeform description.
- `artifactType` — required; one of `DOCUMENT`, `CODE`, `PLAN`, `PR`, `DESIGN`, `OTHER`
- `relevantPaths` — optional; list of files/directories the reviewer should start from. Reviewers may explore beyond these as needed.
- `focusAreas` — optional; specific review focus areas
- `constraints` — optional; constraints reviewers should respect

## Prompt Construction

Read the shared `../templates/request-feedback.template.prompt.md` file (relative to this skill's directory) and replace each placeholder. Format multi-value fields as Markdown bulleted lists.

- `<ARTIFACT_TYPE>` → value of `artifactType`
- `<ARTIFACT>` → value of `artifact`
- `<RELEVANT_PATHS>` → Markdown bulleted list from `relevantPaths`, or "No specific paths — explore as needed." if empty
- `<FOCUS_AREAS>` → Markdown bulleted list from `focusAreas`, or "No specific focus areas — review holistically." if empty
- `<CONSTRAINTS>` → Markdown bulleted list from `constraints`, or "No additional constraints." if empty

Do not duplicate the template here; the template file is the single source of truth.

## Self-Detection

Identify which CLI you are (from the table below) and remove yourself from the reviewer list. Do not invoke yourself recursively. If all other CLIs subsequently fail, see `Execution` step 5 for the self-review fallback.

## CLI Invocation Table

| CLI | Readonly Flag | Non-Interactive Flag | Add Directory Flag | Notes |
|---------|--------------------------------------|----------------------|-------------------------|------------------------|
| Claude | `--permission-mode plan` | `--print` | `--add-dir <dir>` | Native plan mode |
| Gemini | `--approval-mode plan` | `--prompt` | `--include-directories` | Native plan mode |
| Codex | `--sandbox read-only` | `exec` | `--add-dir <dir>` | Sandboxed read-only |
| Copilot | `--available-tools="grep,glob,view"` | `--prompt <text>` | `--add-dir <dir>` | Prompt as arg, see below |

Copilot takes the prompt as a command-line argument (not stdin); use the temp-file pattern shown in `Prompt Passing` for long prompts.

## Prompt Passing

Use the correct non-interactive prompt mechanism for each CLI:

Claude:

```bash
echo "<PROMPT>" | claude --permission-mode plan --add-dir /path/to/repo --print
```

Gemini:

```bash
echo "<PROMPT>" | gemini --approval-mode plan --include-directories /path/to/repo --prompt -
```

Codex:

```bash
echo "<PROMPT>" | codex exec --sandbox read-only
```

Copilot:

```bash
PROMPT_FILE=$(mktemp) && cat <<'EOF' > "$PROMPT_FILE"
<PROMPT>
EOF
copilot --prompt "$(cat "$PROMPT_FILE")" --available-tools="grep,glob,view" --add-dir /path/to/repo --silent && rm -f "$PROMPT_FILE"
```

Replace `<PROMPT>` and `/path/to/repo` with real values.

## Preflight Checks

Before invoking any CLI:

1. If `artifact` is a filesystem path, verify it exists and is readable. If not, abort. For non-path artifacts (PR, branch, commit, design, freeform), skip this check.
2. Check each target CLI is on `PATH`. If one is missing, report it and skip it.

## Execution

1. Run all remaining CLIs in parallel as subagents.
2. Capture `CLI name`, `raw output`, and `status` for each invocation.
3. Apply a 10-minute timeout per invocation. Before killing a process that hits the timeout, ask the user whether to terminate or wait longer.
4. If a CLI errors, capture it and continue. Do not retry or guess alternate flags. Partial failure is acceptable — return all collected outputs alongside the failures.
5. If every other CLI fails (all-fail fallback), ask the user whether to perform a self-review via the current CLI before producing the final output.

## Output

Present each CLI's feedback labeled by name:

```
## Claude

<claude's feedback>

## Gemini

<gemini's feedback>

## Codex

<codex's feedback>
```

Then run the consolidation handoff step.

## Consolidation Handoff

Read `../templates/consolidate-feedbacks.template.prompt.md` (relative to this skill's directory) and execute its instructions yourself, treating the collected feedback as input. Do not print the template text to the user — produce the consolidated report it describes.

## Guardrails

- Never use judgmental or blaming language.
- Prefer concrete examples over vague statements.
- Mark uncertainty explicitly (e.g., "I'm not sure, but…").
