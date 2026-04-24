---
name: write-user-story
description: Turn a rough feature idea into a written user story through one-question-at-a-time refinement, file generation, and a constrained review loop.
---

# write-user-story

Create a business-oriented user story from a rough idea or feature list. Clarify requirements one question at a time, write the story to `docs/user-story/`, run a constrained review subagent, resolve any needed follow-up with the human, and stop after asking the human to review the written file.

## Defaults

- Output directory: `docs/user-story/`
- Draft prompt: `templates/user-story.template.prompt.md`
- Review prompt: `templates/review-user-story.template.prompt.md`

These are defaults, not hard requirements. If the consuming repository explicitly provides a different output path or prompt location, follow that override instead.

## Hard Gates

- Do not invent critical business rules, actors, or acceptance-criteria behavior.
- Do not ask multiple refinement questions in one message.
- Do not turn the story into a design doc or implementation plan.
- Do not commit generated story files.
- Do not continue into implementation planning after the story is written and reviewed by the human.

## Workflow

### 1. Explore minimal context

Before detailed questioning, inspect only enough repository context to avoid conflicting with existing conventions. Focus on documentation layout, naming patterns, existing story locations, and any nearby artifacts directly relevant to the requested story.

Keep this exploration lightweight. Do not wander through unrelated parts of the repo.

### 2. Refine one question at a time

The normal input to this skill is a rough idea or feature list. Ask one question at a time until all critical story inputs are clear enough to draft without guessing:

- actor or user type
- desired outcome
- business value
- scope boundaries
- key rules or constraints
- testable outcomes for acceptance criteria

If the user's initial prompt already contains actor, outcome, business value, scope boundaries, and testable outcomes clearly enough to draft without guessing, you may skip the refinement loop. Treat that as the exception, not the default use case.

When ambiguity remains, keep asking focused questions rather than filling gaps yourself.

### 3. Draft the user story

Read the bundled draft prompt from `templates/user-story.template.prompt.md` and use it as the baseline structure. The draft should include:

- title
- short business-oriented problem statement
- `As a / I want / so that`
- optional `Technical Notes`
- optional `Out of Scope`
- optional `Open Questions`
- `Acceptance Criteria` in Gherkin format

Keep the output concise and business-first.

#### Technical Notes

`Technical Notes` are optional. Include them only when they materially orient implementation without becoming a design doc. Keep them minimal and reference-oriented.

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

- if a card number is provided, write to `docs/user-story/<CARD_NUMBER>-<slug>.md`
- otherwise write to `docs/user-story/YYYY-MM-DD-<slug>.md`

Derive the slug from the resolved story title or the clearest business-oriented summary gathered during refinement.

If the target filename already exists, ask the human whether to overwrite, rename, or cancel before writing.

Write the file before asking for approval.

### 5. Run the review subagent loop

After writing the file, dispatch a constrained review subagent modeled after the brainstorming review flow.

The subagent input must be limited to:

- the drafted markdown file
- a short summary of resolved refinements
- the review rubric from `templates/review-user-story.template.prompt.md`

The review subagent must return one of:

- `approved`
- `needs_refinement`
- `too_broad`

The review must check:

- internal consistency between summary, story statement, scope sections, and acceptance criteria
- single-value-delivery scope
- ambiguity that could support more than one valid interpretation
- acceptance criteria quality

Allow at most 3 unsuccessful review cycles.

If the subagent returns `needs_refinement`, ask the human a single refinement question, update the file, and rerun the review.

If the human decides the ambiguity is acceptable or wants to proceed as-is, the human is the final authority. Honor that decision and move to the human review gate.

If the subagent returns `too_broad`, ask the human whether to split the story or keep it as-is.

If the human chooses to split:

- propose split boundaries
- let the human choose the slice to keep
- rewrite only that single story
- move excluded items into `Out of Scope` as simple bullet points

Do not decompose automatically without that human decision.

If the review loop reaches 3 unsuccessful cycles without approval or an explicit human override, stop rerunning the subagent and surface the remaining issues to the human for guidance.

### 6. Human review gate

Once the review loop passes, or the human explicitly chooses to proceed, ask the human to review the written file and stop there.

Do not commit the file. Do not move into implementation planning automatically.

## Output Message

When the workflow completes, use this shape:

> User story written to `<path>`. Please review it and let me know if you want any changes.

## Guardrails

- Prefer direct, simple questions over broad discovery dumps.
- Preserve the user's terminology when it is clear and consistent.
- Reserve `Open Questions` for genuine unresolved unknowns, not missing diligence.
- Keep anything excluded during split decisions in `Out of Scope`, not hidden in prose.
