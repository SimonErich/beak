---
name: project-patterns
scope: general
description: Primary workflow for project patterns, architecture questions, code placement, and task routing. Use when the user asks about project structure, where code should live, UIKit conventions, Serverpod patterns, or repository architecture.
role: primary_workflow
trigger: direct_match
---

# Project Patterns

This skill should own architecture and routing questions before a more specific implementation workflow takes over.

Use this skill for the repo's structural conventions. It is the detailed companion to `CLAUDE.md`.

## Read In This Order

1. `concept/concept.md` for product intent and UX behavior.
2. Project guidelines for repository-wide rules.
3. `OBERS_UI_LIBRARY_AI_DOCS.md` before extending `uikit`.
4. The task-specific skill that matches the work.

## Repo Map

- `<project>_flutter/`: Flutter app.
- `<project>_server/`: Serverpod backend.
- `<project>_client/`: generated client and protocol.
- `scripts/`: verification and helper scripts.
- `docs/`: specifications such as accessibility.
- `.claude/skills/`: operational playbooks.

## Where To Look

### Flutter

- Feature code: `<project>_flutter/lib/features/<feature>/`
- DI alias: `<project>_flutter/lib/di.dart` (`final GetIt di = GetIt.instance`)
- Global DI: `<project>_flutter/lib/service_locator.dart`
- Feature DI: `<project>_flutter/lib/features/<feature>/di/service_locator.dart`
- Routing: `<project>_flutter/lib/core/navigation/app_router.dart`
- Route definitions: `<project>_flutter/lib/core/navigation/routes/`
- UIKit abstraction layer: `<project>_flutter/lib/uikit/`

### Serverpod

- Feature code: `<project>_server/lib/src/features/<feature>/`
- Global DI: `<project>_server/lib/src/service_locator.dart`
- Feature DI: `<project>_server/lib/src/features/<feature>/service_locator.dart`
- Models: `.spy.yaml` files under server features
- Generated output: `<project>_server/lib/src/generated/` and `<project>_client/lib/src/protocol/`

### Verification

- Repo-wide Dart verification: `scripts/verification/verify_wi_0018.sh`
- Accessibility spec: `docs/accessibility_contract.md`

## Flutter Architecture

### Flutter flow

`UI -> ViewModel -> UseCase -> Repository -> DataSource -> Serverpod client`

### Flutter responsibilities

- UI renders state and forwards user intent to ViewModels.
- ViewModels expose read-only state and call use cases.
- Use cases contain business logic and orchestration.
- Repositories manage caching, state ownership, and error handling.
- Data sources perform raw I/O such as Serverpod calls or local persistence.

### Flutter folder shape

```text
<project>_flutter/lib/features/<feature>/
├── data/
│   └── data_sources/
├── domain/
│   ├── repositories/
│   ├── usecases/
│   ├── entities/        # optional
│   ├── mappers/         # optional
│   └── extensions/      # optional
├── presentation/
│   ├── view_models/
│   ├── screens/
│   ├── widgets/
│   ├── hooks/           # optional
│   ├── models/          # optional
│   └── mappers/         # optional
└── di/
    └── service_locator.dart
```

### Flutter rules

- Use `HookWidget`; `StatefulWidget` is forbidden in feature code.
- UI must not call repositories or use cases directly.
- Do not put business logic in widgets or ViewModels.
- Resolve Flutter dependencies through the global `di` from `package:<project>_flutter/di.dart`.
- Repositories must not leak raw errors upward.

## Signals Pattern

- Repositories own mutable signals.
- ViewModels expose read-only signals to UI.
- Use computed state for derived values.
- Keep state granular and feature-scoped.
- Avoid ad hoc callback chains when the ViewModel can be resolved from DI.

## UIKit Pattern

Architecture:

`feature code -> uikit -> obers_ui`

Rules:

- Feature code imports only `package:<project>_flutter/uikit/uikit.dart`.
- Do not import `obers_ui` directly outside `uikit`.
- Reuse existing UIKit components before creating new ones.
- Use design tokens, not hardcoded spacing, colors, or typography.
- For UIKit changes, follow `docs/accessibility_contract.md`.

For implementation detail, use the `uikit` skill.

## Serverpod Architecture

### Serverpod flow

`Endpoint -> Application -> Repository`

### Serverpod responsibilities

- Endpoints: auth, permission checks, request boundaries, and error mapping only.
- Application: business logic and orchestration.
- Repositories: all database access and transactions.
- Mappers: pure conversion code when needed.
- DTOs: non-persisted `.spy.yaml` types.
- Models: persisted `.spy.yaml` types.

### Serverpod folder shape

```text
<project>_server/lib/src/features/<feature>/
├── models/
├── dtos/            # optional
├── mappers/         # optional
├── repositories/
├── application/
├── endpoints/
├── exceptions/      # optional
└── service_locator.dart
```

### Serverpod rules

- Never put business logic in endpoints.
- Never perform DB calls outside repositories.
- Use feature and global service locators for server registration (server keeps its own DI setup).
- When changing models or endpoints, regenerate protocol with `serverpod generate`.
- If schema changed, create and apply a migration.
- Keep feature code inside `features/<feature>/`; do not default to adding new top-level `endpoints/`, `services/`, or ad hoc shared folders for feature-specific code.
- Avoid static singleton patterns; prefer dependency registration through service locators.

## Testing And Verification

- Dart changes must pass `bash scripts/verification/verify_wi_0018.sh`.
- UIKit changes must satisfy the accessibility contract and related tests.
- After implementation, use the `verify-implementation` skill.
- For backend tests, use the `serverpod-testing` skill.

## Task Routing

- New screen: `flutter-add-screen`
- New widget: `flutter-add-widget`
- New use case: `flutter-add-use-case`
- UIKit layer change: `uikit`
- New model: `serverpod-add-model` or `serverpod-models`
- New business logic class: `serverpod-add-application-class`
- New endpoint: `serverpod-add-endpoint`
- Database work: `serverpod-database`
- Auth work: `serverpod-auth-module`
- Broader setup or onboarding: `getting-started`

## Default Behavior

- Prefer existing feature patterns over inventing a new structure.
- When in doubt, inspect the nearest analogous feature first.
- Keep specialized operational detail in skills, not in `CLAUDE.md`.
