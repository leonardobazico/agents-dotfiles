Create a user story from the resolved requirements.

Keep the story business-oriented and concise. Do not turn it into a design document or implementation plan. Do not invent unsupported requirements.
Avoid em dashes (—) punctuation in written stories. Use other punctuation like colons, parentheses, commas, or periods.

Use this structure:

# User Story Title

Write a short business-oriented description of the problem being solved, why it matters, and the value of solving it. Focus on the user and the business outcome, not the implementation.

## User Story
As a [type of user]
I want [some goal]
so that [some reason]

## Technical Notes

Include this section only when it materially helps orient implementation. Keep it minimal and reference-oriented.

Examples:
- Update existing endpoint `POST /api/v1/endpoint` to include new query parameters for filtering.
- Reference ADR: `[path-to-file](url-to-file)`
- Figma reference: `[label](url-to-figma)`

## Out of Scope

This section is optional. Use it to list simple bullet points for items that are explicitly excluded from the story, especially when a broader request was split and only one slice is being kept.

## Open Questions

This section is optional. Use it only for genuine unresolved unknowns. Do not use it for details that were already clarified or could be inferred from the accepted story scope.

If an optional section is not needed, omit its heading entirely.

## Acceptance Criteria

Write independent, testable Gherkin scenarios using Given / When / Then steps.

Requirements:
- Prefer 2-5 scenarios when possible.
- Include both happy and unhappy paths.
- Keep scenarios non-overlapping and grounded in the agreed story scope.
- If more than 5 scenarios seem necessary, that is a warning that the story may be too broad.
- Do not encode unresolved assumptions into the acceptance criteria.

Example shape:

Scenario: **Title of the scenario being described**
Given some initial context or state of the system
And some other state if needed
When some action is taken or some event occurs
And some other action if needed
Then some expected outcome should happen
And some other expected outcome if needed
