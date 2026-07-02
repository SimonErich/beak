---
name: typed-exceptions
description: Mandatory guardrail for exception class design, naming, placement, and hierarchy. Enforces typed exceptions over bare Exception and defines when to create vs. reuse exception classes.
role: guardrail
scope: general
trigger: auto_with_workflow
pairs_with:
  - error-handling
  - serverpod-error-handling
---

# Typed Exception Rules

Use this skill to constrain exception design decisions. Read it before creating, throwing, or catching custom exceptions.

## Absolute Rules

1. **Never `throw Exception(...)`** — always use a typed exception class. The `avoid_generic_exception_throw` lint rule enforces this.
2. **All custom exceptions `implements Exception`** — not `extends`. Dart convention reserves `Error` and its subtypes for programmer mistakes (bugs); `Exception` is for recoverable failures.
3. **All custom exceptions must have a `message` field** of type `String`.
4. **Override `toString()` consistently** — return `'$runtimeType: $message'` so logs and stack traces identify the exception type immediately.
5. **No more than one level of subclassing** — deep exception hierarchies obscure intent. One base category, one optional subclass. No deeper.
6. **No exception for expected outcomes** — exceptions are for failures that interrupt normal flow. Use return types (booleans, enums, sealed result classes) for expected business outcomes like "user already exists."

## Decision Flowchart

```
You need to throw an exception.
|
+-- Does a shared exception in core/exceptions/ already fit?
|   +-- YES -> Use it. Pass a descriptive message string.
|   +-- NO -> Continue.
|
+-- Does the exception cross feature boundaries
|   (thrown in one feature, caught in another, or used in core)?
|   +-- YES -> Create it in core/exceptions/.
|   +-- NO -> Continue.
|
+-- Is it specific to a single feature and will never
|   be caught outside that feature?
|   +-- YES -> Create it in the feature's exceptions directory.
|   +-- NO -> Create it in core/exceptions/.
|
+-- Is it a narrower variant of an existing category?
|   (e.g., DuplicateEmailException is a kind of ConflictException)
    +-- YES -> Subclass the existing category exception.
    +-- NO -> Create a new top-level category.
```

## Naming Convention

Pattern: **`<FailureDomain>Exception`** where the domain describes the failure category, not the operation that failed.

The name should answer: **"What kind of failure happened?"** — not "Which function threw it?"

### Good Names

| Name | Describes |
|---|---|
| `NetworkException` | A network-level failure |
| `ValidationException` | Input did not meet constraints |
| `AuthorizationException` | Caller lacks permission |
| `NotFoundException` | Requested entity does not exist |
| `ConflictException` | State conflict or duplicate |
| `ConfigurationException` | Bad or missing configuration |
| `ParsingException` | Structured data could not be parsed |
| `StorageException` | Local storage read/write failure |
| `ExportException` | Data export to external system failed |

### Bad Names

| Name | Problem | Fix |
|---|---|---|
| `CreateOrderException` | Operation-named — ties the exception to one call site | `ValidationException` or `ConflictException` depending on why it failed |
| `BadException` | Meaningless | Name the failure domain |
| `MyException` | Meaningless | Name the failure domain |
| `OrderError` | Wrong suffix — `Error` implies a programmer bug, not a recoverable failure | `OrderException` or a category like `ValidationException` |
| `GenericException` | Defeats the purpose of typed exceptions | Pick the actual category |
| `ApiException` | Too broad — every HTTP call would throw the same type | `NetworkException`, `AuthorizationException`, or `NotFoundException` |

### Naming Heuristics

1. **Prefer category over domain entity** — `ValidationException('Order must have items')` over `OrderValidationException('must have items')`. The message carries the entity context; the type carries the failure category.
2. **Create entity-scoped exceptions only when catch-site differentiation requires it** — if you need to catch `WarehouseExportException` separately from `ReportExportException` in the same try block, the entity-scoped name is justified.
3. **Subclass names narrow the parent** — `DuplicateEmailConflictException extends ConflictException` tells the reader it is a specific kind of conflict.

## Base Category Set

Start every project with this shared set. Add categories only when a real use case requires a new catch target.

```dart
// core/exceptions/network_exception.dart
class NetworkException implements Exception {
  NetworkException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'NetworkException: $message';
}
```

```dart
// core/exceptions/validation_exception.dart
class ValidationException implements Exception {
  ValidationException(this.message, {this.fieldErrors});
  final String message;
  final Map<String, String>? fieldErrors;

  @override
  String toString() => 'ValidationException: $message';
}
```

```dart
// core/exceptions/authorization_exception.dart
class AuthorizationException implements Exception {
  AuthorizationException(this.message);
  final String message;

  @override
  String toString() => 'AuthorizationException: $message';
}
```

```dart
// core/exceptions/not_found_exception.dart
class NotFoundException implements Exception {
  NotFoundException(this.message);
  final String message;

  @override
  String toString() => 'NotFoundException: $message';
}
```

```dart
// core/exceptions/conflict_exception.dart
class ConflictException implements Exception {
  ConflictException(this.message);
  final String message;

  @override
  String toString() => 'ConflictException: $message';
}
```

```dart
// core/exceptions/configuration_exception.dart
class ConfigurationException implements Exception {
  ConfigurationException(this.message);
  final String message;

  @override
  String toString() => 'ConfigurationException: $message';
}
```

```dart
// core/exceptions/parsing_exception.dart
class ParsingException implements Exception {
  ParsingException(this.message);
  final String message;

  @override
  String toString() => 'ParsingException: $message';
}
```

Do not pre-create exceptions "just in case." Only add a category when production code actually needs to throw and catch it.

**Timeouts:** Use `dart:async` `TimeoutException` for `Future` timeouts. Only create an `OperationTimeoutException` if you need additional fields (like `operationName`) that the SDK type does not carry.

## Folder Placement Rules

| Project Type | Shared Exceptions | Feature-Specific Exceptions |
|---|---|---|
| Flutter | `lib/core/exceptions/` | `lib/features/<feature>/domain/exceptions/` |
| Serverpod server | `lib/src/core/exceptions/` | `lib/src/features/<feature>/exceptions/` |
| Dart CLI / package | `lib/src/exceptions/` | N/A (flat structure; all go in `lib/src/exceptions/`) |

**File naming:** `<snake_case_name>_exception.dart` (e.g., `validation_exception.dart`, `not_found_exception.dart`).

**One exception class per file** unless exceptions share an inheritance hierarchy and the file stays under 50 lines.

## Exception Class Template

Every custom exception follows this structure:

```dart
class <Name>Exception implements Exception {
  <Name>Exception(this.message);
  final String message;

  @override
  String toString() => '<Name>Exception: $message';
}
```

### Optional Fields

Add optional fields only when catch sites need them for decision-making, not for logging convenience.

| Field | Type | When to Add |
|---|---|---|
| `statusCode` | `int?` | On `NetworkException` — catch sites may retry on 503 but not on 404 |
| `fieldErrors` | `Map<String, String>?` | On `ValidationException` — UI needs per-field error display |
| `innerException` | `Object?` | When re-throwing a wrapped cause that catch sites may inspect |

Do not add fields like `stackTrace` or `timestamp` — these are available from the catch site context already.

## When to Subclass vs. New Category

### Subclass When

- The failure is a **narrower variant** of an existing category.
- Callers already catch the parent type, and the subclass adds a **more specific match target** without breaking existing handlers.
- Example: `DuplicateEmailConflictException extends ConflictException` — caught by `on ConflictException` but also matchable as `on DuplicateEmailConflictException`.

```dart
class DuplicateEmailConflictException extends ConflictException {
  DuplicateEmailConflictException(super.message);

  @override
  String toString() => 'DuplicateEmailConflictException: $message';
}
```

### Create a New Category When

- The failure does not fit any existing category's semantic meaning.
- Catch blocks for the new failure need **fundamentally different handling** (retry vs. show error vs. redirect).

### Never

- Create a subclass more than one level deep (`A extends B extends C` — too deep).
- Create a subclass just to avoid passing a message string — use the message field instead.

## Interaction with Serverpod

When working in a Serverpod project, both this skill and `serverpod-error-handling` apply:

| Concern | Skill |
|---|---|
| **What** exceptions to create (naming, structure, placement) | `typed-exceptions` (this skill) |
| **Where** to throw and catch (endpoints vs. services vs. repositories) | `serverpod-error-handling` |
| **How** to map to client-safe responses (`SerializableException`) | `serverpod-error-handling` |

The base categories defined here align with the standard set in `serverpod-error-handling`. Use the same classes — do not create duplicates.

## Anti-Patterns

### Too Many Exception Classes

```dart
// BAD — one exception per operation
class CreateOrderException implements Exception { ... }
class UpdateOrderException implements Exception { ... }
class DeleteOrderException implements Exception { ... }
class FetchOrderException implements Exception { ... }

// GOOD — category exceptions with descriptive messages
throw ValidationException('Order must have at least one item');
throw NotFoundException('Order $id does not exist');
throw ConflictException('Order $id has already been shipped');
```

**Guideline:** If a feature has more than 3-4 custom exception classes, consolidate. The `message` field carries specificity; the class carries the category.

### Catching Exception Broadly

```dart
// BAD — hides failure types in service/application code
try {
  await orderService.create(dto);
} on Exception catch (e) {
  log(e.toString());
  return null;
}

// GOOD — catch specific types
try {
  await orderService.create(dto);
} on ValidationException catch (e) {
  showFieldErrors(e.fieldErrors);
} on ConflictException catch (e) {
  showMessage('This order already exists');
}
```

### Exception-String Parsing

```dart
// BAD — fragile, breaks on message changes
try {
  await repository.findById(id);
} on Exception catch (e) {
  if (e.toString().contains('not found')) {
    return null;
  }
  rethrow;
}

// GOOD — typed catch
try {
  await repository.findById(id);
} on NotFoundException {
  return null;
}
```

### Exceptions for Control Flow

```dart
// BAD — exception for expected outcome
Future<bool> emailExists(String email) async {
  try {
    await repository.findByEmail(email);
    return true;
  } on NotFoundException {
    return false;
  }
}

// GOOD — explicit query
Future<bool> emailExists(String email) async {
  final user = await repository.findByEmailOrNull(email);
  return user != null;
}
```

### Deep Exception Hierarchies

```dart
// BAD — too deep
class AppException implements Exception { ... }
class DataException extends AppException { ... }
class NetworkDataException extends DataException { ... }
class TimeoutNetworkDataException extends NetworkDataException { ... }

// GOOD — max one level
class NetworkException implements Exception { ... }
class TimeoutNetworkException extends NetworkException { ... }
```

## Checklist

- [ ] No bare `throw Exception(...)` in non-generated, non-test code
- [ ] Every custom exception `implements Exception` and has a `message` field
- [ ] `toString()` overridden with `'$runtimeType: $message'` pattern
- [ ] Shared exceptions in `core/exceptions/`, not scattered across features
- [ ] Feature-specific exceptions only when the exception is never caught outside that feature
- [ ] Exception name describes the failure domain, not the operation
- [ ] No more than one level of subclassing
- [ ] No exception-string parsing for control flow
- [ ] No `catch (e)` or `on Exception catch (e)` in service/application code
- [ ] No exceptions for expected business outcomes — use return types instead
- [ ] Existing base category covers the case before creating a new exception class
