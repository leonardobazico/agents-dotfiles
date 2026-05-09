Consolidate feedback from multiple AI reviewers into one de-duplicated report for the implementer.

## Inputs

Paste each review below, labeled by reviewer:

### Reviewer 1: <NAME>

<FEEDBACK>

### Reviewer 2: <NAME>

<FEEDBACK>

### Reviewer 3: <NAME>

<FEEDBACK>

## Instructions

1. **Identify agreements.** Group findings raised by multiple reviewers; these are higher-confidence items.

2. **Identify unique insights.** Flag findings raised by only one reviewer.

3. **Detect disagreements.** Find conflicting findings or opposing recommendations. Build the pairwise table internally — do not present the full table to the human up front:

| Topic | Position A (Reviewers) | Position B (Reviewers) |
|-------|----------------------|----------------------|
| ...   | ... (names)          | ... (names)          |

Use multiple rows for a topic if more than two positions exist.

4. **Resolve disagreements one at a time.** For each disagreement:
   - Present the single topic with both positions and which reviewers held each.
   - State your recommendation in one sentence with a brief rationale.
   - Ask the human to confirm, override, or provide their own resolution.
   - Wait for the answer before moving to the next disagreement. Do not auto-resolve or batch.

5. **Triage improvements one at a time.** After all disagreements are resolved, walk through every suggested improvement (agreed and unique) one by one:
   - Present the improvement with its source reviewer(s).
   - Ask the human whether it is relevant and should be applied.
   - Record the decision (accept / reject / defer) before moving on.

6. **Produce the final report** with these sections, reflecting the human's decisions from steps 4 and 5:

## Final Report

### Agreed Strengths
- Strengths multiple reviewers confirmed

### Agreed Issues
- Issues multiple reviewers flagged, prioritized by reviewer count

### Accepted Improvements
- Improvements the human marked relevant in step 5, with source reviewer(s)

### Rejected or Deferred Improvements
- Improvements the human chose not to apply, with brief reason if given

### Unique Insights
- Findings from a single reviewer worth considering (excluding ones already triaged as improvements)

### Open Questions
- Unresolved questions from any reviewer

### Resolved Disagreements

| Topic | Position A (Reviewers) | Position B (Reviewers) | Recommendation | Human Decision |
|-------|----------------------|----------------------|----------------|----------------|
| ...   | ...                  | ...                  | ...            | ...            |

## Tone

- Constructive and polite
- Actionable and clear
- No blame or harsh language
- Write for the implementer
- Avoid em dashes (—) in the final report. Use colons, parentheses, commas, or periods instead.
