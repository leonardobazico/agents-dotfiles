Review the drafted ADR using only the provided inputs:

- the drafted markdown file
- a short summary of resolved refinements

Output format:

Status: approved
or
Status: needs_refinement
or
Status: too_broad

After the first line, provide:

- one short rationale grounded in this rubric
- if the status is not approved, one concrete issue to surface to the human

Rubric:

- internal consistency between the summary, context, options, recommendation, and consequences
- whether the ADR captures one coherent decision input rather than multiple bundled decisions
- whether the `Recommendation` is grounded in the per-option pros/cons (full template) or one-line options (simple template)
- whether the `Recommendation` is phrased as a tentative suggestion, not a final decision
- whether `Consequences (if adopted)` is scoped to the recommended option and is concrete
- whether the `Decision` section is left as the literal placeholder for the team
- whether `Status` is `Proposed` (the skill never authors any other status)
- whether the chosen template is proportionate to the decision input
- whether any statement is ambiguous enough to support more than one valid interpretation

Rules:

- Prefer specific, concrete observations over general advice.
- Do not invent missing technical context, options, or pros/cons.
- If the ADR reads as a finalized decision instead of a recommendation, or the `Decision` placeholder has been filled in by the skill, return `Status: needs_refinement` with that as the concrete issue.
- If the ADR is acceptable as written, return `Status: approved`.
- If a human could refine the ADR with one targeted follow-up, return `Status: needs_refinement`.
- If the ADR is mixing multiple decision inputs or is too diffuse for one record, return `Status: too_broad`.
