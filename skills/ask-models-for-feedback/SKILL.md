---
name: ask-models-for-feedback
description: "Use when you need independent AI peer review from other Claude models for any artifact, within the current session. Suggests 2 candidate models when none are specified, dispatches parallel readonly subagents via the Agent tool with a model override, collects feedback, and hands off to consolidation."
---

# ask-models-for-feedback

Get independent review of an artifact from other Claude models in the current session, using the `Agent` tool's `model` override instead of a separate CLI process.

## When To Use

Use when you want independent review from other Claude models for an artifact such as:

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
- `models` — optional; list of model IDs/aliases the human wants review from. When omitted, see Model Selection below.

## Model Selection

Never hardcode a model name or ID in this skill or at runtime. Every model identifier comes from the current session's context or from the human.

1. If `models` was provided, use those and skip to step 6.
2. Otherwise, read the model IDs/aliases already stated in the current session's environment/system context (e.g. a "Model IDs" listing), and identify the model currently driving this conversation.
3. Exclude the current model from the candidate list.
4. Pick 2 candidates from what's left, preferring diversity in capability/reasoning tier when the context distinguishes tiers (e.g. don't suggest two aliases of the same underlying model).
5. If fewer than 2 other models can be identified from context, state what was found and ask the human to name the rest. Do not invent a model identifier.
6. Present the suggested (or human-given) models and wait for explicit approval, a swap, or additions. Do not dispatch any subagent before this confirmation.

## Prompt Construction

Read the shared `../templates/request-feedback.template.prompt.md` file (relative to this skill's directory) and replace each placeholder. Format multi-value fields as Markdown bulleted lists.

- `<ARTIFACT_TYPE>` → value of `artifactType`
- `<ARTIFACT>` → value of `artifact`
- `<RELEVANT_PATHS>` → Markdown bulleted list from `relevantPaths`, or "No specific paths — explore as needed." if empty
- `<FOCUS_AREAS>` → Markdown bulleted list from `focusAreas`, or "No specific focus areas — review holistically." if empty
- `<CONSTRAINTS>` → Markdown bulleted list from `constraints`, or "No additional constraints." if empty

This template is shared with `ask-agents-for-feedback`; do not duplicate it here.

## Preflight Checks

Before dispatching any subagent:

1. If `artifact` is a filesystem path, verify it exists and is readable. If not, abort. For non-path artifacts (PR, branch, commit, design, freeform), skip this check.
2. Complete Model Selection and get explicit human confirmation of the model list.

## Execution

1. For each confirmed model, dispatch one subagent via the `Agent` tool with `subagent_type: Plan` (readonly by construction — no Edit/Write/Agent tools) and `model: <id>` set to that model's identifier.
2. Dispatch all confirmed models' subagents in a single message so they run in parallel.
3. Capture `model name`, `raw output`, and `status` for each dispatch.
4. If a subagent errors, capture it and continue. Do not retry or guess alternate parameters. Partial failure is acceptable — return all collected outputs alongside the failures.
5. If every subagent fails, ask the user whether to perform a self-review via the current model before producing the final output.

## Output

Present each model's feedback labeled by name:

```
## <Model A name>

<model A's feedback>

## <Model B name>

<model B's feedback>
```

Then run the consolidation handoff step.

## Consolidation Handoff

Read `../templates/consolidate-feedbacks.template.prompt.md` (relative to this skill's directory) and execute its instructions yourself, treating the collected feedback as input. Do not print the template text to the user — produce the consolidated report it describes.

## Guardrails

- Never use judgmental or blaming language.
- Prefer concrete examples over vague statements.
- Mark uncertainty explicitly (e.g., "I'm not sure, but…").
