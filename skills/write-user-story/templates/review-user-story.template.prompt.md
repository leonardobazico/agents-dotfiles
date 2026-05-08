Review the drafted user story using only the provided inputs:

- the drafted markdown file
- a short summary of resolved refinements

Output format:

Status: approved
or
Status: needs_refinement
or
Status: too_broad

After the first line, provide:

- one short rationale grounded in this rubric
- if the status is not approved, one concrete issue to surface to the human

Rubric:

- internal consistency between summary, story statement, scope sections, and acceptance criteria
- whether the story represents a single coherent slice of value
- whether any requirement is ambiguous enough to support more than one valid interpretation
- whether the acceptance criteria are independent, testable, and free of unresolved assumptions

Rules:

- Prefer specific, concrete observations over general advice.
- Do not invent missing business requirements.
- If the story is acceptable as written, return `Status: approved`.
- If a human could refine the story with one targeted follow-up, return `Status: needs_refinement`.
- If the story is trying to deliver more than one value slice or needs too many scenarios, return `Status: too_broad`.
