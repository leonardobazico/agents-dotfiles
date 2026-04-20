A good ADR template is the one that makes the **decision, trade-offs, and consequences** easy to understand later. The focus should not be on documenting everything discussed, but on capturing **why this decision was made, what alternatives were considered, and what this means going forward**.

A practical template is:

```md
# ADR-00X: [Short decision title]

## Status
Proposed | Accepted | Superseded | Deprecated

## Context
What problem are we solving?
What constraints, risks, or business/technical drivers matter?
What assumptions are influencing the decision?

## Decision
What are we choosing?
State the decision clearly and directly.

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

## Trade-offs
What do we gain?
What do we give up?
Why is this trade acceptable now?

## Consequences
What changes now?
What are the expected impacts on architecture, delivery, operations, cost, security, or team workflow?
What new risks do we need to mitigate?

## Implementation Notes
Key follow-up actions, guardrails, or technical considerations.

## References
Links to diagrams, spikes, tickets, benchmarks, or related ADRs.
```

What matters most in a strong ADR:

* **Context over theory**: explain the real forces behind the decision
* **Decision clarity**: someone should understand the choice in one paragraph
* **Trade-offs**: show what you accepted, not only the benefits
* **Consequences**: make clear what this means operationally and architecturally
* **Why now**: decisions are usually right for a moment in time, constraints, and priorities

A weak ADR usually spends too much time describing the solution and not enough time explaining:

* why alternatives were rejected
* what risks remain
* what the organization is optimizing for, such as speed, cost, simplicity, scalability, or security
