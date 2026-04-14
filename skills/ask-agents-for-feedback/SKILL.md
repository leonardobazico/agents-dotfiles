---
name: ask-agents-for-feedback
description: "Use when you need independent AI peer review from multiple CLIs for any artifact. Orchestrates parallel readonly invocations, collects feedback, and hands off to consolidation."
---

# ask-agents-for-feedback

Orchestrate parallel, readonly AI peer reviews from multiple CLI agents and collect their independent feedback on any artifact.

## When To Use

Use this skill when you need independent feedback from multiple AI CLIs on any of these artifact types:

- Documents — READMEs, specs, design docs, ADRs
- Code — source files, modules, libraries, scripts
- Plans — implementation plans, migration plans, roadmaps
- PRs — pull request diffs and descriptions
- Designs — architecture diagrams, API designs, schema designs

## Inputs

| Input          | Required | Description                                                        |
|----------------|----------|--------------------------------------------------------------------|
| `artifactType` | Yes      | One of: `DOCUMENT`, `CODE`, `PLAN`, `PR`, `DESIGN`, `OTHER`       |
| `artifactPath` | Yes      | Filesystem path to the artifact under review                       |
| `focusAreas`   | No       | List of specific areas to focus the review on                      |
| `constraints`  | No       | List of constraints or rules the reviewers should respect          |

## Prompt Construction

Read the review prompt template from `templates/ask-agents-for-feedback.template.prompt.md` (co-located at `skills/ask-agents-for-feedback/templates/ask-agents-for-feedback.template.prompt.md`). Replace the placeholders with the inputs above:

- `<ARTIFACT_TYPE>` → value of `artifactType`
- `<PATH>` → value of `artifactPath`
- `<FOCUS_AREAS>` → formatted list from `focusAreas`, or "No specific focus areas — review holistically." if empty
- `<CONSTRAINTS>` → formatted list from `constraints`, or "No additional constraints." if empty

Do not duplicate the prompt template content here. The template file is the single source of truth.

## Self-Detection

You are running as one of the CLIs listed below. Identify which one you are and remove yourself from the reviewer list before executing. You must not invoke yourself recursively.

## CLI Invocation Table

| CLI     | Readonly Flag                        | Non-Interactive Flag | Add Directory Flag      | Notes                                                                                          |
|---------|--------------------------------------|----------------------|-------------------------|------------------------------------------------------------------------------------------------|
| Claude  | `--permission-mode plan`             | `--print`            | `--add-dir <dir>`       | Native plan mode                                                                               |
| Gemini  | `--approval-mode plan`               | `--prompt`           | `--include-directories` | Native plan mode                                                                               |
| Codex   | `--sandbox read-only`                | `exec`               | `--add-dir <dir>`       | Sandboxed read-only                                                                            |
| Copilot | `--available-tools="grep,glob,view"` | `--prompt <text>`          | `--add-dir <dir>`       | Takes prompt as argument (not stdin). Use temp file + command substitution for long prompts |

## Prompt Passing

Each CLI has a different mechanism for receiving prompts non-interactively. Use the correct method per CLI:

Claude — reads prompt from stdin via `--print`:
```bash
echo "<PROMPT>" | claude --permission-mode plan --add-dir /path/to/repo --print
```

Gemini — reads prompt from stdin via `--prompt -`:
```bash
echo "<PROMPT>" | gemini --approval-mode plan --include-directories /path/to/repo --prompt -
```

Codex — reads prompt from stdin via `exec`:
```bash
echo "<PROMPT>" | codex exec --sandbox read-only
```

Copilot — takes prompt as a direct argument to `--prompt`, does NOT read stdin. Write the prompt to a temp file and pass it via command substitution:
```bash
PROMPT_FILE=$(mktemp) && cat <<'EOF' > "$PROMPT_FILE"
<PROMPT>
EOF
copilot --prompt "$(cat "$PROMPT_FILE")" --available-tools="grep,glob,view" --add-dir /path/to/repo --quiet && rm -f "$PROMPT_FILE"
```

Replace `<PROMPT>` with the fully constructed prompt and `/path/to/repo` with the actual repository root.

## Preflight Checks

Before invoking any CLI, perform these checks:

1. Artifact exists and is readable. Verify that `artifactPath` points to an existing, readable file. If not, abort with an error.
2. CLI binary is installed and on `PATH`. For each target CLI, check that the binary is available (e.g., `which claude`). If a CLI is not found, report it and skip that CLI — do not fail the entire run.

## Execution

1. After preflight, run all remaining CLIs in parallel as subagents.
2. Each invocation returns:
   - CLI name — which agent produced the output
   - Raw output — the full response text
   - Status — success or failure
3. Apply a reasonable timeout per invocation. If a CLI times out, mark it as failed.
4. Fail fast on errors — if a CLI returns an error, capture it and move on. Do not attempt to adapt flags, retry with `--help`, or guess alternative invocations.

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

Then ask:

> Would you like me to consolidate these into a final report? If yes, I'll use the consolidation prompt to detect disagreements and produce a de-duplicated report.

## Consolidation Handoff

If the user requests consolidation, read the consolidation prompt from `templates/consolidate-feedbacks.template.prompt.md` (co-located at `skills/ask-agents-for-feedback/templates/consolidate-feedbacks.template.prompt.md`) and follow its instructions, passing all collected feedback as input.

## Guardrails

- Never use judgmental or blaming language.
- Prefer concrete examples over vague statements.
- Mark uncertainty explicitly (e.g., "I'm not sure, but…").
