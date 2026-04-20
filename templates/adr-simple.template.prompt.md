A good ADR template is the one that makes the **decision, trade-offs, and consequences** easy to understand later. The focus should not be on documenting everything discussed, but on capturing **why this decision was made, what alternatives were considered, and what this means going forward**.

A practical template is:

```md
# ADR-00X: [Short decision title]

## Status
Proposed | Accepted | Superseded

## Context
What problem are we solving?
What are the main constraints or drivers?

## Decision
What did we choose?

## Why
Why is this the best option right now?
What trade-offs are we accepting?

## Consequences
What happens next?
What are the impacts, risks, or follow-up actions?
```

This works well when:

the decision is important enough to record
the alternatives are simple or already known by the team
you want low friction so ADRs become part of daily engineering work

If you want it even leaner, you can compress it to:

```md
# ADR-00X: [Title]

- **Status:** Accepted
- **Context:** ...
- **Decision:** ...
- **Rationale:** ...
- **Consequences:** ...
```

A weak ADR usually spends too much time describing the solution and not enough time explaining:

* why alternatives were rejected
* what risks remain
* what the organization is optimizing for, such as speed, cost, simplicity, scalability, or security
