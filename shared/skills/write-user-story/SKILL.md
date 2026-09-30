---
name: write-user-story
description: Turn a rough feature idea into a written user story through one-question-at-a-time refinement, file generation, and a constrained review loop.
---

# write-user-story

Create a business-oriented user story from a rough idea or feature list. Refine requirements one question at a time,
write the story to `docs/user-stories/`, run a constrained review step, resolve any needed follow-up with the human, and
stop after asking the human to review the written file.

## Defaults

- Output directory: `docs/user-stories/`
- Draft prompt: `templates/user-story.template.prompt.md`
- Review prompt: `templates/review-user-story.template.prompt.md`

These paths are co-located with the skill and must be resolved relative to `SKILL.md`, not the current working directory
or the repository root.

Override precedence:

1. invocation-time override
2. repo-provided default
3. skill built-in default

This precedence applies to the output directory, filename convention, draft prompt path, and review prompt path.

## Hard Gates

- Do not invent critical business rules, actors, or acceptance-criteria behavior.
- Do not ask multiple refinement questions in one message.
- Do not turn the story into a design doc or implementation plan.
- Do not commit generated story files.
- Do not continue into implementation planning after the story is written and reviewed by the human.

## Workflow

### 1. Explore minimal context

Before detailed questioning, inspect only enough repository context to avoid conflicting with existing conventions.
Focus on documentation layout, naming patterns, existing story locations, and any nearby artifacts directly relevant to
the requested story.

Keep this exploration lightweight. Do not wander through unrelated parts of the repo.

### 2. Refine one question at a time

The normal input to this skill is a rough idea or feature list. Ask one question at a time until all critical story
inputs are clear enough to draft without guessing:

- actor or user type
- desired outcome
- business value
- scope boundaries
- key rules or constraints
- testable outcomes for acceptance criteria

Maintain a short running summary of resolved refinements during the workflow. Keep it compact and focused on the
decisions that materially affect the drafted story and review step.

Ask the smallest next refinement question that materially changes scope, business value, or acceptance criteria.

If the user's initial prompt already contains actor, outcome, business value, scope boundaries, and testable outcomes
clearly enough to draft without guessing, you may skip the refinement loop. Treat that as the exception, not the default
use case. If you skip it, explicitly tell the human that refinement is being skipped because the provided input is
already complete enough to draft.

When ambiguity remains, keep asking focused questions rather than filling gaps yourself.

### 3. Draft the user story

Read the bundled draft prompt from `templates/user-story.template.prompt.md` and use it as the baseline structure. The
draft should include:

- title
- short business-oriented problem statement
- `As a / I want / so that`
- optional `Technical Notes`
- optional `Out of Scope`
- optional `Open Questions`
- `Acceptance Criteria` in Gherkin format

Keep the output concise and business-first.

#### Technical Notes

`Technical Notes` are optional. Include them only when they materially orient implementation without becoming a design
doc. Keep them minimal and reference-oriented.

Examples:

- update an existing endpoint to support a new filter
- reference an ADR path
- link to a Figma artifact

#### Acceptance Criteria

Acceptance criteria must:

- be independent and testable
- include happy and unhappy paths
- usually land in the 2-5 scenario range

If more than five scenarios are needed, treat that as a scope warning and review whether the story should be split.

### 4. Choose the output path and write the file

Ensure the output directory exists before writing.

Filename rules:

- if a card number is provided, write to `docs/user-stories/<CARD_NUMBER>-<slug>.md`
- otherwise write to `docs/user-stories/YYYY-MM-DD-<slug>.md`

Derive the slug from the resolved story title.

If an explicit alternate output path is provided, treat it as a directory path and apply the same filename rules inside
that directory.

If the target filename already exists, ask the human whether to overwrite, rename, or cancel before writing.

`rename` means choosing a different filename for the new story while leaving the existing file untouched.

Write the file before asking for approval.

### 5. Run the review subagent loop

After writing the file, run the review step in one of these two modes:

- preferred: dispatch a constrained review subagent when the platform supports it
- fallback: perform an inline self-review using the same bundled rubric, clearly separated from the drafting step

The review input must be limited to:

- the drafted markdown file
- a short summary of resolved refinements
- the review rubric from `templates/review-user-story.template.prompt.md`

The review step must return one of:

- `approved`
- `needs_refinement`
- `too_broad`

The review must check:

- internal consistency between summary, story statement, scope sections, and acceptance criteria
- single-value-delivery scope
- ambiguity that could support more than one valid interpretation
- acceptance criteria quality

Allow at most 3 unsuccessful review cycles.

If the review returns `needs_refinement`, ask the human a single refinement question, update the file, and rerun the
review.

If the human decides the ambiguity is acceptable or wants to proceed as-is, the human is the final authority. Honor that
decision and move to the human review gate.

If the review returns `too_broad`, ask the human whether to split the story or keep it as-is.

If the human chooses to split:

- propose split boundaries
- let the human choose the slice to keep
- rewrite only that single story
- move excluded items into `Out of Scope` as simple bullet points

Do not decompose automatically without that human decision.

If the review loop reaches 3 unsuccessful cycles without approval or an explicit human override, stop rerunning the
review and surface the remaining issues to the human for guidance.

### 6. Human review gate

Once the review loop passes, or the human explicitly chooses to proceed, ask the human to review the written file and
stop there.

Do not commit the file. Do not move into implementation planning automatically.

## Output Message

When the workflow completes, use this shape:

> User story written to `<path>`. Please review it and let me know if you want any changes.

## Guardrails

- Prefer direct, simple questions over broad discovery dumps.
- Preserve the user's terminology when it is clear and consistent.
- Reserve `Open Questions` for genuine unresolved unknowns, not missing diligence.
- Keep anything excluded during split decisions in `Out of Scope`, not hidden in prose.
- Avoid em dashes (—) punctuation in written stories. Use other punctuation like colons, parentheses, commas, or
  periods.
