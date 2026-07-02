---
name: flutter-dart-official-rules
description: Official Flutter team best practices and strict Dart idioms — type safety, SOLID, immutability, performance, accessibility, layout, testing. Reference skill for any Flutter/Dart work.
role: reference
scope: flutter
trigger: explicit_request
pairs_with:
  - flutter-dart-refactor
  - flutter-widget-composition
---

# Flutter & Dart Official Rules

Reference skill containing official Flutter team best practices and strict Dart idioms that are **additive** to the project's existing architecture.

Sources:
- https://docs.flutter.dev/ai/ai-rules (Flutter team `rules.md`)
- https://dart.dev/effective-dart
- Strict analysis options (`strict-casts`, `strict-inference`, `strict-raw-types`)

## Strict Static Analysis

Enable strict analyzer settings in `analysis_options.yaml` to catch implicit `dynamic` at compile time:

```yaml
analyzer:
  language:
    strict-casts: true      # No implicit casts from dynamic
    strict-inference: true   # No implicit dynamic for unresolved types
    strict-raw-types: true   # No raw generic types (e.g., List instead of List<String>)
```

Key lint rules that enforce type safety and quality:
- `avoid_dynamic_calls: true` — flag calls on `dynamic` values
- `always_declare_return_types: true` — every function has an explicit return type
- `type_annotate_public_apis: true` — all public API members typed
- `strict-casts` prevents `dynamic` from silently becoming any type
- `strict-inference` prevents the analyzer from silently inferring `dynamic`
- `strict-raw-types` prevents unparameterized generics like `List` or `Map`

## Type Safety

- **Always use the most specific type possible.** Prefer structured classes, enums, sealed classes, and primitives over vague types. `Object` and `Object?` are last resorts — only acceptable when no concrete type, generic, enum, or primitive can express the value. `dynamic` is forbidden except in unavoidable interop/reflection scenarios and must be accompanied by a comment explaining why. When in doubt, model the domain with a proper type instead of reaching for a loose one.
- **Null Safety:** Leverage Dart's null safety fully. Avoid the `!` operator unless the value is guaranteed non-null. Prefer null-aware operators (`?.`, `??`, `?..`) and control flow analysis.
- **Exhaustive switch:** Prefer exhaustive `switch` statements or expressions. They do not require `break` and the compiler catches missing cases.
- **Pattern Matching:** Use pattern matching features (destructuring, if-case, switch expressions) where they simplify code.
- **Records:** Use records to return multiple values when defining an entire class would be cumbersome.
- **Sealed classes:** Use `sealed`, `base`, `interface`, `final` class modifiers to clarify API intent and enable exhaustive pattern matching.

## Modern Dart Idioms

Prefer idiomatic modern Dart:
- Super parameters (`super.key`)
- Pattern matching and switch expressions
- Collection `if` / `for`
- Records for short-lived grouped values
- Destructuring where it improves readability
- `final` by default — use `final` unless mutation is necessary
- `const` when compile-time constant values are possible
- Arrow syntax (`=>`) for simple one-line functions

Do not force modern syntax where it hurts readability.

## SOLID Principles

Apply SOLID throughout the codebase:
- **S**ingle Responsibility: each class and function has one reason to change.
- **O**pen/Closed: extend behavior without modifying existing code.
- **L**iskov Substitution: subtypes must be substitutable for their base types.
- **I**nterface Segregation: prefer small, focused interfaces.
- **D**ependency Inversion: depend on abstractions, not concretions.

## Immutability

- Prefer immutable data structures.
- Widgets should be immutable — state lives in ViewModels and Signals, not in the widget tree.
- Use `const` constructors wherever possible to reduce rebuilds.
- Minimize mutable local state.
- Avoid top-level mutable state — no hidden globals, no shared mutable singletons without justification.

## Functions and Methods

- Keep functions short and single-purpose. Strive for fewer than 20 lines.
- Use arrow syntax (`=>`) for simple one-line functions.
- Avoid performing expensive operations (network calls, complex computations) directly within `build()` methods.
- Avoid boolean parameter traps (`createUser(true, false, true)`) — prefer named parameters or enums.

## Performance

- Use `const` constructors in `build()` methods whenever possible.
- Use `ListView.builder` or `SliverList` for long/dynamic lists (lazy loading).
- Use `compute()` / `Isolate.run()` for expensive calculations to avoid blocking the UI thread.
- Avoid rebuilding the entire widget tree — extract subtrees into separate widget classes.
- Avoid unnecessary opacity/clipping/layout complexity, especially in scrolling views.
- Minimize allocations in hot paths — do not recreate large lists, maps, or callbacks every frame.

## Layout Best Practices

- **`Expanded`:** Fill remaining space along the main axis.
- **`Flexible`:** Shrink to fit but not grow. Do not combine `Flexible` and `Expanded` in the same `Row`/`Column`.
- **`Wrap`:** When children would overflow and should flow to the next line.
- **`SingleChildScrollView`:** For content larger than the viewport but of fixed size.
- **`ListView.builder` / `GridView.builder`:** For long lists or grids — always use `.builder` constructors.
- **`FittedBox`:** Scale or fit a single child within its parent.
- **`LayoutBuilder`:** For responsive layouts that adapt to available space.
- **`OverlayPortal`:** For showing UI elements (dropdowns, tooltips) on top of everything else.

## Widget Composition

- Prefer composing smaller widgets over extending existing ones.
- Use small, **private Widget classes** instead of helper methods that return widgets.
- Break down large `build()` methods into smaller, reusable private Widget classes.

## Testing Preferences

- Follow the **Arrange-Act-Assert** (Given-When-Then) pattern.
- **Prefer fakes and stubs over mocks.** Use mocks (`mockito`/`mocktail`) only when fakes are impractical.
- Prefer `package:checks` for expressive, readable assertions over default matchers.
- Write unit tests for domain logic, data layer, and state management.
- Write widget tests for UI components.
- Use integration tests for end-to-end user flows.
- Aim for high test coverage.

## Error Handling

- Anticipate and handle potential errors. Do not let code fail silently.
- Use `try-catch` blocks with exceptions appropriate for the error type.
- Use custom exceptions for domain-specific situations.
- Do not overuse exceptions for expected control flow — validation failure or empty results are often not exceptional.

## Documentation

- Use `///` for doc comments on all public APIs.
- Start with a single-sentence summary ending with a period.
- Add a blank line after the first sentence to separate the summary from details.
- Comment **why** the code is written a certain way, not **what** it does.
- Do not add trailing comments.
- Do not write documentation that merely restates the obvious from the name.
- Place doc comments before annotations.

## Naming and Style

- Use `PascalCase` for classes, `camelCase` for members/variables/functions/enums, and `snake_case` for files.
- Avoid abbreviations. Use meaningful, consistent, descriptive names.
- Follow the official Effective Dart guidelines: https://dart.dev/effective-dart

## Accessibility

- Ensure text has a contrast ratio of at least **4.5:1** against its background (WCAG 2.1).
- Large text (18pt or 14pt bold) requires at least **3:1**.
- Test UI with increased system font sizes (dynamic text scaling).
- Use the `Semantics` widget to provide clear, descriptive labels for UI elements.
- Regularly test with TalkBack (Android) and VoiceOver (iOS).

## Async/Await and Concurrency

- Use `Future`, `async`, and `await` for asynchronous operations with robust error handling.
- Use `Stream` for sequences of asynchronous events.
- Await futures intentionally — avoid fire-and-forget unless explicitly safe.
- Cancel/dispose subscriptions and listeners correctly.
- Guard against race conditions: rapid taps, stale async responses, state updates after disposal.

## Class and Library Organization

- Define related classes within the same library file.
- For large libraries, export smaller private libraries from a single top-level library.
- Group related libraries in the same folder.
- Keep extensions focused with narrow, obvious purposes — do not use as dumping grounds.

## Project Default Conventions

These are the standard conventions used across projects. They are not configurable per-project unless explicitly overridden in `CLAUDE.md`.

| Topic | Default Convention |
|-------|-------------------|
| State management | Signals + HookWidget |
| Navigation | go_router |
| UI components | obers_ui via `uikit` abstraction layer |
| Serialization | Serverpod models + `.spy.yaml` (when using Serverpod) |
| Code generation | `serverpod generate` (when using Serverpod) |
| DI | GetIt |
