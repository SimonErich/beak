# Project — Agent Start Here

## Project Overview

Dart package (`worm`) within the `beak` monorepo.

## Read First

1. `README.md` for setup and run instructions.
2. This file for architecture and non-negotiable rules.
3. `.claude/skills/SKILLS.md` for the full skill catalog and routing rules.
4. `.claude/skills/` for task-specific playbooks.

## Repo Map

- `lib/`: Dart package source code.
- `lib/worm.dart`: Package barrel file.
- `lib/src/`: Internal implementation.
- `test/`: Unit tests.
- `analysis_options.yaml`: Strict static analysis configuration.
- `.claude/skills/`: AI coding playbooks.
- `.claude/skills/SKILLS.md`: Full skill catalog with routing rules.

## MCP Servers

| Server | Purpose | Setup |
|--------|---------|-------|
| `dart` | Dart SDK analysis, fixes, tooling | Zero-config (Dart 3.9+) |
| `context7` | Package docs lookup | Zero-config (needs `npx`) |

## Where To Look

- Source code: `lib/src/`
- Public API: `lib/worm.dart`
- Tests: `test/`

## Non-Negotiable Rules

### Type Safety (Absolute)
- Always use the most specific type possible: prefer structured classes, enums,
  sealed classes, and primitives over vague types.
- `Object` and `Object?` are last resorts — only when no concrete type, generic,
  enum, or primitive can express the value.
- `dynamic` is forbidden except in unavoidable interop scenarios — add a comment
  explaining why.
- No `Map<String, dynamic>` as domain types — use typed DTOs.
- No `as` casts — use pattern matching or typed APIs.

### Dart Quality
- Avoid the `!` operator unless the value is guaranteed non-null.
- Use `const` constructors wherever possible.
- Keep functions short and single-purpose; strive for fewer than 20 lines.
- Prefer enums over strings for known value sets.

### Testing
- Tests must verify behavior, not just existence or mocked return values.
- Prefer fakes and stubs over mocks.
- Bug fixes must have regression tests.

### Code Health
- Search for existing components and patterns before creating new abstractions.
- Never create `utils.dart` or `helpers.dart` dumping grounds.
- Generated code is not hand-authored.
- Never commit secrets (`.env` files, passwords, API keys, private keys).

### Before Finishing
- Run `dart format .` and `dart analyze` — both must be clean.
- Run `dart test` — all tests must pass.

## Use Skills For Details

See `.claude/skills/SKILLS.md` for the full skill catalog with routing rules.

### QA Foundation
- QA posture and acceptance bar: `qa-core`
- Strict code review: `qa-review`
- Requirements audit: `qa-requirements-audit`
- Validation scope selection: `qa-run-checks`
- After implementation: `verify-implementation`

### Dart Development
- Error handling: `error-handling`
- Typed exceptions: `typed-exceptions`
- Declarative API design: `declarative-api`
- Project patterns: `project-patterns`
- Project configuration: `project-configuration`
- Reusable helpers and utilities: `create-reusable-helpers`
- Dart best practices: `flutter-dart-official-rules`
- Comprehensive refactoring: `flutter-dart-refactor`
- Test-driven development: `tdd-workflow`
- TDD setup: `tdd-setup`
- Custom lint rules: `add-custom-lint`

### Operations
- Static quality checks: `code-quality`
- Broad cleanup: `fix-all-issues`
- Codebase compliance audit: `cleanup-dart-codebase`

## Working Principles

- Prefer existing patterns over inventing new ones.
- Start from the feature you are changing, then expand outward.
- Be concise and direct when communicating.
- If something is unclear, ask before assuming.
