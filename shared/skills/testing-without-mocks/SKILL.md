---
name: testing-without-mocks
description: Use when writing tests that touch external systems (HTTP, database, file system, clock, randomness, message queues), when a test needs a mock or fake, or when designing the seam between application logic and infrastructure. Applies James Shore's Nullables patterns.
---

# Testing Without Mocks

Source: James Shore, <https://www.jamesshore.com/v2/projects/nullables/testing-without-mocks>.

Replace mocks with production code that has an off switch. Test doubles are written once, as production-grade code,
inside the class they belong to.

## The core move

Wrap each external system in one class (**Infrastructure Wrapper**). Give that class a `createNull()` factory returning
a real instance with external communication disabled and every other behavior intact (**Nullable**).

How `createNull()` disables communication depends on where the class sits. Decide by one question: **does this class
call a third-party library directly?**

| Class | `createNull()` is built by | Pattern |
| -- | -- | -- |
| Calls a third-party client or SDK directly | Stubbing that library inside the class | **Embedded Stub** |
| Calls only your own classes | Passing in their `createNull()` instances | **Fake It Once You Make It** |

Only the lowest wrapper stubs a library. Everything above it composes Nullables. Stubbing a driver from a higher layer
duplicates the stub and bypasses the infrastructure boundary.

```
Database.createNull()      -> embedded stub of the driver, no database IO
OrderRepository.createNull() -> receives Database.createNull()
OrderService.createNull()    -> receives OrderRepository.createNull()
```

Your own logic runs for real at every level, in production and in tests.

## Verifying without call assertions

| Need | Pattern | Mechanism |
| -- | -- | -- |
| Assert on a write that leaves the system | **Output Tracking** | `trackXxx()` returns a growing array of what was written |
| Drive an inbound event from outside | **Behavior Simulation** | `simulateXxx()` method on the wrapper |
| Vary what a dependency returns | **Configurable Responses** | optional parameters to `createNull()` |

All three are tested, production-grade methods on the wrapper. None of them assert that a function was called: they
assert on recorded behavior, which is what `classical TDD` in `AGENTS.md` requires.

## Construction

Constructors take dependencies explicitly: that is how a Nullable gets its stub or its nulled collaborators. Factories
decide what the default entry point looks like, and that depends on whether a no-argument default is meaningful.

| Class | Factory | Why |
| -- | -- | -- |
| Infrastructure wrapper, service, application class | `create()` with no parameters, sensible defaults that build its own dependencies (**Parameterless Instantiation**) | A default connection, client, or collaborator is meaningful |
| Value object or any type with required valid input (`UserId`, `Money`, `EmailAddress`) | `create(value)` plus `createTestInstance()` supplying explicit valid defaults | A parameterless constructor would produce an invalid or meaningless object |

Never give a value object a no-argument factory to satisfy the rule above. `EmailAddress.create()` has no correct
answer; `EmailAddress.createTestInstance()` does.

Constructors do no IO and open no connections (**Zero-Impact Instantiation**).

## Architecture

- **A-Frame Architecture**: infrastructure and logic are peers under an application layer, with no dependency between
  infrastructure and logic.
- **Logic Sandwich**: the application layer reads via infrastructure, processes via logic, writes via infrastructure.
- Logic layer code takes values and returns values. It needs no nulling because it touches nothing external.

## What still uses real systems

**Narrow Integration Tests** apply to the classes that talk to the outside world themselves, not to every class in the
infrastructure package. Same question as before: does this class call a third-party library directly?

| Class | Test against |
| -- | -- |
| Calls a third-party client or SDK directly | The real external system, on an instance reserved for one machine |
| Delegates to your own wrapper | That wrapper's Nullable |

Testing every delegating layer against a real database duplicates the slowest coverage you own and proves nothing the
bottom wrapper's test did not already prove. Nullables test everything *above* the bottom wrapper; they never prove the
bottom wrapper itself works.

**Paranoic Telemetry**: assume the external system fails. Every failure path either logs an error and alerts, or throws
so something upstream does. Test those paths.

## Relationship to the per-stack table in AGENTS.md

**Follow the codebase before following this skill.** Inspect how the repository already tests infrastructure and match
it. Introducing Nullables into a suite built on another pattern is a behavior-preserving restructure of test code: run
it through the `refactoring` skill, one wrapper at a time, rather than converting a suite wholesale.

Where the existing pattern is emulated real infrastructure, keep it. Testcontainers, WireMock, MSW, `responses`, and
`pytest-httpserver` are the preferred way to run narrow integration tests: they exercise the real protocol against a
real process, which an embedded stub cannot do.

Division of labour:

| Target | Tool |
| -- | -- |
| Narrow integration test of a wrapper that talks to a real system | Testcontainers, WireMock, MSW, or the stack's equivalent |
| Third-party service you do not own | WireMock, MSW, `responses` per the `AGENTS.md` table |
| Everything above your bottom-level wrapper | Nullables |

Nullables replace hand-rolled fakes and mocks of *your own* classes. They do not replace real infrastructure in
integration tests.
