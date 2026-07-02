---
name: flutter-debug-state
description: Primary workflow for debugging state management issues in a Flutter app. Use when the user reports that a screen does not update, a button does nothing, stale data is shown, or the UI is not reacting to state changes.
role: primary_workflow
scope: flutter
trigger: direct_match
pairs_with:
  - project-patterns
  - flutter-testing
---

# Debug State Management Issue

This skill should own Flutter state-debugging work.

## Triggers

Use this skill when the user reports:

- "Screen does not update"
- "Button doesn't do anything"
- "Stale data / showing old values"
- "Signal not reacting"
- "ViewModel change not reflected in UI"

## Full data flow (for context)

```
onPressed (Widget)
  → vm.someMethod() (ViewModel)
    → useCase.execute() (UseCase)
      → repository.someSignal / repository.doSomething() (Repository)
        → dataSource.fetch() (DataSource)
          → serverpodClient.endpoint.method() (Serverpod)
```

State flows back up via `Signal<T>` in the Repository, exposed as `ReadonlySignal<T>` through the ViewModel.

## Step 1 — Find the obvious issue

Read the relevant widget, ViewModel, UseCase, and Repository files. Check for:

- Widget reads a plain value instead of watching a signal (missing `useSignal` / `.watch(context)`)
- ViewModel exposes a `Signal` directly instead of `ReadonlySignal` (signal mutated externally)
- UseCase updates the wrong signal or forgets to call the repository write method
- Repository method updates a local variable instead of the `Signal`
- `di` registration missing — ViewModel resolves to a different instance than the one the widget holds

Report any obvious finding to the user and suggest the fix before proceeding to Step 2.

## Step 2 — Add logging at each layer

If no obvious issue is found, add temporary `print` / `debugPrint` statements at each layer:

```dart
// Widget — confirm method is called
onPressed: () {
  debugPrint('[Widget] button pressed');
  vm.someMethod();
}

// ViewModel
void someMethod() {
  debugPrint('[ViewModel] someMethod called');
  useCase.execute();
}

// UseCase
Future<void> execute() async {
  debugPrint('[UseCase] execute called');
  await repository.doSomething();
}

// Repository
Future<void> doSomething() async {
  debugPrint('[Repository] doSomething called');
  final result = await dataSource.fetch();
  debugPrint('[Repository] result: $result');
  _itemsSignal.value = result; // confirm signal is updated
}
```

## Step 3 — Ask the user to reproduce

Tell the user:

> "I've added logging at each layer. Please reproduce the issue and share the debug output from the console."

## Step 4 — Diagnose from logs

| Last log seen                               | Likely cause                                       |
| ------------------------------------------- | -------------------------------------------------- |
| `[Widget] button pressed` — nothing after   | ViewModel not resolving / wrong instance           |
| `[ViewModel]` — nothing after               | UseCase not called or wrong DI instance            |
| `[UseCase]` — nothing after                 | Repository call missing or async not awaited       |
| `[Repository] result: ...` but UI unchanged | Signal not watched in widget (`useSignal` missing) |
| No logs at all                              | `onPressed` not wired up correctly                 |

## Step 5 — Fix and clean up

Apply the fix, remove all debug logging, then run:

```bash
flutter analyze
flutter test
```
