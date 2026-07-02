# Clean Code Boilerplate for Flutter, Dart & Serverpod

A project-agnostic boilerplate that gives every new Flutter, Dart, or Serverpod project
a complete, opinionated setup for clean code from day one — strict static
analysis, 64 AI coding skills, and quality guardrails.

---

## What's Included

```text
marqably-flutter/
├── .mcp.json                              <- MCP server config for Claude Code
├── CLEAN_CODE.md                          <- this file
├── CLAUDE.md                              <- AI coding instructions (customize per project)
├── IDEA.md                                <- vision and roadmap
├── flutter_analysis_options.yaml          <- strict analysis for Flutter apps
├── dart_analysis_options.yaml             <- strict analysis for Dart server/CLI packages
└── .claude/
    ├── agents/
    │   └── software-architect.md
    └── skills/
        ├── SKILLS.md                      <- full skill catalog with routing rules
        │
        │  General (15 skills)
        ├── qa-core/
        ├── qa-review/
        ├── qa-requirements-audit/
        ├── qa-run-checks/
        ├── verify-implementation/
        ├── code-quality/
        ├── fix-all-issues/
        ├── error-handling/
        ├── create-reusable-helpers/
        ├── declarative-api/
        ├── project-patterns/
        ├── project-configuration/
        ├── add-custom-lint/
        ├── setup-codegraph-context/
        ├── marionette-mcp/
        │
        │  Flutter (17 skills)
        ├── flutter-add-screen/
        ├── flutter-add-widget/
        ├── flutter-add-use-case/
        ├── flutter-code-review/
        ├── flutter-pr-review/
        ├── flutter-dart-official-rules/
        ├── flutter-dart-refactor/
        ├── flutter-debug-state/
        ├── flutter-testing/
        ├── flutter-tdd/                   (+ references/)
        ├── flutter-widget-composition/
        ├── create-visual-ui/
        ├── patrol-e2e-testing/
        ├── patrol-test/
        ├── refactor-provider/
        ├── getit-dependency-injection/
        ├── uikit/
        │
        │  Serverpod (25 skills)
        ├── serverpod-overview/
        ├── serverpod-add-application-class/
        ├── serverpod-add-client-data-mapping/
        ├── serverpod-add-endpoint/
        ├── serverpod-add-model/
        ├── serverpod-auth-module/
        ├── serverpod-caching/
        ├── serverpod-cli/
        ├── serverpod-configuration/
        ├── serverpod-database/
        ├── serverpod-endpoints/
        ├── serverpod-error-handling/
        ├── serverpod-extensions/
        ├── serverpod-file-uploads/
        ├── serverpod-health-checks/
        ├── serverpod-logging/
        ├── serverpod-models/
        ├── serverpod-modules/
        ├── serverpod-orm-first/
        ├── serverpod-scheduling/
        ├── serverpod-server-events/
        ├── serverpod-sessions/
        ├── serverpod-streams/
        ├── serverpod-testing/
        ├── serverpod-type-safety/
        ├── serverpod-upgrading/
        ├── serverpod-webserver/
        │
        │  Full-stack (5 skills)
        ├── getting-started/
        ├── docker-services/
        ├── migrate-database/
        ├── seed-database/
        └── run-server/
```

---

## How To Use

### 1. Create your project

```bash
flutter create my_app
# or: serverpod create my_app
# or: dart create my_cli
```

### 2. Copy everything into the project

```bash
cp /path/to/marqably-flutter/flutter_analysis_options.yaml analysis_options.yaml
cp /path/to/marqably-flutter/CLAUDE.md CLAUDE.md
cp /path/to/marqably-flutter/.mcp.json .mcp.json
cp -r /path/to/marqably-flutter/.claude .claude
```

For a **Serverpod monorepo**:

```bash
# Flutter package
cp flutter_analysis_options.yaml my_app_flutter/analysis_options.yaml

# Dart server package
cp dart_analysis_options.yaml my_app_server/analysis_options.yaml

# AI skills go at the repo root
cp -r .claude .claude
cp CLAUDE.md CLAUDE.md
```

### 3. Prune skills for your project type

See the "Project Type Setup" section in `CLAUDE.md` for what to remove based on your project type (Flutter-only, Dart-only, or full-stack).

### 4. Customize CLAUDE.md

Open `CLAUDE.md` and fill in:

- Project description
- Your architecture pattern (or keep the default layered example)
- Your state management choice (default: Signals + HookWidget)
- Your UI component library (default: obers_ui via uikit)
- Your DI approach (default: GetIt)
- Your routing package (default: go_router)
- Project-specific non-negotiables

### 5. Verify the setup

```bash
dart analyze
flutter test
```

---

## Default Conventions

| Convention | Default |
| ---------- | ------- |
| State management | Signals + HookWidget |
| Navigation | go_router |
| UI components | obers_ui via `uikit` abstraction layer |
| DI | GetIt |
| Architecture | UI -> ViewModel -> UseCase -> Repository -> DataSource |
| Serverpod monorepo | `<project>_client/`, `<project>_flutter/`, `<project>_server/`, `<project>_shared/` |

---

## File Reference

### `CLAUDE.md`

The entry point for Claude Code. Read on every conversation.

**What to customize:**

- Replace placeholder project overview with your project description
- Replace the architecture section with your actual patterns
- Add project-specific non-negotiables (UIKit rules, DI conventions, etc.)
- Remove skills that don't apply to your project type

### `.mcp.json`

MCP server configuration for Claude Code. Pre-configured with six servers.
Remove servers you don't need. API keys use `${VAR}` syntax to reference shell
environment variables.

### `.claude/skills/SKILLS.md`

The master skill catalog with routing rules, scope tags, QA chain, and selection examples.

### `flutter_analysis_options.yaml`

Strict static analysis for Flutter app packages. Key settings:

- `strict-casts: true` — no implicit casts from `dynamic`
- `strict-inference: true` — no implicit `dynamic` for unresolved types
- `strict-raw-types: true` — no raw generics
- `avoid_dynamic_calls: true` — flags any call on a `dynamic` value
- `prefer_const_constructors: true` — enforces `const` widget constructors

### `dart_analysis_options.yaml`

Same strict settings for Dart server or CLI packages.

---

## Core Rules That Never Change

| Rule | Why |
| ---- | --- |
| Always use the most specific type — never `dynamic` | Hides bugs, defeats static analysis |
| `Object` and `Object?` are last resorts | Vague types push problems to runtime |
| No `Map<String, dynamic>` as domain types | Use typed DTOs |
| No `!` unless guaranteed non-null | Runtime crashes |
| No widget functions returning `Widget` | Breaks Flutter lifecycle and DevTools |
| `const` constructors everywhere possible | Reduces unnecessary rebuilds |
| Tests verify behavior, not existence | Shallow tests give false confidence |
| Bug fixes need regression tests | Without them, bugs come back |
| No `utils.dart` / `helpers.dart` dumping grounds | Becomes unmaintainable |
| `dart format` + `dart analyze` always clean | Consistent, discoverable issues |

---

## Recommended Dev Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  # Mocking (use fakes first, mocks when necessary)
  mocktail: ^x.x.x

  # Expressive test assertions
  checks: ^x.x.x
```

---

## Updating This Boilerplate

When you improve skills or rules in an active project, bring the improvements
back here:

1. Copy the updated skill from the project to `marqably-flutter/.claude/skills/`
2. Strip any project-specific references (replace with `<project>` placeholders)
3. Update this `CLEAN_CODE.md` if the skill's purpose or behavior changed
