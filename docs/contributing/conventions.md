---
title: Conventions
description: Shape commits, exceptions, tests and regenerated files the way a Beak reviewer expects, and know which conventions have a tool behind them.
type: guide
audience: [contributor]
status: stable
---

# Conventions

The [code guardrails](code-guardrails.md) are the rules a tool checks. These are the habits a reviewer checks: how a commit is named, when to add something new, which exception to throw and what to regenerate after a change. Most of them have no tool behind them, and this page says which.

## At a glance

| Convention | In short | Checked by |
| --- | --- | --- |
| Conventional Commits | `type(scope): summary`, scope is the package directory, `!` marks a break | review only |
| Reuse first | search the repo, extend the existing widget, mapper or column | review only |
| `const` and `final` | everything that can be | the `prefer_const_*` and `prefer_final_*` lints |
| Typed exceptions | a `BeakException` subtype, never a bare `Exception` | review; a sealed switch in the error middleware |
| Tests verify behavior | fakes over mocks, a regression test per fix | review; the coverage floors |
| Regenerate, never hand-edit | run the generator, commit its output | `melos run check-examples` |
| Pre-1.0 breaks | remove the old API, log it in `CHANGELOG.md` | review only |

## Conventional Commits

A commit is a type, the package it touches in parentheses, then a present-tense summary. The history shows the shape:

```text
feat(beak_cli): prepare a package of schema classes on its own
fix(tool): link obers_ui by declared dependencies only
feat(examples): a Beak admin inside a Serverpod 4 workspace
refactor(beak_frontend)!: units in size names, typed actions in forms, no casts
docs: rewrite the style guide around the author voice
```

The types in use are `feat`, `fix`, `refactor`, `docs`, `test` and `chore`. The scope is a package directory name (`beak_core`, `beak_frontend`) or an area (`tool`, `examples`, `ci`). A `!` after the scope marks a breaking change. Drop the scope when a change spans the repo.

One commit per unit of work, with the gate green behind it. A diff that touches four packages for one feature is harder to review than four small ones, so split before you open the pull request. The pull request template asks for what and why, how you verified it, and a checklist that mirrors the gate.

No hook and no CI job checks the message. A wrong one is not rejected, only noticed.

## Reuse first

Search the repo before you add a widget, a util, a mapper, a column or an exception. Beak is a small vocabulary used many times: one `BeakColumn` feeds the table cell, the form field, the detail row, the filter, the REST validator and the CSV column. A second way to say the same thing is how that vocabulary rots. A bird has one beak, and a framework that says a thing twice has two.

When you do need a new escape hatch, the existing ones show the shape a good one takes: `BeakCustomColumn` for a column Beak does not know, `BeakWidgetBlock` for a widget where no block fits, `BeakClient` for a request the generated API does not cover.

## `const` and `final`

Make everything `const` and `final` unless it has to change. Column and rule declarations are `const`-constructible on purpose, so a whole resource can be a compile-time constant. The lints in `analysis_options.yaml` (`prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_locals`, `prefer_final_fields`, `prefer_final_in_for_each`) fail `melos run analyze` under `--fatal-infos`.

Keep units small and single-purpose. No dead code, no `TODO` in committed code, no commented-out blocks. The lint catches `print`; a reviewer catches the rest.

## Typed exceptions

Never throw a bare `Exception`. Beak's failures are the sealed `BeakException` family in `beak_core`, and each variant carries a stable `code` and a `message`.

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
--8<-- "packages/beak_core/lib/src/common/beak_exception.dart:BeakException"
```

The family is sealed so the backend can map it with a switch the compiler proves complete. Add a variant and every mapper stops compiling until it handles the new case.

```dart title="packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart"
--8<-- "packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart:exceptionStatus"
```

A layer translates the failures below it into the right typed exception at its boundary and lets nothing rawer through. The storage drivers show the pattern: a private guard rethrows Beak's own exceptions untouched and wraps everything else, so no socket error crosses the driver seam.

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
try {
  return await operation();
} on BeakException {
  rethrow;
} on FtpProtocolException catch (error) {
  if (missingFileReplies && error.replyCode == 550) {
    throw BeakStorageException('No file is stored under "$key".');
  }
  throw BeakStorageException(
    'FTP $operationName failed for "$key" '
    '(reply ${error.replyCode}): ${error.message}',
  );
} on Object catch (error) {
  throw BeakStorageException(
    'FTP $operationName failed for "$key": $error',
  );
}
```

The frontend has one catch boundary too, and it returns a value instead of throwing. View models never `try/catch`; they read the `BeakResult` the repository hands back.

```dart title="packages/beak_frontend/lib/src/data/beak_run.dart"
--8<-- "packages/beak_frontend/lib/src/data/beak_run.dart:beakRun"
```

[Results and errors](../concepts/results-and-errors.md) covers both halves from the user's side.

## Tests verify behavior

Every public behavior is covered, red before green. Assert what a unit returns or renders and how it fails, not which private methods it called. Prefer a small fake that stores and serves data over a mock wired to return canned answers, because a fake catches the filter that never reached the query. Every bug fix ships the regression test that would have caught it, and a test is never skipped, weakened or deleted to get green. [Writing tests](writing-tests.md) has the harness for each package.

## Regenerate, never hand-edit

Generated files (`*.g.dart`, `*.beak.dart`) are excluded from analysis and coverage, and nothing in review should be a hand edit to one. Change the generator or the source it reads, then regenerate and commit the output.

| You changed | Run |
| --- | --- |
| A `beak_cli` emitter | `dart run ../../packages/beak_cli/bin/beak.dart prepare` in each example, then commit the output |
| The scaffold in `packages/beak_cli/lib/src/commands/create_command.dart` | recreate `examples/quickstart`; `quickstart_parity_test.dart` compares the two file by file |
| `docs/`, a file a docs page quotes with `--8<--`, `CHANGELOG.md`, the templates in `docs/_agents/blocks` | `melos run agent-docs` |
| `packages/*/skills` | `dart test test/published_skills_test.dart` |

`prepare` is quiet when there is nothing to do:

```text
  generated  up to date (7 files)
```

## Breaking changes before 1.0

Beak is pre-1.0, so a superseded API is removed instead of deprecated. Delete it, record the break under `[Unreleased]` in `CHANGELOG.md`, and add a row to the corrections table on the AI directory page (`docs/ai/index.md`), which is how coding agents learn that the old name is gone. `melos run check-agent-docs` fails when a row names a symbol that does not exist, or marks as removed a symbol that still exists.

## Rules and limits

- **Nothing checks commit messages.** The convention holds because reviewers hold it.
- **Nothing checks "reuse first".** A duplicate passes every tool. It fails on the first review that remembers the original.
- **A default branch opts out of the sealed check.** Every `switch` over `BeakException` should list the variants and have no `default`, so a new variant breaks the build instead of falling through.
- **Vendored worm code follows other rules.** `packages/worm*` are outside the melos gate, so a change to them is checked by `melos run test-worm` instead. They are still edited here when Beak needs a change; the pull request says why.
- **Local agent files stay local.** `CLAUDE.md`, `.claude/`, `PLAN/` and `PROMPT.md` at the repo root are git-ignored. `AGENTS.md` is the committed instruction file, and `*.db` files never get committed.

## Verify it

Read the last few subjects and match them:

```bash
git log --format=%s -5
```

Then check that nothing generated is stale. The script runs `beak doctor` in every example:

```bash
dart run tool/check_examples.dart
```

```text
  OK   quickstart
  OK   showcase
All 4 examples are healthy.
```

Warnings above those lines about a local SQLite file are true of a checkout that never ran `beak migrate`, and do not fail the check.

## Reference

| Exception | `code` | HTTP status | Meaning |
| --- | --- | --- | --- |
| `BeakValidationException` | `validation` | 422 | field-level validation failed; carries `fieldErrors` |
| `BeakNotFoundException` | `not_found` | 404 | no record for the id |
| `BeakAuthenticationException` | `authentication` | 401 | the caller is not signed in |
| `BeakAuthorizationException` | `authorization` | 403 | signed in, not allowed |
| `BeakConflictException` | `conflict` | 409 | the write conflicts with current state |
| `BeakConfigurationException` | `configuration` | 500 | Beak itself is set up wrong, a developer error |
| `BeakStorageException` | `storage` | 500 | a storage driver failed to store, read or delete a file |

`BeakRecordShapeException` extends `BeakConfigurationException`, so it maps to 500 and shares its code. The full list with wire bodies is in [Exceptions](../reference/exceptions.md).

## Continue reading

- [Writing tests](writing-tests.md) the harness and coverage floor per package.
- [Writing docs](writing-docs.md) the same discipline for the site.
- [Results and errors](../concepts/results-and-errors.md) the exception and result types from the user's side.
- [Exceptions](../reference/exceptions.md) every exception with its wire shape.
