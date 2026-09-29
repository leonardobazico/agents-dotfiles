# Superpowers Overrides

Superpowers skills are process defaults. This user's instructions outrank them.

Precedence, highest first:

1. The repository's own `AGENTS.md`
2. This user's `AGENTS.md` (`~/.claude/AGENTS.md`)
3. Any superpowers skill

The superpowers `using-superpowers` skill states this itself, under `User Instructions`: "User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, etc, direct requests) take precedence over skills". This file names the specific points where that applies.

## Rules That Win

| Superpowers skill | Its rule | What wins instead |
|-------------------|----------|-------------------|
| `test-driven-development`, via its `writing-good-tests` reference | Add a mock when a real dependency is slow or external | `Testing philosophy` in `AGENTS.md` and the `testing-without-mocks` skill. Prefer sociable tests, Nullables, stubbed services, and real infrastructure in containers. Mocking is a last resort for clocks and randomness |
| `brainstorming` | Save the spec to `docs/superpowers/specs/` and commit it | `Safety Rules` in `AGENTS.md`. Never commit a spec, plan, or working file a superpowers skill produced unless explicitly asked. |
| `requesting-code-review`, `brainstorming` spec reviewer, and every other subagent prompt template | Dispatch the template as written | Every dispatch carries the governing `AGENTS.md` rules and the names of relevant local skills in its prompt. A subagent that does not know the rules cannot review against them |
| Any skill's own prose | Emoji, em dashes, and decorative symbols throughout | `Communication Style` in `AGENTS.md`. A skill's formatting licenses nothing. No emoji, no em dashes, no decorative symbols in output |

## Local Skills To Route To

| Skill | Invoke when |
|-------|-------------|
| `refactoring` | Restructuring existing code without changing behavior. Covers which test edits are allowed mid-refactor |
| `testing-without-mocks` | Designing tests for code that talks to an external system. Nullables, `createNull()`, output tracking, narrow integration tests |
| `count-tokens` | A token count, context budget, or size cap matters. Never estimate from characters or words |
| `write-adr` | Recording an architecture decision |
| `write-user-story` | Turning a request into a user story |
| `ask-agents-for-feedback` | The user explicitly asks for multi-CLI peer review |
| `ask-models-for-feedback` | The user explicitly asks for multi-model peer review |

Superpowers process skills still set the approach. These skills carry it out where they are more specific.
