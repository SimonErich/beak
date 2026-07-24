---
title: Results and errors
description: How Beak models failure as typed exceptions and typed values, and the typed row model that carries data across every boundary without dynamic.
---

# Results and errors

Beak has two ways to signal that something went wrong, and one typed shape for
the data that flows when nothing does. After this page you know when Beak throws
and when it returns a value, which exception maps to which situation, and how a
row stays typed from the database all the way to the widget.

## Two ways to fail: throw or return

The layering rule decides which mechanism a piece of code uses.

- **Exceptions travel at layer boundaries.** A Shelf handler on the backend and a
  repository on the frontend are the catch points. Services and data sources
  throw; the boundary catches.
- **`BeakResult` travels at the value level.** When a failure should ride along
  with the data instead of unwinding the stack (a parse, a validation, a
  per-item outcome), Beak returns a result you switch on.

`BeakResult` is a sealed pair: `BeakOk` carries a value, `BeakErr` carries a
`BeakException`.

```dart title="packages/beak_core/lib/src/common/beak_result.dart"
@immutable
sealed class BeakResult<T> {
  const BeakResult();

  /// Whether this result is a [BeakOk].
  bool get isOk;

  /// The success value; throws the wrapped [BeakException] on a [BeakErr].
  T get valueOrThrow;

  /// Reduces both cases into a single value of type [R].
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(BeakException error) onErr,
  });

  /// Transforms the success value with [transform], leaving errors untouched.
  BeakResult<R> map<R>(R Function(T value) transform);
}
```

Collapse both cases into one value with `fold`, or keep the failure and rework
only the success with `map`:

```dart title="packages/beak_core/lib/src/common/beak_result.dart"
BeakResult<int> parseQuantity(String raw) {
  final int? value = int.tryParse(raw);
  return value == null
      ? BeakErr(BeakValidationException('"$raw" is not a number'))
      : BeakOk(value);
}

final String label = parseQuantity('12').fold(
  onOk: (value) => 'quantity: $value',
  onErr: (error) => 'invalid: ${error.message}',
);
```

## The exception family

Every failure Beak raises is a `BeakException`. The type is sealed and each
variant carries a stable, machine-readable `code` (for wire formats) and a
human-readable `message`.

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
@immutable
sealed class BeakException implements Exception {
  /// Creates an exception carrying a stable [code] and a [message].
  const BeakException({required this.code, required this.message});

  /// Stable machine-readable identifier of the failure category.
  final String code;

  /// Human-readable description of what went wrong.
  final String message;

  @override
  String toString() => '$runtimeType($code): $message';
}
```

There are seven variants. Pick the one whose meaning matches; the code and the
HTTP status follow from the type.

| Exception | `code` | Raised when |
| --- | --- | --- |
| `BeakValidationException` | `validation` | User input violates column rules. Carries `fieldErrors` per column key. |
| `BeakNotFoundException` | `not_found` | A requested record or resource does not exist. |
| `BeakAuthenticationException` | `authentication` | A request carries no valid identity (missing, invalid, or expired credentials). |
| `BeakAuthorizationException` | `authorization` | The current user is not allowed to perform the operation. |
| `BeakConfigurationException` | `configuration` | Beak itself is set up wrong (missing driver, duplicate key). A developer error, not user input. |
| `BeakStorageException` | `storage` | A storage driver fails to store, read, or delete a file. |
| `BeakConflictException` | `conflict` | An operation conflicts with existing state (duplicate unique value, concurrent modification). |

Because the family is sealed, the backend's exception-to-response mapping is an
exhaustive switch: add a variant and every mapper stops compiling until it
handles the new case.

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
int httpStatus(BeakException exception) => switch (exception) {
  BeakValidationException() => 422,
  BeakNotFoundException() => 404,
  BeakAuthenticationException() => 401,
  BeakAuthorizationException() => 403,
  BeakConflictException() => 409,
  BeakConfigurationException() => 500,
  BeakStorageException() => 500,
};
```

`BeakValidationException` is the one that carries structure. Its `fieldErrors`
map lets a form highlight the offending inputs individually instead of showing
one blanket message.

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
throw const BeakValidationException(
  'The product could not be saved.',
  fieldErrors: {
    'price': ['Must be greater than 0'],
    'sku': ['Already taken'],
  },
);
```

## Failure becomes a value at the repository

On the frontend, the catch boundary is `BeakResourceRepository`. It wraps every
data-source call: a thrown `BeakException` comes back as `BeakErr`, and anything
else still propagates (a real bug should not be silently swallowed).

```dart title="packages/beak_frontend/lib/src/data/beak_resource_repository.dart"
Future<BeakResult<T>> _guard<T>(Future<T> Function() run) async {
  try {
    return BeakOk(await run());
  } on BeakException catch (exception) {
    return BeakErr(exception);
  }
}
```

Above the repository, view models never write `try/catch`. They receive a
`BeakResult` and switch on the outcome, which keeps the failure path visible in
the type rather than hidden in control flow.

```dart title="packages/beak_frontend/lib/src/data/beak_resource_repository.dart"
final repository = BeakResourceRepository(dataSource);
final result = await repository.query(
  const BeakQuerySpec(table: 'products'),
);
switch (result) {
  case BeakOk(:final value):
    print('${value.items.length} products');
  case BeakErr(:final error):
    print('load failed: ${error.message}');
}
```

!!! note "What just happened"
    - The data source threw a typed `BeakException` (or returned normally).
    - The repository caught it and handed back a `BeakResult`.
    - The view model matched `BeakOk` or `BeakErr`, no `try/catch` in sight.
    - The frontend flow is Widget then ViewModel then Repository then DataSource;
      the repository is the single catch point.

## The typed row: BeakValue and BeakRecord

Data crossing a boundary is never a `Map<String, dynamic>`. Beak wraps each cell
in a `BeakValue` and each row in a `BeakRecord`, so a value keeps its type from
the database to the widget and query specs serialize losslessly.

A `BeakValue` is a sealed wrapper with a variant per primitive. Build one from
plain Dart with `BeakValue.of`, which picks the matching variant and throws a
`BeakConfigurationException` for anything it cannot represent.

```dart title="packages/beak_core/lib/src/query/beak_value.dart"
static BeakValue of(Object? raw) => switch (raw) {
  null => const BeakNullValue(),
  final BeakValue value => value,
  final bool value => BeakBoolValue(value),
  final int value => BeakIntValue(value),
  final double value => BeakDoubleValue(value),
  final String value => BeakStringValue(value),
  final DateTime value => BeakDateTimeValue(value),
  final List<Object?> values => BeakListValue([
    for (final value in values) BeakValue.of(value),
  ]),
  _ => throw BeakConfigurationException(
    'BeakValue does not support ${raw.runtimeType} values (got $raw).',
  ),
};
```

Two getters matter. `raw` unwraps back to plain Dart (a `BeakDateTimeValue`
returns a `DateTime`). `toJson` produces the wire form, where a timestamp becomes
a tagged object so decoding never confuses it with a plain string.

```dart title="packages/beak_core/lib/src/query/beak_value.dart"
@override
Object? get raw => value;

@override
Object? toJson() => {'type': 'dateTime', 'value': value.toIso8601String()};
```

A `BeakRecord` is a row: `BeakValue`s keyed by column key, plus any eager-loaded
relations keyed by relation key. It round-trips to a plain ORM row
(`fromRow`/`toRow`) and to JSON (`fromJson`/`toJson`), and you read a value back
out by column key with `operator []`.

```dart title="packages/beak_core/lib/src/query/beak_record.dart"
// Wrap a raw ORM row, then read typed values back out by column key.
final record = BeakRecord.fromRow({
  'id': 7,
  'title': 'Hello',
  'published': true,
});

final BeakValue? title = record['title']; // BeakStringValue('Hello')
final Object? id = record['id']?.raw;      // 7
```

That is the same `BeakRecord` a data source returns, a form controller edits, and
`renderBeakCell` reads. No `dynamic` in the middle, and no stringly-typed map to
guess the shape of. A record never lazy-loads either: a relation is present only
if the query asked for it.

## Continue reading

- [The four layers](the-four-layers.md) where exceptions are thrown and caught on
  each side.
- [How data flows](how-data-flows.md) the serializable query spec that carries
  `BeakValue`s over the wire.
- [The type-safety promise](the-type-safety-promise.md) why users never touch
  `dynamic` or a raw map.
- [Exceptions](../reference/exceptions.md) the full reference for every variant.
- [Middleware](../backend/middleware.md) the backend boundary that maps the
  exception family to HTTP status and JSON.
