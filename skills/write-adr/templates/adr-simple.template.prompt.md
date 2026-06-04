Draft an architecture decision record from the resolved refinements using this lighter template.

This ADR is an input to a future team discussion, not a recorded decision. Populate `Context`, `Options`, `Recommendation` (with nested `Consequences if adopted`), and leave the `Decision` section as a placeholder for the team to fill in after the discussion. Status stays `Proposed`.

Use this template when options can be expressed as one-line summaries. Otherwise use the full template.

Keep the ADR concise. Do not turn it into a design document, implementation plan, or project retrospective. Do not invent context, options, or consequences that were not resolved during refinement.

Write `Context`, `Options`, `Recommendation`, and `Consequences` so a diverse team (QAs, product managers, software engineers, data engineers, architects) can follow without specialist jargon.

Avoid em dashes in written ADRs. Use commas, colons, parentheses, or periods instead.

Use this structure:

# ADR-TBD: [Short decision title]

## Status
Proposed

## Context
What problem are we solving?
What are the main constraints or drivers?

## Options
- Option A: one-line summary
- Option B: one-line summary
- Option C: one-line summary

## Recommendation
Which option looks strongest right now, and why, as a tentative recommendation for the team to confirm. Include the main trade-off inline (what we give up by choosing it).

### Consequences (if adopted)
What would change if the recommendation is adopted?
What are the impacts, risks, or follow-up actions the team should weigh?

## Decision
_To be completed by the team after discussion. When filled in, update `Status` to `Accepted`._

Guidance for the agent (do not include in the output):

- Replace `ADR-TBD` in the heading only when the human provides a number or the repo's numbering convention is unambiguous.
- Status is always `Proposed` in drafts produced by this skill. The team updates it to `Accepted` (or later `Superseded`) after the discussion. `Deprecated` is set even later by humans on an already-accepted ADR.
- Leave the `## Decision` body as the literal placeholder above. Do not fill it in, even if the human seems to favor an option during refinement.
- `Recommendation` is a tentative preferred option, not a decision. Use language like "Option A looks strongest because…, subject to team confirmation." Never write "We have decided…".
- A weak ADR over-describes the solution and under-explains why alternatives were rejected, what risks remain, and what the team is optimizing for: speed, cost, simplicity, scalability, or security.
