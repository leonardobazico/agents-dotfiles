Draft an architecture decision record from the resolved refinements.

This ADR is an input to a future team discussion, not a recorded decision. Populate `Context`, `Options Considered`, `Recommendation` (with nested `Consequences if adopted`), and leave the `Decision` section as a placeholder for the team to fill in after the discussion. Status stays `Proposed`.

Keep the ADR concise. Do not turn it into a design document, implementation plan, or project retrospective. Do not invent context, drivers, options, pros, cons, or consequences that were not resolved during refinement.

Write `Context`, `Options Considered`, `Recommendation`, and `Consequences` so a diverse team (QAs, product managers, software engineers, data engineers, architects) can follow without specialist jargon.

Avoid em dashes in written ADRs. Use commas, colons, parentheses, or periods instead.

Use this structure:

# ADR-TBD: [Short decision title]

## Status
Proposed

## Context
What problem are we solving?
What constraints, risks, or business/technical drivers matter?
What assumptions are influencing the decision?

## Options Considered
### Option 1: [Name]
Pros:
- ...
Cons:
- ...

### Option 2: [Name]
Pros:
- ...
Cons:
- ...

### Option 3: [Name]
Pros:
- ...
Cons:
- ...

## Recommendation
Which option looks strongest right now, and why?
State this as a tentative recommendation for the team to confirm, modify, or reject. Do not phrase it as a final decision.

### Consequences (if adopted)
If the team adopts the recommendation: what would change in architecture, delivery, operations, cost, security, or team workflow?
What new risks would need to be mitigated?

## Decision
_To be completed by the team after discussion. When filled in, update `Status` to `Accepted`._

## References
Links to diagrams, spikes, tickets, benchmarks, or related ADRs.

Guidance for the agent (do not include in the output):

- Replace `ADR-TBD` in the heading only when the human provides a number or the repo's numbering convention is unambiguous.
- Status is always `Proposed` in drafts produced by this skill. The team updates it to `Accepted` (or later `Superseded`) after the discussion. `Deprecated` is set even later by humans on an already-accepted ADR.
- Leave the `## Decision` body as the literal placeholder above. Do not fill it in, even if the human seems to favor an option during refinement. The recommendation is where preference is expressed.
- `Recommendation` is a tentative preferred option, not a decision. Use language like "Option 2 looks strongest because…, subject to team confirmation." Never write "We have decided…".
- Per-option `Pros` / `Cons` carry the trade-off material. Do not add a separate `Trade-offs` section.
- Scope `Consequences (if adopted)` to the recommended option. Make it concrete (architecture, operations, delivery, risk, workflow) rather than vague prose.
- Omit `References` only when there genuinely are none.
