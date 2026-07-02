---
name: getit-dependency-injection
scope: flutter
description: Manual on-demand reference for GetIt dependency injection usage, boundaries, registration patterns, and test setup.
role: manual_execution
trigger: explicit_request
---

# GetIt Dependency Injection (On Demand)

Use this skill when the user explicitly asks how dependency injection works, where it is allowed, where it is forbidden, how dependencies are registered, or how tests should wire mocks.

## Canonical DI Entry Point

All Flutter DI access must go through the global variable in `<project>_flutter/lib/di.dart`:

```dart
import 'package:<project>_flutter/di.dart';

final vm = di<FeatureViewModel>();
```

Do not use `GetIt.I`, `GetIt.instance`, or ad hoc local aliases in feature code.

## Where DI Is Used

- Flutter feature composition and state flow:
  - `UI -> ViewModel -> UseCase -> Repository -> DataSource`
- Flutter registrations:
  - `<project>_flutter/lib/features/<feature>/di/service_locator.dart`
  - `<project>_flutter/lib/service_locator.dart` (global setup entry point)
- Flutter runtime resolution:
  - Screens/widgets resolve ViewModels through `di<FeatureViewModel>()`
  - UseCases/Repositories/DataSources resolve constructor fallbacks through `di<T>()` when optional constructor args are not supplied

## Where DI Is NOT Used

- Pure helpers/formatters/extensions/mappers that should stay deterministic and side-effect free
- Stateless utility functions that do not require runtime dependencies
- Data transformation logic that belongs in pure mappers
- Tests that can pass dependencies directly via constructors without touching the container
- Non-Flutter code unless that layer has its own explicit DI contract

## GetIt Features We Use

Use only the subset below unless a task explicitly extends the DI contract:

- `registerFactory<T>()` for DataSources, UseCases, and ViewModels
- `registerLazySingleton<T>()` for Repositories (shared signal ownership)
- `di<T>()` / `di.get<T>()` for dependency resolution
- `di.isRegistered<T>()` for guard checks in diagnostics and test setup
- `di.reset()` for test cleanup between cases

Avoid advanced patterns by default (named registrations, scopes, async registration) unless the task requires them and the user approves.

## Registration Pattern (Setup)

Register in this order inside each feature `di/service_locator.dart`:

1. DataSource (`registerFactory`)
2. Repository (`registerLazySingleton`)
3. UseCases (`registerFactory`)
4. ViewModel (`registerFactory`)

```dart
import 'package:<project>_flutter/di.dart';

void setupFeatureDependencies() {
  di
    ..registerFactory<FeatureDataSource>(FeatureDataSource.new)
    ..registerLazySingleton<FeatureRepository>(FeatureRepository.new)
    ..registerFactory<LoadFeatureUseCase>(LoadFeatureUseCase.new)
    ..registerFactory<FeatureViewModel>(FeatureViewModel.new);
}
```

Global setup (`<project>_flutter/lib/service_locator.dart`) imports each feature's DI file and invokes their setup methods.

## Runtime Resolution Pattern

Use constructor injection with DI fallback:

```dart
class LoadFeatureUseCase {
  LoadFeatureUseCase({FeatureRepository? repository})
      : _repository = repository ?? di<FeatureRepository>();

  final FeatureRepository _repository;
}
```

Widget/ViewModel access:

```dart
final vm = di<FeatureViewModel>();
```

## Testing Pattern

Prefer constructor injection for unit tests. Use DI only when exercising integration wiring.

For container-based tests:

```dart
import 'package:<project>_flutter/di.dart';

setUp(() async {
  await di.reset();
  di.registerLazySingleton<WalletRepository>(() => MockWalletRepository());
  di.registerFactory<LoadWalletUseCase>(() => MockLoadWalletUseCase());
});
```

Guidelines:

- Reset container state between tests (`await di.reset()`)
- Register test doubles before creating subject-under-test
- Keep registrations local to each test file; no hidden global test setup unless deliberate

## Checklist

- [ ] Imports use `package:<project>_flutter/di.dart`
- [ ] All resolution uses `di<T>()` (not `GetIt.I`)
- [ ] Registration order is DataSource -> Repository -> UseCase -> ViewModel
- [ ] Repositories use `registerLazySingleton`, not `registerFactory`
- [ ] ViewModels/UseCases/DataSources use `registerFactory`
- [ ] Tests either inject via constructor or reset/re-register through `di`
