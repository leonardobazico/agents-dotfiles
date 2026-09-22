---
name: testing-without-mocks
description: Use when writing tests that touch external systems (HTTP, database, file system, clock, randomness, message queues), when a test needs a mock or fake, or when designing the seam between application logic and infrastructure. Applies James Shore's Nullables patterns.
---

# Testing Without Mocks

Source: James Shore, <https://www.jamesshore.com/v2/projects/nullables/testing-without-mocks>.

Replace mocks with production code that has an off switch. Test doubles are written once, as production-grade code, inside the class they belong to.

## The core move

Wrap each external system in one class (**Infrastructure Wrapper**). Give that class a `createNull()` factory returning a real instance with external communication disabled and every other behavior intact (**Nullable**).

`createNull()` works by stubbing the *third-party library* the wrapper calls, not your own code (**Embedded Stub**). Your wrapper's logic runs for real in both production and tests.

```
HttpClient.create()      -> talks to the network
HttpClient.createNull()  -> same class, same logic, no socket
```

## Verifying without call assertions

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Assert on a write that leaves the system | **Output Tracking** | `trackXxx()` returns a growing array of what was written |
| Drive an inbound event from outside | **Behavior Simulation** | `simulateXxx()` method on the wrapper |
| Vary what a dependency returns | **Configurable Responses** | optional parameters to `createNull()` |

All three are tested, production-grade methods on the wrapper. None of them assert that a function was called: they assert on recorded behavior, which is what `classical TDD` in `AGENTS.md` requires.

## Construction

Every class has a factory taking no parameters, with sensible defaults that build its own dependencies (**Parameterless Instantiation**). Constructors still take dependencies explicitly: that is how `createNull()` injects the embedded stub. The parameterless factory is the default entry point, not a replacement for injection.

Constructors do no IO and open no connections (**Zero-Impact Instantiation**).

## Architecture

- **A-Frame Architecture**: infrastructure and logic are peers under an application layer, with no dependency between infrastructure and logic.
- **Logic Sandwich**: the application layer reads via infrastructure, processes via logic, writes via infrastructure.
- Logic layer code takes values and returns values. It needs no nulling because it touches nothing external.

## What still uses real systems

**Narrow Integration Tests**: test each infrastructure wrapper against the real external system (real files, real database, real broker) on an instance reserved for one machine. Nullables test everything *above* the wrapper; they never prove the wrapper itself works.

**Paranoic Telemetry**: assume the external system fails. Every failure path either logs an error and alerts, or throws so something upstream does. Test those paths.

## Relationship to the per-stack table in AGENTS.md

The `avoid -> stub with -> real infrastructure` table still holds for third-party services you do not own (WireMock, MSW, `responses`). Nullables replace hand-rolled fakes and mocks of *your own* infrastructure wrappers. Testcontainers remains how the narrow integration tests get a real system.
