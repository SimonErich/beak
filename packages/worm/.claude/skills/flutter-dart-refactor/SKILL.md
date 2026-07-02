---
name: flutter-dart-refactor
description: Comprehensive Flutter/Dart refactoring workflow. Analyses code, produces a written plan, waits for approval, then executes and verifies. Use when asked to refactor, clean up, improve quality, or "make this code perfect".
role: primary_workflow
scope: flutter
trigger: direct_match
pairs_with:
  - qa-core
  - qa-review
  - flutter-testing
  - flutter-widget-composition
  - error-handling
  - create-reusable-helpers
  - verify-implementation
---

# Flutter & Dart Refactor

Primary workflow for turning messy, inconsistent, or oversized Flutter/Dart code into clean, scalable, testable, idiomatic, and maintainable code.

Optimize for (in order):
1. Clarity
2. Correctness
3. Consistency
4. Testability
5. Maintainability
6. Performance
7. Developer experience

## Process Overview

```text
Step 1: ANALYSE   → read everything, understand the current state
Step 2: PLAN      → produce a written refactor plan, grouped by priority
Step 3: CONFIRM   → present plan to user and wait for explicit approval
Step 4: EXECUTE   → implement approved changes phase by phase
Step 5: VERIFY    → run all quality gates and fix remaining issues
```

**Do not write any production code changes before Step 3 is approved.**

## Step 1: Analyse

Read all relevant files. Build a complete picture of the current state.

Identify:
- Feature boundaries and scope of the refactor
- Architectural patterns already in use
- Layer violations (business logic in widgets, etc.)
- Oversized files, classes, build methods
- `dynamic`, `Map<String, dynamic>` abuse, nullable misuse, `!` spam
- Duplicated logic and UI trees
- Naming problems (vague, inconsistent, abbreviated)
- Missing or wrong test coverage
- Code smells (see list below)
- Dead code, dead imports, commented-out code

## Step 2: Plan

Produce a written **Refactor Plan** with the following structure:

```text
## Refactor Plan: <scope / file / feature name>

### Current State Summary
<2-5 bullet points describing the key problems found>

### Proposed Changes

#### Phase A: Structure & Naming
- [ ] <specific change> — <reason>

#### Phase B: Architecture
- [ ] <specific change> — <reason>

#### Phase C: Type Safety & Null Safety
- [ ] <specific change> — <reason>

#### Phase D: Performance & Widget Quality
- [ ] <specific change> — <reason>

#### Phase E: Tests
- [ ] <specific change> — <reason>

### Risk Assessment
- Behavior changes: <list any, or "none — structure only">
- Files affected: <list>
- Estimated blast radius: <narrow / moderate / broad>

### What will NOT be changed
<list anything explicitly left out and why>
```

Group changes by phase. Within each phase, order by impact. Call out any item that changes observable behavior separately.

## Step 3: Confirm

Present the Refactor Plan to the user.

Then ask:

> "Does this plan look right? Should I proceed with all phases, or only some? Any changes before I start?"

**Wait for explicit user approval before writing any code.** Do not interpret silence as approval.

## Step 4: Execute

Execute the approved phases in order. Follow these rules during execution:

- **Separate behavior changes from structure changes.** Make structural refactors first, then any approved behavior fixes.
- Execute one phase at a time. Do not mix phases.
- If you discover a new problem mid-execution that wasn't in the plan, **note it but do not fix it**. Add it to a "Found During Refactor" list to discuss after.

### Execution Phase A: Stabilize
```bash
dart format .
dart fix --apply
dart analyze
flutter test
```
Document current failures as baseline.

### Execution Phase B: Structure & Naming
- Standardize folders and naming to project conventions
- Extract oversized widgets into private child widget classes
- Split oversized classes
- Rename vague identifiers

### Execution Phase C: Architecture
- Move business logic out of widgets into UseCases/Application classes
- Wire data flow correctly through the layer stack
- Standardize state flow (Signals pattern)
- Standardize error handling
- Make dependencies injectable via DI

### Execution Phase D: Type Safety & Null Safety
- Remove all `dynamic` — replace with concrete types, generics, or `Object?`
- Remove all `Map<String, dynamic>` in domain/presentation — replace with typed DTOs
- Remove unjustified `!` — prefer null-aware operators, guards, or better modeling
- Replace stringly typed states with enums or sealed classes
- Add missing explicit types to public APIs

### Execution Phase E: Performance & Widget Quality
- Add `const` constructors where possible
- Narrow Watch() placement to smallest rebuild scope
- Remove expensive work from `build()`
- Use `.builder` constructors for lists and grids

### Execution Phase F: Tests
- Add/update tests for refactored logic
- Ensure bug fixes have regression tests
- Verify the test matrix: success, failure, boundary, negative

## Step 5: Verify

After all approved phases are complete, run all quality gates automatically:

```bash
dart format .
dart fix --apply
dart analyze
flutter test
```

For each gate:
- **Format:** Report any files reformatted.
- **Analyze:** Report any remaining warnings or errors. Fix all that relate to the refactor. Do not suppress with `// ignore`.
- **Tests:** Report pass/fail count. If tests fail, investigate and fix before declaring done.

After all gates pass, run the Refactor Checklist below and report results.

## Refactor Checklist (Report After Step 5)

### Structure
- [ ] Each file focused and under size limits?
- [ ] Each class/widget has one responsibility?
- [ ] Logic in correct architectural layer?

### Reuse
- [ ] Reused existing abstractions instead of duplicating?
- [ ] Removed duplicate logic and UI patterns?

### Typing
- [ ] Zero `dynamic` usage?
- [ ] Nullability modeled correctly? No unjustified `!`?
- [ ] All collections typed? Enums for known value sets?

### Flutter Quality
- [ ] `const` constructors where possible?
- [ ] Rebuild scope minimized?
- [ ] No expensive work in `build()`?

### Architecture
- [ ] Business logic outside widgets?
- [ ] Layer separation respected?
- [ ] DI used correctly?
- [ ] Side effects explicit and isolated?

### Safety
- [ ] Behavior preserved (or changes explicitly approved)?
- [ ] Tests cover changed behavior?
- [ ] Errors handled intentionally?

### Hygiene
- [ ] `dart format` clean?
- [ ] `dart analyze` clean?
- [ ] All tests pass?

## Size Limits

| Unit | Target | Hard Ceiling |
|------|--------|-------------|
| Widget file | < 200 lines | ~300 lines |
| General class | < 250 lines | — |
| Method | < 20 lines | ~30 lines |
| `build()` method | < 50 lines | ~100 lines |

## Naming Rules

Names must be specific, intention-revealing, domain-correct, pronounceable, and consistent.

**Avoid:** `data`, `item`, `thing`, `handler`, `util`, `helper`, `manager`, `customWidget`, `newData`, `temp`, `misc`

**Prefer:** `InvoiceSummaryCard`, `FetchCustomerOrdersUseCase`, `UserProfileRepository`, `OrderStatusBadge`, `PaymentMethodDto`

- Classes → nouns
- Methods → verbs
- Booleans → positive predicates (`isVisible`, `hasError`, `canRetry`)
- Abbreviations only when universally understood (`id`, `url`, `dto`, `api`, `ui`)

## Code Smells — Add to Plan When Found

- Giant widgets / files / methods
- Duplicated branches and UI trees
- `dynamic` and `Map<String, dynamic>` as domain models
- Nullable misuse and `!` spam
- Stringly typed state, magic numbers, magic strings
- Hidden side effects and swallowed exceptions
- Business logic in widgets or `build()` methods
- `utils.dart` / `helpers.dart` dumping grounds
- Unused code, dead imports, commented-out old code
- Vague names and mixed responsibilities
- Direct dependency creation inside widgets (should use DI)
- Hardcoded colors/spacing/typography (should use design tokens)
- Async work in `build()` methods
- State scattered across unrelated widgets

## Project-Specific Rules

All refactored code must comply with project conventions. These are checked during Step 5.

### Architecture
- **Flutter flow:** `UI -> ViewModel -> UseCase -> Repository -> DataSource`
- **Serverpod flow (if applicable):** `Endpoint -> Application -> Repository`
- UI talks to ViewModels only. ViewModels coordinate use cases.
- Repositories own caching, error handling, and mutable Signals.
- ViewModels expose read-only Signals to widgets.
- **Reference:** `project-patterns` skill

### Widgets
- `HookWidget` only — `StatefulWidget` is **forbidden** in feature code
- Never use raw Material or Cupertino widgets — use UIKit only
- NO widget functions — always extract as widget classes
- Place Watch() at narrowest scope
- **Reference:** `flutter-widget-composition` skill, `create-visual-ui` skill

### Type Safety
- **Always use the most specific type possible.**
- No `Map<String, dynamic>` as domain/presentation types
- No `as` casts — use pattern matching or typed APIs
- Prefer enums over strings for known value sets
- **Reference:** `flutter-dart-official-rules` skill

### Error Handling
- Flutter: Repositories are the primary try/catch boundary
- Serverpod: Endpoints catch; Application classes throw typed exceptions
- Never swallow errors. Never leak internal details to clients.
- **Reference:** `error-handling` skill

### DI
- Use `di<T>()` for dependency resolution
- **Reference:** `getit-dependency-injection` skill

### Design Tokens
- All colors, spacing, and typography from design tokens
- Touch targets >= 44x44 dp, contrast >= 4.5:1 (text), 3.0:1 (UI)
- **Reference:** `create-visual-ui` skill

### Feature Organization
- Feature code inside `features/<feature>/` with `data/`, `domain/`, `presentation/`, `di/`
- Shared code in `core/` only if truly cross-feature

## Found During Refactor

If new issues are discovered mid-execution that were not in the approved plan:
- Add them to a "Found During Refactor" list
- Do not fix them without approval
- Present the list to the user after Step 5 and ask if a follow-up pass is wanted
