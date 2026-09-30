---
name: refactoring
description: Use when restructuring existing code without changing its behavior - extracting functions, renaming, decomposing conditionals, removing dead code, or splitting a unit that has grown too large. Also use before a behavior change that needs the code reshaped first.
---

# Refactoring

Refactoring changes structure, never behavior. If behavior changes, it is not a refactoring; say so and treat it as a
behavior change, test-first.

## Tests during a refactoring

Tests stay green from start to finish.

| Test edit | Verdict |
| -- | -- |
| Following a renamed symbol, a new seam, or a changed fixture | Part of the move. Proceed. |
| Changing an assertion or an expected value | Behavior change. Stop. |
| Deleting a test case to make it fit the new shape | Behavior change. Stop. |

When you hit a Stop row: say so, and run the change test-first instead (failing test, minimum code to pass, then
refactor).

## Coverage

**Refactoring never leaves a behavior untested.** If the behavior you are about to restructure has no covering test,
write that characterization test first and watch it pass against the current code. Only then refactor.

Judge by behavior, not by line counts or percentages: removing dead code or comments moves both without any behavior
losing its test.

## Named moves

Work in named moves from Martin Fowler's *Refactoring*. Name the move you are making, make one at a time, and run the
tests between moves.

- Extract Function, Extract Variable, Extract Class
- Inline Function, Inline Variable
- Change Function Declaration, Rename Variable
- Move Function
- Decompose Conditional, Consolidate Conditional Expression
- Replace Magic Literal
- Remove Dead Code

If no catalog name fits what you are about to do, you are probably changing behavior. Check against the table above
before continuing.

## Target shape

The target is the `Code clarity` rules in `AGENTS.md`, sizing included. A refactoring that leaves a unit longer, with
more parameters, or with more hidden state has not finished.

Refactor toward the side-effect rule: fakes belong at IO boundaries, so a unit needing one to exercise its own logic is
asking to be split into a pure core and a thin shell. See the `testing-without-mocks` skill for the infrastructure side
of that split.
