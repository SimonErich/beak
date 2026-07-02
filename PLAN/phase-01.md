# Phase 01 — beak_core: types, enums, errors

## Objective
Lay down `beak_core`'s foundational, dependency-free vocabulary that every later type
builds on. Pure Dart, no Flutter, no worm in the public API.

## Prerequisites
- Phase 00 `✅ DONE`.

## Files created (in `packages/beak_core/lib/src/`)
- `context/beak_context.dart`
- `context/beak_render_intent.dart`
- `common/beak_color.dart`
- `query/beak_operator.dart`
- `common/beak_result.dart`
- `common/beak_exception.dart`
- barrel updates in `lib/beak_core.dart`

## Public API to implement (contract)
- `enum BeakContext { table, form, detail, filter }` — where a column is being rendered.
- `enum BeakRenderIntent { text, number, currency, badge, image, thumbnail, boolean,
  date, relativeDate, relationLink, relationBadges, richText, color, json, custom }` —
  the ORM/UI-neutral rendering hint a column resolves to per context. `beak_frontend`
  maps these to obers_ui widgets; `beak_core` never imports Flutter.
- `enum BeakColor { primary, secondary, success, warning, error, info, muted }` — a
  semantic color token (maps to `context.colors` in the frontend). No `dart:ui.Color`
  in core.
- `enum BeakOperator { eq, neq, gt, gte, lt, lte, like, ilike, contains, startsWith,
  endsWith, isNull, isNotNull, inList, notInList, between, notBetween }` — Beak's own
  operator set (backend maps each to a worm `Operator`; frontend serializes it). Include
  a documented mapping table in the doc comment.
- `sealed class BeakException implements Exception` with a `String code` and `String
  message`, and concrete subclasses: `BeakValidationException` (carries
  `Map<String, List<String>> fieldErrors` — typed, NOT dynamic), `BeakNotFoundException`,
  `BeakAuthorizationException`, `BeakConfigurationException`, `BeakStorageException`,
  `BeakConflictException`. Each has a `const` constructor and a helpful `toString()`.
- `sealed class BeakResult<T>` with `BeakOk<T>(T value)` and `BeakErr<T>(BeakException
  error)`; helpers `bool get isOk`, `T get valueOrThrow`, `R fold<R>(...)`,
  `BeakResult<R> map<R>(...)`. Use this for fallible operations that shouldn't throw
  across a boundary. (Exceptions are still used at Shelf/repository boundaries per the
  layering rule — `BeakResult` is for value-level composition.)

## Tests to write FIRST
- `beak_operator_test.dart` — every operator has a stable `name`; the mapping table
  documented is exhaustive (a test iterates all 18 values so adding one without handling
  breaks the build).
- `beak_exception_test.dart` — each exception carries code+message; `BeakValidationException`
  aggregates field errors; `toString()` includes the code.
- `beak_result_test.dart` — `fold`/`map`/`isOk`/`valueOrThrow` semantics; `valueOrThrow`
  on `BeakErr` throws the wrapped exception.
- `beak_context_test.dart` / render-intent — enums are complete and stable.

## Implementation notes / constraints
- Zero external deps beyond `meta` (for `@immutable`). No Flutter. No worm.
- Everything `const`-constructible and `@immutable` where it holds data.
- Public symbols documented. No `dynamic`, no `Map<String,dynamic>` in signatures.

## Definition of Done (gate)
- [ ] `melos run analyze` → 0 issues.
- [ ] `melos run test` → all green.
- [ ] `beak_core` coverage = **100%** (raise its threshold in `tool/check_coverage.dart`).
- [ ] `melos run format-check` → clean.
- [ ] Barrel exports all new public types.
- [ ] STATE.md row 01 → `✅ DONE` + SHA.

## Commit
`feat(beak_core): add foundational contexts, operators, results and exception hierarchy`
