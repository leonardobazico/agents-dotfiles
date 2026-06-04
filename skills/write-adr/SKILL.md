---
name: write-adr
description: Use when an architectural or technical decision needs an ADR draft that captures context, options, trade-offs, a tentative recommendation, and consequences as input for a team discussion that will finalize the decision.
---

# write-adr

Create an architecture decision record draft from a problem statement, meeting notes, or a partial set of trade-offs. The ADR is an input to a future team discussion, not a recorded decision: it captures context, options, trade-offs, a tentative recommendation, and consequences so the team can converge. Refine the inputs one question at a time, choose the right ADR template, write the ADR to `docs/adr/`, run a constrained review step, resolve any needed follow-up with the human, and stop after asking the human to review the written file.

## Defaults

- Output directory: `docs/adr/`
- Full draft prompt: `templates/adr.template.prompt.md`
- Simple draft prompt: `templates/adr-simple.template.prompt.md`
- Review prompt: `templates/review-adr.template.prompt.md`

All template paths are co-located with the skill and must be resolved relative to `SKILL.md`, not the current working directory or the repository root.

Override precedence:

1. invocation-time override
2. discovered repo convention (e.g., existing ADR location or numbering pattern surfaced in step 1)
3. skill built-in default

This precedence applies to the output directory, filename convention, template choice, and draft or review prompt paths.

## Hard Gates

- Do not invent decision drivers, options, trade-offs, constraints, or consequences.
- Do not ask multiple refinement questions in one message.
- Do not turn the ADR into a design doc, implementation plan, or project retrospective.
- Do not finalize the decision. The skill writes a tentative `Recommendation` and leaves the `Decision` section as a placeholder for the team. Do not fill in the `Decision` body even if the human seems to favor an option during refinement.
- Do not invent an ADR sequence number when the repo convention is unclear.
- Status is always `Proposed` in drafts produced by this skill. Do not set `Accepted`, `Superseded`, or `Deprecated`. The team updates the status after the discussion.
- Do not commit generated ADR files.
- Do not continue into implementation planning after the ADR is written and reviewed by the human.

## Workflow

### 1. Explore minimal context

Before detailed questioning, inspect only enough repository context to avoid conflicting with existing conventions. Focus on documentation layout, ADR locations, numbering patterns, nearby plans or specs, and any directly related decision artifacts.

Keep this exploration lightweight. Do not wander through unrelated parts of the repo.

If you discover an existing ADR directory that differs from `docs/adr/`, or a numbering convention that differs from `ADR-NNN-<slug>.md`, use the discovered convention and tell the human you are doing so.

### 2. Refine one question at a time

The normal input to this skill is a rough problem statement, meeting outcome, or partial set of trade-offs. Ask one question at a time until all critical ADR inputs are clear enough to draft without guessing:

- short decision title
- problem and context
- key drivers, constraints, or assumptions
- options to weigh, with pros and cons per option (one-line summaries are fine for the simple template)
- which option currently looks strongest, and why (captured as a tentative recommendation, not a decision)
- consequences if the recommendation is adopted: risks, follow-up actions, impacts on architecture, delivery, operations, cost, security, or team workflow
- related references
- whether the full or simple template is the better fit

Status is always `Proposed` in skill-authored drafts. Never ask the human to pick a status.

Maintain a short running summary of resolved refinements during the workflow. Keep it compact and focused on inputs that materially affect the ADR and review step.

Ask the smallest next refinement question that materially changes the options, trade-offs, recommendation, or consequences.

If the user's initial prompt already contains the context, drivers, options, trade-offs, a recommendation, and consequences clearly enough to draft without guessing, you may skip the refinement loop. Treat that as the exception, not the default use case. If you skip it, explicitly tell the human that refinement is being skipped because the provided input is already complete enough to draft.

When ambiguity remains, keep asking focused questions rather than filling gaps yourself.

### 3. Choose the ADR template

Both templates carry `Context`, options, `Recommendation`, `Consequences (if adopted)`, and a `Decision` placeholder. The difference is depth.

Use the simple template only when all of these hold:

- options can be expressed as one-line summaries (no per-option pros/cons lists)
- no `References` section is needed
- the human has not asked for the full template

Otherwise use the full template. If you are unsure, prefer the full template. Do not inflate a narrow decision into a heavyweight ADR just to fill sections.

Do not read either prompt yet. The selected prompt is read in step 4.

### 4. Draft the ADR

Read the selected draft prompt and use it as the baseline structure.

The ADR should include:

- a clear title
- status (always `Proposed`)
- context
- options (per-option pros/cons in the full template, one-line summaries in the simple template)
- recommendation (tentative, for the team to confirm; not a decision)
- consequences if adopted (nested under recommendation)
- decision (placeholder only, for the team to complete)

Include `references` only when the chosen template calls for it and there is something to reference.

Keep the output concise and oriented to the team that will finalize the decision.

#### ADR Numbering

If the repository already has a clear ADR numbering convention, follow it.

If the human provides an ADR number, use it.

If numbering is unclear and no number is provided, do not guess. Leave the heading as `ADR-TBD: <title>` and use a date-based filename. Surface this to the human so they can assign the sequence number later.

#### ADR Identifier Normalization

When an ADR identifier is provided by the human, normalize it before using it in the heading or filename:

- strip any leading `ADR-` (case-insensitive)
- zero-pad to at least 3 digits (e.g. `7` → `007`, `42` → `042`, `1234` stays `1234`)
- format the heading as `ADR-<NNN>: <title>` and the filename as `ADR-<NNN>-<slug>.md`

If step 1 surfaced a different repo convention (e.g. `0001-slug.md` without the `ADR-` prefix), use the repo's pattern exactly and skip this normalization.

### 5. Choose the output path and write the file

Resolve the output directory in this order:

1. an explicit invocation-time override
2. a discovered repo ADR location from step 1
3. the default `docs/adr/`

Ensure the chosen directory exists before writing.

Filename rules, applied in order:

1. if step 1 surfaced a clear repo filename convention, use it exactly
2. else, if a normalized ADR identifier is available, write to `<dir>/ADR-<NNN>-<slug>.md`
3. else, write to `<dir>/YYYY-MM-DD-<slug>.md`

Derive the slug from the resolved ADR title.

If an explicit alternate output path is provided, treat it as a directory path and apply the same filename rules inside that directory.

If the target filename already exists, ask the human whether to overwrite, rename, or cancel before writing.

`rename` means choosing a different filename for the new ADR while leaving the existing file untouched.

Write the file before asking for approval.

### 6. Run the review subagent loop

After writing the file, run the review step in one of these two modes:

- preferred: dispatch a constrained review subagent when the platform supports it
- fallback: perform an inline self-review using the same bundled rubric, clearly separated from the drafting step

The review input must be limited to:

- the drafted markdown file
- a short summary of resolved refinements
- the review rubric from `templates/review-adr.template.prompt.md`

The review step must return one of:

- `approved`
- `needs_refinement`
- `too_broad`

The review must check:

- internal consistency between the summary, context, options, recommendation, and consequences
- whether the ADR captures one coherent decision input rather than several bundled decisions
- whether the recommendation is grounded in the per-option pros/cons (or one-line options in the simple template)
- whether the recommendation is phrased as a tentative suggestion, not a final decision
- whether `Consequences (if adopted)` is scoped to the recommended option and is concrete
- whether the `Decision` section is left as the literal placeholder (not filled in by the skill)
- whether `Status` is `Proposed`
- whether the chosen template is proportionate to the decision input
- whether any statement is ambiguous enough to support more than one valid interpretation

Allow at most 3 unsuccessful review cycles.

If the review returns `needs_refinement`, ask the human a single refinement question, update the file, and rerun the review.

If the human decides the ambiguity is acceptable or wants to proceed as-is, the human is the final authority. Honor that decision and move to the human review gate.

If the review returns `too_broad`, ask the human whether to split the ADR or keep it as-is.

If the human chooses to split:

- propose decision boundaries
- let the human choose the single decision this ADR should keep
- rewrite only that one ADR
- surface excluded decisions to the human as follow-up candidates, not as hidden prose inside the ADR

If the human chooses to keep it as-is, record that they accepted a bundled ADR, stop rerunning the review, and proceed directly to the human review gate.

Do not decompose automatically without that human decision.

If the review loop reaches 3 unsuccessful cycles without approval or an explicit human override, stop rerunning the review and surface the remaining issues to the human for guidance.

### 7. Human review gate

Once the review loop passes, or the human explicitly chooses to proceed, ask the human to review the written file and stop there.

Do not commit the file. Do not move into implementation planning automatically.

## Output Message

When the workflow completes, use this shape:

> ADR written to `<path>`. Please review it and let me know if you want any changes.

## Guardrails

- Prefer direct, narrow refinement questions over open-ended architecture interviews.
- Preserve the human's optimization language when it is clear: cost, speed, simplicity, reliability, security, or operability.
- When alternatives are unknown, ask for them or explicitly mark them as not yet captured. Do not fabricate rejected options.
- Keep consequences concrete. Favor changes to architecture, operations, delivery, risk, or team workflow over vague prose.
- Write `Context`, options, `Recommendation`, and `Consequences` so a diverse team (QAs, product managers, software engineers, data engineers, architects) can follow without specialist jargon.
- Phrase the recommendation as tentative ("Option B looks strongest because…, subject to team confirmation"). Never phrase it as a decided outcome.
- Leave the `Decision` section as the literal placeholder from the template. The team completes it after the discussion.
- Use the simple template to reduce friction, not to skip the rationale.
- Avoid em dashes in written ADRs. Use commas, colons, parentheses, or periods instead.
