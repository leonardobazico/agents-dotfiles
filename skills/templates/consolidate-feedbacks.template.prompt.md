Consolidate feedback from one or more AI reviewers into one de-duplicated report for the implementer.

## Inputs

Paste each review below, labeled by reviewer. Use as many reviewer blocks as reviews were actually collected (as few as one).

### Reviewer 1: <NAME>

<FEEDBACK>

### Reviewer 2: <NAME>

<FEEDBACK>

### Reviewer 3: <NAME>

<FEEDBACK>

### Same-origin review

If there is exactly one review above and it was produced by the current agent itself (e.g. the all-fail self-review fallback in `ask-agents-for-feedback` / `ask-models-for-feedback`, where the current agent is both the sole reviewer and the consolidator), skip directly to the **Same-Origin Path** at the end of this file. Do not run Step 0 or any comparison step below — there is only one voice, so a comparison against itself would be meaningless.

## Instructions

**Step 0: State Self Position.** Before comparing or grouping any reviewer findings, write your own independent view of the artifact: Strengths, Issues, Suggested Improvements. Draw this from your own existing context on the artifact, not from the reviewer feedback pasted above (which is already visible to you by this point in the prompt — this is an ordering rule for authoring an independent judgment, not a claim of isolation from that text). Keep it brief: a handful of bullets per category, not a restatement of the artifact.

**Tag vocabulary**, used on every finding from here on:
- `Self: agrees` / `Self: disagrees` / `Self: no position` — self's stance on a reviewer finding.
- `Reviewer: not covered` — marks a self-only item: something self raised in Step 0 that no reviewer mentioned.

No other tag values exist. Keep every tag's surrounding note brief: one line, no restatement of the artifact or of feedback already quoted elsewhere.

**If exactly one review was collected (and it is not a same-origin review), use the Single-Review Path: skip the pairwise-table steps (1 and 3), use the Single-Review branch of step 2, and run step 4 only if step 2 produced a `Self: disagrees` finding.** Otherwise use the Standard Path: steps 1-4 as written, with the Standard-Path branch of step 2.

1. **Identify agreements (Standard Path only).** Group findings raised by multiple reviewers; these are higher-confidence items. Tag each group with self's stance from Step 0.

2. **Identify unique insights / single-review findings.**
   - Standard Path: flag findings raised by only one reviewer, each tagged with self's stance.
   - Single-Review Path: every finding in the one review is unique by definition. List each finding, tagged with self's stance (`Self: agrees` / `Self: disagrees` / `Self: no position`). Then list any Step 0 self-position item the review didn't cover, tagged `Reviewer: not covered`.

3. **Detect disagreements (Standard Path only).** Find conflicting findings or opposing recommendations among reviewers. Build the pairwise table internally — do not present the full table to the human up front:

| Topic | Position A (Reviewers) | Position B (Reviewers) | Self |
|-------|----------------------|----------------------|------|
| ...   | ... (names)          | ... (names)          | agrees with A / agrees with B / independent position / no position |

Use multiple rows for a topic if more than two positions exist. The `Self` column never counts toward Position A/B's reviewer tally, it is a note, not a vote.

If self disagrees with a finding that all reviewers agree on (no reviewer-vs-reviewer disagreement exists on that topic), do not add a row for it here. Express it solely via the `Self: disagrees` tag on the finding in step 1 or 2, it does not get its own entry in the resolution loop (step 4).

4. **Resolve disagreements one at a time.** Run this step only if disagreements exist: on the Standard Path, for each row in the step 3 pairwise table; on the Single-Review Path, only if step 2 found any `Self: disagrees` finding. For each disagreement:
   - Standard Path: present the topic with both reviewer positions and self's stance from the `Self` column.
   - Single-Review Path: present the topic with self's position vs. the lone reviewer's position.
   - State your recommendation in one sentence with a brief rationale.
   - Ask the human to confirm, override, or provide their own resolution.
   - Wait for the answer before moving to the next disagreement. Do not auto-resolve or batch.

5. **Triage improvements one at a time.** After all disagreements are resolved (step 4, if it ran) or immediately after step 2 if no disagreements existed, walk through every suggested improvement one by one:
   - Standard Path source: every improvement raised as agreed, unique, or surfaced by a resolved disagreement.
   - Single-Review Path source: every actionable improvement from the one reviewer, plus any self-only improvement (tagged `Reviewer: not covered` in step 2) the reviewer didn't mention. Both go through the same triage process below with no distinction between reviewer-sourced and self-only items.
   - Present the improvement with its source (reviewer name(s), or "Self" for a self-only item).
   - State your recommendation in one sentence with a brief rationale.
   - Ask the human whether it is relevant and should be accepted / rejected / deferred.
   - Record the decision (accepted / rejected / deferred) before moving on.

6. **Produce the final report**, reflecting the human's decisions from steps 4 and 5. Use the Standard Report Shape if 2+ reviews were collected, or the Single-Review Report Shape if exactly one non-same-origin review was collected.

## Final Report: Standard Shape (2+ reviewers)

### Self Position
- Self's independent view from Step 0, brief bullets, stated before reviewer findings were compared

### Agreed Strengths
- Strengths multiple reviewers confirmed, each tagged Self: agrees / disagrees / no position

### Agreed Issues
- Issues multiple reviewers flagged, prioritized by reviewer count, each tagged Self: agrees / disagrees / no position

### Accepted Improvements
- Improvements the human marked relevant in step 5, with source reviewer(s)

### Rejected or Deferred Improvements
- Improvements the human chose not to apply, with brief reason if given

### Open Questions
- Unresolved questions from any reviewer

### Resolved Disagreements

- <TOPIC>: Brief description of the disagreement topic
- <POSITION_A>: Summary of one side's position and which reviewers held it
- <POSITION_B>: Summary of the opposing position and which reviewers held it
- <SELF_STANCE>: Self's stance on the topic (agrees with A / agrees with B / independent position / no position)
- <RECOMMENDATION>: Your recommended resolution in one sentence with rationale
- <HUMAN_DECISION>: The human's final decision (confirm A, confirm B, override with own resolution)

## Final Report: Single-Review Shape (exactly one review, not same-origin)

### Self Position
- Self's independent view from Step 0, brief bullets, stated before the review's findings were compared

### Reviewer Findings vs. Self
- Each finding from the single review, tagged Self: agrees / disagrees / no position
- Any self-position item the review didn't cover, tagged Reviewer: not covered

### Accepted Improvements
- Improvements the human marked relevant in step 5, with source (reviewer or Self)

### Rejected or Deferred Improvements
- Improvements the human chose not to apply, with brief reason if given

### Open Questions
- Unresolved questions from the review

### Resolved Disagreements
- Only include this section if self and the single reviewer actually disagreed on something in step 4; omit the section entirely otherwise (do not leave it empty).
- <TOPIC>: Brief description of the disagreement topic
- <SELF_POSITION>: Self's stance and rationale
- <REVIEWER_POSITION>: The reviewer's stance and rationale
- <RECOMMENDATION>: Your recommended resolution in one sentence with rationale
- <HUMAN_DECISION>: The human's final decision

## Same-Origin Path (self-review fallback: the one review and the consolidator are the same agent)

Skip Step 0 and every comparison step above. There is nothing to compare against. Produce the final report using this shape instead of either shape above:

### Strengths
- From the single review, unchanged

### Issues to Address
- From the single review, unchanged

### Suggested Improvements
- From the single review, unchanged

### Open Questions
- From the single review, unchanged

No `Self:` or `Reviewer:` tags appear anywhere in this shape.

## Tone

- Constructive and polite
- Actionable and clear and brief: self position and every `Self:` / `Reviewer:` tag note is a short bullet or one-liner, never a restatement of the artifact or of feedback already quoted elsewhere in the report.
- No blame or harsh language
- Avoid em dashes (—) in the final report. Use colons, parentheses, commas, or periods instead.
