---
title: Exceptions
description: The sealed BeakException family, each variant's stable code, the HTTP status it maps to, and when Beak throws it.
---

# Exceptions

After this page you can name every failure Beak raises, know the `code` and HTTP
status each one carries, and follow an error from the layer that throws it to the
JSON on the wire to the `BeakResult` a view model reads.

Beak has exactly one exception hierarchy. It is a **sealed** family rooted at
`BeakException`, so the switch that maps an error to an HTTP response is checked
for completeness at compile time. Add a variant and every mapper stops compiling
until it handles the new case. There are no stray `Exception`s, no strings, and
no `dynamic` payloads in Beak's error surface.

## The base type

Every failure carries two things: a stable machine-readable `code` for wire
formats and a human-readable `message` for people.

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
--8<-- "packages/beak_core/lib/src/common/beak_exception.dart:BeakException"
```

The `code` is the contract. It travels in the JSON error body, and the frontend
rebuilds the exact same typed exception from it. The `message` is free text a
form or toast can show.

## The seven variants at a glance

| Exception | `code` | HTTP status | Beak throws it when |
| --- | --- | --- | --- |
| `BeakValidationException` | `validation` | 422 | user-supplied data violates one or more column [rules](../models/validation-rules.md); carries per-field errors |
| `BeakNotFoundException` | `not_found` | 404 | a requested record or resource does not exist for the given id |
| `BeakAuthenticationException` | `authentication` | 401 | the request carries no valid identity: missing, invalid, or expired credentials |
| `BeakAuthorizationException` | `authorization` | 403 | the authenticated principal is not allowed to perform the operation |
| `BeakConflictException` | `conflict` | 409 | an operation conflicts with existing state: a duplicate unique value or a concurrent modification |
| `BeakConfigurationException` | `configuration` | 500 | Beak itself is set up wrong: a missing driver, a duplicate column key, an unregistered model, a bad env value. A developer error, not user input |
| `BeakStorageException` | `storage` | 500 | a storage driver fails to store, read, or delete a file |

Anything that is **not** a `BeakException` never reaches the client typed. The
error-mapping middleware turns it into an opaque `500` with `code: 'internal'` and
reports it to the unexpected-error listener, so server internals never leak.

## Each variant

The constructors below are copied verbatim. Only `BeakValidationException` adds a
field beyond `message`.

### BeakValidationException

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
final class BeakValidationException extends BeakException {
  const BeakValidationException(String message, {this.fieldErrors = const {}})
    : super(code: 'validation', message: message);

  /// Validation messages aggregated per column key.
  final Map<String, List<String>> fieldErrors;

  // ... a toString that appends fieldErrors ...
}
```

The backend's `ValidationService` collects every rule failure, keys the messages
by column, and throws once so a form can highlight each offending input:

```dart title="packages/beak_backend/lib/src/service/validation_service.dart"
/// Applies the shared core validator at the backend write boundary.
final class ValidationService {
  /// Creates the stateless validation boundary.
  const ValidationService();

  /// Rejects malformed fields and shared model rules with structured errors.
  /// [initial] supplies omitted fields and relations for partial updates.
  /// Graph commits defer record rules until the final transaction state exists.
  void validate(
    BeakModel model,
    BeakRecord input, {
    required bool isCreate,
    BeakRecord? initial,
    bool includeRecordRules = true,
  }) {
    final errors = const BeakValidation().validate(
      model,
      input,
      isCreate: isCreate,
      initial: initial,
      includeRecordRules: includeRecordRules,
    );
    if (errors.isNotEmpty) {
      throw BeakValidationException(
        'Validation failed for "${model.table}".',
        fieldErrors: errors,
      );
    }
  }
}
```

`fieldErrors` is the only structured payload in the family. It maps a column key
to its list of messages (`{'price': ['Must be greater than 0']}`) and rides along
in the JSON body under `fieldErrors`.

### BeakNotFoundException

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
final class BeakNotFoundException extends BeakException {
  const BeakNotFoundException(String message)
    : super(code: 'not_found', message: message);
}
```

Thrown by the service layer when a lookup by primary key comes back empty:

```dart title="packages/beak_backend/lib/src/service/beak_resource_service.dart"
Future<BeakRecord> getOne(Object id, {BeakFilter? scope}) async =>
    await _findInScope(id, scope) ??
    (throw BeakNotFoundException(
      'No record of "${model.table}" with id "$id".',
    ));
```

A record a [row policy](../backend/auth-and-policies.md) scope excludes reports
as missing too, not as forbidden. Telling a caller that a row they cannot
address exists is itself a leak.

### BeakAuthenticationException

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
final class BeakAuthenticationException extends BeakException {
  const BeakAuthenticationException(String message)
    : super(code: 'authentication', message: message);
}
```

The 401 counterpart to authorization's 403. Raised when the login credentials are
wrong or a guarded route is hit without a session:

```dart title="packages/beak_backend/lib/src/auth/auth_router.dart"
throw const BeakAuthenticationException('Invalid username or password.');
```

### BeakAuthorizationException

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
final class BeakAuthorizationException extends BeakException {
  const BeakAuthorizationException(String message)
    : super(code: 'authorization', message: message);
}
```

A [policy](../backend/auth-and-policies.md) denies an action to a signed-in
principal. Note how the same guard picks the right exception based on whether a
principal is present at all:

```dart title="packages/beak_backend/lib/src/auth/beak_policy.dart"
if (principal == null) {
  throw BeakAuthenticationException('Sign in to $action "$table".');
}
throw BeakAuthorizationException(
  'Principal "${principal.id}" is not allowed to $action "$table".',
);
```

### BeakConflictException

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
final class BeakConflictException extends BeakException {
  const BeakConflictException(String message)
    : super(code: 'conflict', message: message);
}
```

The slot for state conflicts: a duplicate unique value or a concurrent
modification. The 409 mapping and the wire decode are already in place, so a
`BeakDataSource` (or a custom service) that surfaces a duplicate-key violation as
`BeakConflictException` reaches the client fully typed.

### BeakConfigurationException

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
final class BeakConfigurationException extends BeakException {
  const BeakConfigurationException(String message)
    : super(code: 'configuration', message: message);
}
```

A developer mistake, not a user one: a [registry](../models/the-registry.md)
lookup for an unregistered table, a duplicate column key, a missing environment
variable. It maps to `500` because it means the deployment is misconfigured. This
is also the fallback the client decoder uses for an unrecognized error `code`.

It has one subclass, `BeakRecordShapeException`, thrown by
`BeakTypedColumn.require` when a record carries no readable value for the column
(absent, null, or the wrong shape). It carries the `columnKey` and the
`expectedType`, and it travels as `configuration` like any other, because a
record missing a column the code demands is a wiring mistake.

### BeakStorageException

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
final class BeakStorageException extends BeakException {
  const BeakStorageException(String message)
    : super(code: 'storage', message: message);
}
```

A [storage driver](../models/files-and-storage-columns.md) could not put, get, or
delete a file, or a storage key failed validation. The built-in drivers throw it
directly:

```dart title="packages/beak_core/lib/src/storage/drivers/beak_memory_storage_driver.dart"
throw BeakStorageException('No file is stored under "$key".');
```

## How an exception crosses the wire

Exceptions are thrown by the [Service and DataSource layers](../concepts/the-four-layers.md)
and never caught there. The backend has exactly one catch boundary, the
error-mapping middleware, and it is an exhaustive switch:

```dart title="packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart"
Response _exceptionResponse(BeakException exception, Request request) {
  final int statusCode = switch (exception) {
    BeakValidationException() => 422,
    BeakNotFoundException() => 404,
    BeakAuthenticationException() => 401,
    BeakAuthorizationException() => 403,
    BeakConflictException() => 409,
    BeakConfigurationException() => 500,
    BeakStorageException() => 500,
  };
  // ... encodes {code, message, fieldErrors?, requestId?} as JSON.
}
```

!!! note "What just happened"
    The middleware wraps the whole handler chain. A `BeakException` becomes its
    status plus a `{code, message}` JSON body (with `fieldErrors` when present).
    Any other throw becomes an opaque `500` with `code: 'internal'`, so a stack
    trace never lands in a client.

On the frontend, `BeakClient` reads that JSON back and rebuilds the same typed
exception from the `code`, so the two sides speak one vocabulary:

```dart title="packages/beak_core/lib/src/client/beak_client.dart"
throw switch (body['code']) {
  'validation' => BeakValidationException(
    message,
    fieldErrors: _fieldErrors(body),
  ),
  'not_found' => BeakNotFoundException(message),
  'authentication' => BeakAuthenticationException(message),
  'authorization' => BeakAuthorizationException(message),
  'conflict' => BeakConflictException(message),
  'storage' => BeakStorageException(message),
  _ => BeakConfigurationException(message),
};
```

An unknown `code` falls back to `BeakConfigurationException`, because an error the
client cannot categorize means the two sides disagree about the contract.

## Where exceptions turn into results

View models never `try/catch`. The frontend's `BeakResourceRepository` is the
catch boundary: it wraps each data-source call, and any thrown `BeakException`
surfaces as a `BeakErr`, so callers switch on an outcome instead of catching.

```dart title="packages/beak_frontend/lib/src/data/beak_run.dart"
Future<BeakResult<T>> beakRun<T>(
  Future<T> Function() operation, {
  BeakException? Function(Exception exception, StackTrace stack)? mapException,
}) async {
  try {
    return BeakOk(await operation());
  } on BeakException catch (exception) {
    return BeakErr(exception);
  } on Exception catch (exception, stack) {
    final mapped = mapException?.call(exception, stack);
    if (mapped != null) return BeakErr(mapped);
    rethrow;
  }
}
```

From there a `BeakErr(BeakValidationException(...))` flows into a form's field
errors, a `BeakErr(BeakNotFoundException(...))` into a "not found" state, and so
on. See [Results and errors](../concepts/results-and-errors.md) for the full
`BeakResult` story.

## Continue reading

- [Results and errors](../concepts/results-and-errors.md) how `BeakResult` wraps a failure so nobody up the stack needs a `try/catch`.
- [Middleware](../backend/middleware.md) the request stack the error-mapping boundary sits in.
- [Auth and policies](../backend/auth-and-policies.md) where the 401 and 403 exceptions come from.
- [Glossary](glossary.md) the rest of Beak's vocabulary in one place.
