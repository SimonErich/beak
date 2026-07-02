---
name: error-handling
description: Concise workflow for Flutter and Serverpod error and exception handling. Layer boundaries, try/catch placement, typed failures, safe user messaging, and failure-path tests. Use when adding or reviewing error flows, exception mapping, or failure-state UX.
role: reference
scope: general
trigger: explicit_request
pairs_with:
  - qa-review
  - flutter-testing
  - serverpod-testing
  - typed-exceptions
---

# Error Handling

Use this skill when adding, changing, or reviewing failure paths.

## Quick Start

- Classify failure: validation, authorization, not found, conflict, transient infrastructure, unexpected bug.
- Handle it in the correct layer.
- Use typed failures (not string parsing, `null`, or generic booleans).
- Keep user messages safe and actionable; keep technical detail in logs.
- Add failure-path tests.

## General Principles

- Catch only where you can translate, log, retry, or render.
- Map failures once at the next boundary.
- Keep expected failures distinct from bugs.
- Retry only transient failures, explicitly.
- Never swallow errors.
- Use typed exception classes. For exception design rules, pair with `typed-exceptions`.

## Flutter Error Flow

`Widget -> ViewModel -> UseCase -> Repository -> DataSource`

Rules:

- Widgets: no domain/data error handling, except local UI-only interactions.
- ViewModels: never `try/catch` repository or domain errors; only consume repository/use-case state and expose UI state.
- UseCases: business validation and domain failures.
- Repositories: this is the primary Flutter boundary for catching infra errors (`try/catch`) and mapping them to safe domain/UI-facing error states.
- Repositories should expose signals wrapped in `AsyncState` so loading/data/error are already handled before reaching ViewModels.
- DataSources: raw I/O.

## Serverpod Error Flow

`Endpoint -> Application -> Repository`

Rules:

- Repository: persistence only; do not swallow failures.
- Application: throw typed business failures.
- Endpoint: auth/permissions and safe client mapping.
- Never leak internal details to clients.

For Serverpod-specific guardrails, pair with `serverpod-error-handling`.

## Failure Categories

- Validation
- Authorization
- Not found
- Conflict
- Transient infrastructure
- Unexpected bug

## Anti-Patterns

- Empty catch blocks
- `null`/`false` as generic error signaling
- Exception-string parsing for logic
- Throwing low-level exceptions directly to UI/client
- Leaking internal details or secrets

## Placement Checklist

- [ ] Validation/business failures in UseCase/Application.
- [ ] Infrastructure `try/catch` and mapping in Repository, not ViewModel.
- [ ] Endpoint maps to safe client response.
- [ ] ViewModel/UI shows safe actionable message.
- [ ] Logs contain diagnostics, not secrets.

## Testing Expectations

- Add at least one failure-path test per changed action.
- Verify typed failure mapping.
- Verify safe user/client messages.
- Verify no sensitive leakage.
