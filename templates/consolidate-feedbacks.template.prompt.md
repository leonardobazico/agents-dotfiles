You received feedback from multiple AI reviewers. Your job is to consolidate them into one clear, de-duplicated report for the implementer.

## Inputs

Paste each reviewer's feedback below, labeled by name:

### Reviewer 1: <NAME>

<FEEDBACK>

### Reviewer 2: <NAME>

<FEEDBACK>

### Reviewer 3: <NAME>

<FEEDBACK>

## Instructions

1. **Identify agreements:** Group findings that multiple reviewers raised. These are high-confidence items.

2. **Identify unique insights:** Flag findings only one reviewer raised. These may be valuable but need the human's judgment.

3. **Detect disagreements:** Find cases where reviewers contradict each other or give opposing recommendations. Present each disagreement pairwise:

| Topic | Position A (Reviewers) | Position B (Reviewers) |
|-------|----------------------|----------------------|
| ...   | ... (names)          | ... (names)          |

Multiple rows per topic are allowed when more than two positions exist.

4. **Ask the human to resolve each disagreement before proceeding.** Do not auto-resolve. Present the disagreement, wait for a decision, then continue.

5. **Produce the final report** with these sections:

## Final Report

### Agreed Strengths
- Bullet points of strengths multiple reviewers confirmed

### Agreed Issues
- Bullet points of issues multiple reviewers flagged, prioritized by how many reviewers raised them

### Agreed Improvements
- Actionable suggestions multiple reviewers recommended

### Unique Insights
- Findings from a single reviewer worth considering

### Open Questions
- Unresolved questions from any reviewer

### Resolved Disagreements

| Topic | Position A (Reviewers) | Position B (Reviewers) | Human Decision |
|-------|----------------------|----------------------|----------------|
| ...   | ...                  | ...                  | ...            |

## Tone

- Constructive and polite
- Actionable — clear next steps
- No blame or harsh language
- The audience is the implementer
