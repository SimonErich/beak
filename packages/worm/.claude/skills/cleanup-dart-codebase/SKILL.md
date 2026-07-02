---
name: cleanup-dart-codebase
description: Full-codebase compliance audit and iterative remediation for legacy Flutter, Dart, or Serverpod projects
role: manual_execution
scope: general
trigger: explicit_request
pairs_with:
  - qa-core
  - qa-run-checks
  - code-quality
  - verify-implementation
  - flutter-dart-refactor
  - declarative-api
  - create-reusable-helpers
  - error-handling
---

# Cleanup Dart Codebase

Systematic compliance audit and iterative remediation for bringing a codebase into full alignment with this template's rules.

Start with `qa-core`.

## When to Use

- A legacy project is adopting this template's rules for the first time.
- A project has drifted significantly from conventions after a long period without review.
- The user explicitly asks to "clean up the whole codebase", "bring this project into compliance", or "audit everything".

## When NOT to Use

| Need | Use instead |
|------|-------------|
| Quick static check | `code-quality` |
| Single-feature refactor | `flutter-dart-refactor` |
| Iterative fix loop without deep analysis | `fix-all-issues` |
| Provider-to-clean-architecture migration | `refactor-provider` |
| Review without fixing | `qa-review` + `flutter-code-review` |
| Add a recurring lint enforcement | `add-custom-lint` |

---

## Phase 0: Detect Project Type

Determine project type automatically before scanning. This governs which rule categories apply.

### Detection Logic

1. Look for `pubspec.yaml` files in root and subdirectories.
2. Check for **Serverpod** indicators:
   - Directories matching `*_server/`, `*_client/`, `*_shared/`
   - `pubspec.yaml` dependencies containing `serverpod`
   - `.spy.yaml` files anywhere in the tree
3. Check for **Flutter** indicators:
   - `pubspec.yaml` with `sdk: flutter` dependency
   - `lib/` containing files importing `package:flutter/`
4. Classify:
   - Flutter + Serverpod → **full-stack** (all rule categories active)
   - Flutter only → **flutter** (skip Category F: Serverpod Rules)
   - Dart only → **dart** (skip Category D: Flutter Rules and Category F: Serverpod Rules)

Announce the result:

```
Project type detected: [Flutter-only | Dart-only | Flutter + Serverpod]
Rule categories active: [list]
Rule categories skipped: [list and why]
```

---

## Phase 1: Deep Analysis

Scan every `.dart` file in the project. Exclude `build/`, `.dart_tool/`, and `**/generated/**`.

For each file, check against all active rule categories. Record every violation with:
- File path and line number
- Rule ID and category
- Severity (CRITICAL, HIGH, MEDIUM)
- Short description

### Category A: Analysis Infrastructure (CRITICAL)

Check BEFORE scanning code — these affect whether other violations are even detectable.

| ID | Rule | Detection |
|----|------|-----------|
| A1 | `analysis_options.yaml` exists with strict settings | Verify `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true` |
| A2 | `avoid_dynamic_calls: true` in linter rules | Parse analysis_options.yaml |
| A3 | `prefer_const_constructors: true` in linter rules | Parse analysis_options.yaml |
| A4 | All recommended lint rules present | Compare against template's analysis options |
| A5 | No unjustified `// ignore:` suppressions | Search for `// ignore:` and `// ignore_for_file:` without justification comment |

### Category B: Type Safety (CRITICAL)

| ID | Rule | Detection |
|----|------|-----------|
| B1 | No `dynamic` keyword (except interop with comment) | Search for `: dynamic`, `<dynamic>`, `as dynamic` — exclude lines with interop justification |
| B2 | No `Map<String, dynamic>` as domain/presentation type | Search outside `generated/`, `data_sources/`, JSON interop boundaries |
| B3 | No `as` casts | Search for ` as ` keyword used as cast — exclude `import ... as` aliases |
| B4 | No raw generic types (`List` without `<T>`) | Search for `List `, `Map `, `Set `, `Future `, `Stream ` without type params |
| B5 | Public APIs have explicit return types | Search for public functions/methods missing return type annotations |
| B6 | Enums used for known value sets instead of strings | Search for string literals in switch/if chains that could be enums |

### Category C: Dart Quality (HIGH)

| ID | Rule | Detection |
|----|------|-----------|
| C1 | No unjustified `!` operator | Search for `!` on nullable expressions — flag when null-check or pattern match is viable |
| C2 | `const` constructors where possible | Run `dart analyze` — missing const warnings |
| C3 | Functions under 20 lines | Count lines per function/method body |
| C4 | Files under 500 lines | Count total lines per file (exclude test and generated files) |
| C5 | No `print()` calls | Search for `print(` outside test files |
| C6 | Single quotes preferred | Search for double-quoted strings that are not interpolated |
| C7 | Extension naming convention | Check extensions use approved suffixes: Checks, Display, Formatting, Behavior, Properties, Validation, QueryScopes |
| C8 | No `utils.dart` or `helpers.dart` filenames | Search for dumping-ground file names |

### Category D: Flutter Rules (HIGH — skip for Dart-only)

| ID | Rule | Detection |
|----|------|-----------|
| D1 | No widget functions (methods returning Widget) | Search for functions with `Widget` return type inside widget classes |
| D2 | No business logic in `build()` | Check `build()` for repository calls, API calls, complex computations |
| D3 | Widget files under 300 lines | Count lines per file in presentation/screens/widgets directories |
| D4 | `build()` methods under 50 lines | Count lines in `build()` method bodies |
| D5 | `HookWidget` only — no `StatefulWidget` in feature code | Search for `extends StatefulWidget` outside `core/` and `uikit/` |
| D6 | No raw Material/Cupertino imports in feature code | Search for `import 'package:flutter/material.dart'` in features/ |
| D7 | No direct `obers_ui` imports outside `uikit/` | Search for `import 'package:obers_ui/` |
| D8 | UIKit components used instead of raw Material widgets | Search for ElevatedButton, Text, Card, TextField, Scaffold, AppBar, etc. in features/ |
| D9 | Design tokens only — no hardcoded colors | Search for `Color(0x`, `Colors.xxx` in feature code |
| D10 | No hardcoded spacing | Search for `EdgeInsets.all(`, `SizedBox` with raw numeric literals in features/ |
| D11 | One public widget per file | Search for files with multiple public widget classes |

### Category E: Architecture (HIGH)

| ID | Rule | Detection |
|----|------|-----------|
| E1 | Proper layer separation (UI → ViewModel → UseCase → Repository → DataSource) | Check for widgets importing repositories or data sources directly |
| E2 | Extensions-first API design | Search for standalone functions operating on a single type that should be extensions |
| E3 | Configuration via `lib/config/` only | Search for `dotenv.env[` outside `lib/config/` |
| E4 | Feature code in `features/<feature>/` structure | Check for ad-hoc top-level directories that should be features |
| E5 | DI via GetIt pattern (`di<T>()`) | Search for `GetIt.I<` or `GetIt.instance<` — should use `di<T>()` alias |
| E6 | Repository error handling correct per project type | Flutter: repos catch and map errors. Serverpod: repos do NOT catch. |

### Category F: Serverpod Rules (HIGH — skip for non-Serverpod)

| ID | Rule | Detection |
|----|------|-----------|
| F1 | ORM-first — no unnecessary raw SQL | Search for `unsafeQuery` without justification comment |
| F2 | Typed exceptions — no generic `Exception` | Check for `throw Exception(` instead of typed exceptions |
| F3 | Extension-based model enrichment | Check for subclassed or wrapped generated models |
| F4 | No catch in repositories | Search for `try`/`catch` in repository files |
| F5 | Endpoint catch-and-map pattern | Check endpoints for proper exception mapping to SerializableException |
| F6 | No business logic in endpoints | Check endpoint methods for complex logic beyond auth/catch/delegate |
| F7 | No string interpolation in SQL | Search for `$` in strings passed to `unsafeQuery` |
| F8 | No `dynamic` in endpoint signatures | Check endpoint methods for `dynamic` params or return types |
| F9 | No catch-all return defaults | Search for catch blocks returning `[]`, `null`, `0`, `''`, `false` |

### Category G: Testing (MEDIUM)

| ID | Rule | Detection |
|----|------|-----------|
| G1 | Test files exist for non-trivial code | Compare `lib/` against `test/` for coverage gaps |
| G2 | Tests verify behavior, not just existence | Search for `expect(widget, isNotNull)` or `verify(...).called(1)` with no state assertions |
| G3 | Fakes/stubs preferred over mocks | Count mock vs fake usage; flag heavy `when().thenReturn()` chains |

### Category H: Code Health (MEDIUM)

| ID | Rule | Detection |
|----|------|-----------|
| H1 | `dart format` clean | Run `dart format --output=none --set-exit-if-changed .` |
| H2 | `dart analyze` clean | Run `dart analyze` and count issues |
| H3 | No committed secrets | Search for API keys, passwords, tokens in `.dart` files; check `.env` tracked in git |
| H4 | No dead imports | Run `dart analyze` — unused import warnings |
| H5 | No commented-out code blocks | Search for multi-line comments containing Dart syntax |

---

## Phase 1 Output

```
## Codebase Compliance Report

Project type: [detected type]
Files scanned: [count]
Total violations: [count]

### Violation Summary by Category

| Category | Critical | High | Medium |
|----------|----------|------|--------|
| A: Analysis Infrastructure | X | X | X |
| B: Type Safety | ... | ... | ... |
| C: Dart Quality | ... | ... | ... |
| D: Flutter Rules | ... | ... | ... |
| E: Architecture | ... | ... | ... |
| F: Serverpod Rules | ... | ... | ... |
| G: Testing | ... | ... | ... |
| H: Code Health | ... | ... | ... |

### Top 10 Most Violated Rules

| Rank | Rule | Count | Example file |
|------|------|-------|--------------|
| 1 | ... | ... | ... |

### Violations by File (grouped, sorted by severity)
```

---

## Phase 2: Prioritized Refactoring Plan

Group fixes into batches ordered by priority and dependency.

### Batch Order

| Batch | Category | Purpose |
|-------|----------|---------|
| 0 | A: Analysis Infrastructure | Install strict analysis_options.yaml — surfaces additional violations |
| 1 | H1: Formatting + autofixes | `dart format .` + `dart fix --apply` — mechanical cleanup |
| 2 | B: Type Safety | Remove dynamic, Map<String, dynamic>, as casts, add type annotations |
| 3 | C: Dart Quality | Remove `!`, add const, split oversized functions, fix filenames |
| 4 | E: Architecture | Fix layer separation, extract extensions, move config, restructure |
| 5 | D: Flutter-specific | Replace widget functions, StatefulWidget → HookWidget, Material → UIKit |
| 6 | F: Serverpod-specific | ORM-first, typed exceptions, repository/endpoint patterns |
| 7 | H: Code Health | Remove dead code, commented-out code, verify no secrets |
| 8 | G: Testing | Add missing tests, improve shallow tests, replace excessive mocking |

Present this plan and **WAIT for user approval** before proceeding:

> "Here is the remediation plan with [X] violations across [Y] batches. Should I proceed with all batches, skip any, or adjust the order?"

---

## Phase 3: Execute Fixes

For each approved batch:

1. **Announce** which batch is starting and how many violations it addresses.
2. **Execute** atomic changes — one concern at a time within the batch.
3. **Verify** after each batch:

```bash
dart format . --output=none --set-exit-if-changed
dart analyze
flutter test   # or dart test for Dart-only
```

4. **Report** results:

```
## Batch [N] Complete: [Category Name]

Violations fixed: X / Y
New issues introduced: [count, if any]
Verification:
  - dart format: [clean | X files need formatting]
  - dart analyze: [clean | X issues remaining]
  - tests: [all pass | X failures]
```

### Execution Rules

- **NEVER** suppress warnings to fake a clean result.
- **NEVER** delete tests to reduce failures.
- **NEVER** hand-edit generated code.
- If a fix would change observable behavior → flag and ask before proceeding.
- If the same violation pattern repeats 5+ times → recommend a custom lint rule via `add-custom-lint`.
- If a fix creates a cascade of other issues → stop the batch and report.

---

## Phase 4: Verify

After all batches complete, run a full verification sweep:

```bash
dart format .
dart fix --apply
dart analyze
flutter test   # or dart test
```

Report the full state.

---

## Phase 5: Re-Scan

Re-run Phase 1 analysis to detect remaining violations. This catches:

- Issues that only became visible after analysis_options.yaml was tightened.
- Secondary violations created by earlier fixes.
- Items missed in the first pass.

---

## Iteration Loop (Phases 3–5)

Repeat Phases 3 through 5 **up to 12 times** until the re-scan shows zero violations.

Each iteration must:

1. Show a progress summary comparing current vs previous violation count.
2. Focus on the highest-priority remaining violations.
3. **Stop early** if the violation count is not decreasing between iterations (structural blocker detected).

```
## Iteration [N] Progress

Previous violation count: X
Current violation count: Y
Delta: -Z (or +Z if regressions)
Remaining by category: [breakdown]
```

If violations plateau → report what is structurally blocked and recommend manual intervention.

---

## Completion Report

When clean (or when iterations are exhausted):

```
## Codebase Cleanup Complete

Project type: [type]
Total iterations: [N]
Starting violations: [count]
Final violations: [count]

### Fixed by Category
| Category | Fixed | Remaining | Blocked |
|----------|-------|-----------|---------|
| A: Analysis Infrastructure | X | X | X |
| ... | ... | ... | ... |

### Structural Issues Requiring Manual Intervention
- [list blocked items with explanation]

### Recommended Follow-Up
- [ ] Custom lint rules recommended: [list]
- [ ] Architecture migrations needed: [list]
- [ ] Test coverage gaps to close: [list]

### Verification Results
- dart format: clean
- dart analyze: clean
- tests: all pass
```

## Checklist

- [ ] Project type detected and announced
- [ ] All active rule categories scanned
- [ ] Violation report produced with counts and examples
- [ ] Remediation plan presented and approved by user
- [ ] Batches executed in priority order
- [ ] Verification run after each batch
- [ ] Re-scan performed after all batches
- [ ] Iteration loop continued until clean or plateaued (max 12)
- [ ] Completion report produced
- [ ] No warnings suppressed to fake clean results
- [ ] No tests deleted to reduce failures
- [ ] Recurring violations flagged for `add-custom-lint`
