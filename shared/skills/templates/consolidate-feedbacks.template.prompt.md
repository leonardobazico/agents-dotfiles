Consolidate feedback from one or more AI reviewers into one de-duplicated report for the implementer.

## Inputs

Paste each review below, labeled by reviewer. Use as many blocks as reviews were actually collected (as few as one).

### Reviewer 1: <NAME>

<FEEDBACK>

### Reviewer 2: <NAME>

<FEEDBACK>

### Reviewer 3: <NAME>

<FEEDBACK>

### Same-origin review

If there is exactly one review above and you (the consolidator) produced it yourself (e.g. the all-fail self-review fallback in `ask-agents-for-feedback` / `ask-models-for-feedback`), skip straight to **Same-Origin Path** at the end. Skip Step 0 and every comparison step below: one voice can't be compared to itself.

## Instructions

**Step 0: State Self Position.** Before comparing or grouping any reviewer findings, write your own independent view of the artifact: Strengths, Issues, Suggested Improvements. Draw this from your own existing context, not paraphrased from the reviewer text above (already visible to you by this point — this is an authoring-order rule, not a claim of isolation from that text). Keep it brief: a handful of bullets per category, not a restatement of the artifact.

**Tag vocabulary**, used on every finding from here on. No other values exist:
- `Self: agrees` / `Self: disagrees` / `Self: no position` — self's stance on a reviewer finding.
- `Reviewer: not covered` — a self-only item (raised in Step 0) that no reviewer mentioned.

Keep every tag's note to one line: no restatement of the artifact or of feedback quoted elsewhere.

**Path selection.** Exactly one review, not same-origin -> **Single-Review Path**: skip steps 1 and 3, use the Single-Review branch of step 2, run step 4 only if step 2 produced a `Self: disagrees` finding. Otherwise -> **Standard Path**: steps 1-4 as written, Standard branch of step 2.

1. **Identify agreements (Standard Path only).** Group findings raised by multiple reviewers, higher-confidence items. Tag each group with self's stance from Step 0.

2. **Identify unique insights / single-review findings.**
   - Standard Path: findings raised by only one reviewer, each tagged with self's stance.
   - Single-Review Path: every finding in the one review is unique by definition. List each, tagged with self's stance. Then list any Step 0 self-position item the review didn't cover, tagged `Reviewer: not covered`.

3. **Detect disagreements (Standard Path only).** Find conflicting findings or opposing recommendations among reviewers. Build the pairwise table internally, do not present it to the human up front:

| Topic | Position A (Reviewers) | Position B (Reviewers) | Self |
|-------|----------------------|----------------------|------|
| ...   | ... (names)          | ... (names)          | agrees with A / agrees with B / independent position / no position |

Use multiple rows for a topic if more than two positions exist. `Self` is a note, not a vote: it never counts toward Position A/B's reviewer tally. If self disagrees with a finding all reviewers agree on (no reviewer-vs-reviewer disagreement exists on that topic), don't add a row for it: express it solely via the `Self: disagrees` tag on the finding in step 1 or 2. It does not get an entry in step 4.

4. **Resolve disagreements one at a time.** Run this step only if disagreements exist: Standard Path, for each row in the step 3 pairwise table; Single-Review Path, only if step 2 found a `Self: disagrees` finding. For each disagreement:
   - Standard Path: present the topic with both reviewer positions and self's stance from the `Self` column.
   - Single-Review Path: present the topic with self's position vs. the lone reviewer's position.
   - State your recommendation in one sentence with a brief rationale.
   - Ask the human to confirm, override, or provide their own resolution.
   - Wait for the answer before moving to the next disagreement. Do not auto-resolve or batch.

5. **Triage improvements one at a time.** After all disagreements are resolved (step 4, if it ran) or immediately after step 2 if none existed, walk through every suggested improvement one by one:
   - Standard Path source: every improvement raised as agreed, unique, or surfaced by a resolved disagreement.
   - Single-Review Path source: every actionable improvement from the one reviewer, plus any self-only improvement (tagged `Reviewer: not covered` in step 2). Both go through the same process below, with no distinction between reviewer-sourced and self-only items.
   - Present the improvement with its source (reviewer name(s), or "Self" for a self-only item).
   - State your recommendation in one sentence with a brief rationale.
   - Ask the human whether it is relevant and should be accepted / rejected / deferred.
   - Record the decision before moving on.

6. **Produce the final report**, reflecting the human's decisions from steps 4 and 5. Use the Standard Shape if 2+ reviews were collected, the Single-Review Shape if exactly one non-same-origin review was collected, or the Same-Origin Path below.

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
- <TOPIC>: brief topic description
- <POSITION_A> / <POSITION_B>: each side's position and which reviewers held it
- <SELF_STANCE>: self's stance (agrees with A / agrees with B / independent position / no position)
- <RECOMMENDATION>: your recommended resolution in one sentence with rationale
- <HUMAN_DECISION>: the human's final decision (confirm A, confirm B, override with own resolution)

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
- Only include this section if self and the single reviewer actually disagreed on something in step 4; omit entirely otherwise (do not leave it empty).
- <TOPIC>: brief topic description
- <SELF_POSITION> / <REVIEWER_POSITION>: each side's stance and rationale
- <RECOMMENDATION>: your recommended resolution in one sentence with rationale
- <HUMAN_DECISION>: the human's final decision

## Same-Origin Path (self-review fallback: the one review and the consolidator are the same agent)

Skip Step 0 and every comparison step above, there's nothing to compare against. Report using this shape instead:

### Strengths / ### Issues to Address / ### Suggested Improvements / ### Open Questions
- From the single review, unchanged

No `Self:` or `Reviewer:` tags appear anywhere in this shape.

## Tone

- Constructive, polite, no blame or harsh language
- Actionable and brief: self position and every `Self:` / `Reviewer:` tag note is a short bullet or one-liner, never a restatement of the artifact or of feedback already quoted elsewhere in the report
- Avoid em dashes (—) in the final report. Use colons, parentheses, commas, or periods instead.
