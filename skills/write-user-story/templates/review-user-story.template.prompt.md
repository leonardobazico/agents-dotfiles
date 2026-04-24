Review the drafted user story using only the provided inputs:

- the drafted markdown file
- a short summary of resolved clarifications

Return exactly one status:

- approved
- needs_refinement
- too_broad

Then provide a short explanation grounded in this rubric:

- internal consistency between summary, story statement, scope sections, and acceptance criteria
- whether the story represents a single coherent slice of value
- whether any requirement is ambiguous enough to support more than one valid interpretation
- whether the acceptance criteria are independent, testable, and free of unresolved assumptions

Rules:

- Prefer specific, concrete observations over general advice.
- Do not invent missing business requirements.
- If the story is acceptable as written, return `approved`.
- If a human could refine the story with one targeted follow-up, return `needs_refinement`.
- If the story is trying to deliver more than one value slice or needs too many scenarios, return `too_broad`.
