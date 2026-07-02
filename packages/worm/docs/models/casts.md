---
title: Casts
description: Convert field values between Dart types and stored primitives with worm's 14 built-in casts.
---

Casts translate a field's value between its Dart type and the primitive form your database adapter stores. This page catalogs every built-in cast and shows how to wire them into a model. It builds on [defining models](./defining-models.md).

## Where casts run

Casts sit on the storage boundary, not the JSON boundary:

- **Decode on read.** When Active Record hydrates a model from an adapter row, it runs `castManager.decodeAll(row)` and hands you domain values.
- **Encode on write.** Before an insert or update, it runs `castManager.encodeAll(values)` and hands the adapter storable primitives.
- **Never on serialization.** `toMap()` and `toJson()` read live attribute values. Casts are not re-applied there. See [serialization](./serialization.md).

Fields without a registered cast pass through both directions untouched.

## Wiring casts to a model

Override the `castManager` getter. Keys are column names as they appear in the row:

```dart title="user.dart"
enum Role { admin, editor, viewer }

final class User extends Model {
  // ... constructor, id, toRow ...

  @override
  CastManager get castManager => CastManager(<String, AttributeCast>{
    'created_at': const DateTimeCast(),
    'balance': const DecimalCast(),
    'role': const EnumCast<Role>(Role.values),
    'settings': const JsonMapCast(),
  });
}
```

The base `Model.castManager` returns an empty manager, so models without casts pay no per-call cost.

You can also use any cast directly. Every built-in cast is `const` and symmetric:

```dart
const cast = DateTimeCast();
final encoded = cast.encode(DateTime.utc(2026, 5, 22, 12, 30, 45));
// '2026-05-22T12:30:45.000Z'
final decoded = cast.decode(encoded); // DateTime (UTC)
cast.decode('not-a-date');            // throws CastException
```

## Decode is lenient, encode is strict

Every cast accepts several raw forms on decode, because databases surface values in different shapes (SQLite hands you ints for booleans, Mongo may hand you strings for counts). Encode mostly accepts only the domain type, because a wrong type on the write path is a bug in your code, not a storage quirk.

```dart
const cast = BoolCast();
cast.decode('true'); // true
cast.encode('true'); // throws CastException: encode wants a bool
```

Unusable input throws `CastException` in both directions. The exception carries `field`, `fromType`, and `toType` so you can see exactly which conversion failed.

## The built-in casts

All 14 built-in casts, verified against `lib/src/cast/casts/`:

| Cast | `name` | Dart type | Stored form | Decode also accepts |
| --- | --- | --- | --- | --- |
| `IntCast` | `int` | `int` | `int` | numeric `String`, whole `double` |
| `DoubleCast` | `double` | `double` | `double` (encode converts `int`) | `int`, numeric `String` |
| `BoolCast` | `bool` | `bool` | `bool` | `int` (0 is false, nonzero is true), `'true'`/`'t'`/`'1'`, `'false'`/`'f'`/`'0'` (case-insensitive) |
| `StringCast` | `string` | `String` | `String` | `num`, `bool`, `BigInt`, `Uri` via `toString()` |
| `DateTimeCast` | `datetime` | `DateTime` (UTC) | ISO-8601 `String` | epoch-milliseconds `int` (as UTC), parseable `String`, `DateTime` |
| `DurationCast` | `duration` | `Duration` | `int` milliseconds | `int`, `BigInt`, whole `double`, numeric `String` |
| `BigIntCast` | `bigint` | `BigInt` | canonical decimal `String` | `int`, parseable `String` |
| `DecimalCast` | `decimal` | `Decimal` | canonical `String` (`.value`) | `String`, `int`, `Decimal` |
| `EnumCast<T>` | `enum` | `T extends Enum` | `value.name` `String` | name `String`, index `int`, `T` |
| `UriCast` | `uri` | `Uri` | `uri.toString()` | parseable `String` |
| `JsonMapCast` | `json-map` | `Map<String, Object?>` | JSON-encoded `String` | already-decoded `Map` (keys must be `String`) |
| `JsonListCast` | `json-list` | `List<Object?>` | JSON-encoded `String` | already-decoded `List` |
| `CustomCast<T>` | `custom` (configurable) | `T` | whatever your `toDb` returns | whatever your `fromDb` handles |
| `EncryptedCast` | `encrypted` | `String` plaintext | subclass-defined ciphertext | whatever your `decryptString` handles |

Every built-in cast except `CustomCast` takes an optional `field` parameter (default `'value'`, `'duration'` for `DurationCast`) that is only used for error reporting in `CastException`. `CustomCast` reports its `name` instead.

## Dates normalize to UTC

`DateTimeCast` calls `toUtc()` on both decode and encode. A local-time value round-trips as the same instant, but it comes back as UTC. Epoch integers are interpreted as milliseconds since epoch, in UTC.

## Decimal: lossless numbers

`Decimal` is an arbitrary-precision decimal backed by its canonical string, so `0.10000000000000001` survives a round trip without floating-point drift. The accepted grammar is `sign? digits ('.' digits)? exponent?`.

```dart
final price = Decimal.parse('19.99');   // throws FormatException on bad input
final maybe = Decimal.tryParse('oops'); // null
final whole = Decimal.fromInt(42);
Decimal.zero;                            // const zero
price.value;                             // '19.99', the canonical string
```

Two things to know:

- **Equality is string-based.** `Decimal.parse('1.10') != Decimal.parse('1.1')`. Canonicalization only strips a leading `+`.
- **`compareTo` parses through `double`.** Ordering can lose precision beyond roughly 15 to 17 significant digits.

## EnumCast

`EnumCast` needs the enum's `values` list, because Dart cannot enumerate an enum from a type parameter alone:

```dart
const roleCast = EnumCast<Role>(Role.values);
roleCast.encode(Role.editor); // 'editor'
roleCast.decode('editor');    // Role.editor
roleCast.decode(0);           // Role.admin (index fallback)
```

Decode matches by `name` first, then falls back to the integer index. The index fallback means reordering enum members silently changes the meaning of stored integers. Store names, not indexes, whenever you control the column.

## CustomCast

For one-off conversions that don't warrant a class, build a cast from closures. Here is a `Duration` stored as whole seconds instead of the `DurationCast` default of milliseconds:

```dart
final secondsCast = CustomCast<Duration>(
  fromDb: (raw) => Duration(seconds: raw! as int),
  toDb: (duration) => duration.inSeconds,
  name: 'duration-seconds',
);
```

`null` short-circuits in both directions, so your closures only ever see non-null values. Encode throws `CastException` when the value is not a `T`. Register it in a `castManager` override; `CustomCast` takes constructor arguments, so it cannot be used with `@CastAs`.

## EncryptedCast: bring your own crypto

`EncryptedCast` is an abstract skeleton. Worm ships **no cipher, no key handling, and no encryption-at-rest**. The base class only provides:

- `null` passthrough in both directions,
- an encode type check (`String` plaintext only, otherwise `CastException`),
- wrapping of any `FormatException` your `decryptString` throws into a `CastException`.

Everything else, including the ciphertext format (nonce and tag embedding, encoding), is your subclass's contract:

```dart title="my_encrypted_cast.dart"
final class MyEncryptedCast extends EncryptedCast {
  const MyEncryptedCast();

  @override
  Object encryptString(String plaintext) {
    // Call your crypto library here (AES-GCM, libsodium, a KMS).
    // Return the ciphertext in the exact shape decryptString expects,
    // for example a base64 string that embeds nonce and auth tag.
    throw UnimplementedError('bring your own cipher');
  }

  @override
  String decryptString(Object ciphertext) {
    // Reverse encryptString. Throw FormatException on malformed input;
    // the base class wraps it in a CastException.
    throw UnimplementedError('bring your own cipher');
  }
}
```

:::caution
Use a maintained cryptography library and keep key material out of your source tree. Encrypted columns cannot be filtered by plaintext: the database only ever sees ciphertext. See [security](../guides/security.md).
:::

## The @CastAs annotation

`@CastAs(SomeCast)` exists in `package:worm/annotations.dart`, but its wiring is experimental. The generator emits it into an opt-in `_$YourModelAnnotations` mixin that you must mix in manually, and it renders the cast as `const SomeCast()`, so the cast needs a const no-argument constructor. `EnumCast` and `CustomCast` take constructor arguments and don't qualify.

The recommended mechanism is the `castManager` override shown above. It is explicit, works for every cast, and needs no code generation. See [code generation](./code-generation.md) for what the mixin contains.

## Gotchas

- Encode throws where decode succeeds. `BoolCast().encode('true')` throws even though `decode('true')` returns `true`.
- `DateTimeCast` always returns UTC. Local-time values come back as the same instant in UTC. Epoch integers are milliseconds, not seconds.
- `Decimal.parse` throws `FormatException`, not `CastException`. Only `DecimalCast` wraps failures in `CastException`.
- `Decimal` equality compares canonical strings: `'1.10'` and `'1.1'` are not equal. `compareTo` goes through `double` and can lose precision on very long numbers.
- `EnumCast` decodes integer indexes. Reordering enum members changes what stored integers mean.
- `JsonMapCast` and `JsonListCast` accept an already-encoded JSON `String` on encode, but they validate it with `jsonDecode` first. Invalid JSON throws a raw `FormatException` there, not a `CastException`.
- `JsonMapCast` throws `CastException` when a decoded map has a non-`String` key.
- Casts do not run on query predicates. When you filter on a casted column, compare against the stored form (for example the ISO-8601 string for a `datetime` column, or `Decimal.value` for a `decimal` column).
- `CastManager` treats unregistered fields as pass-through. A typo in the field key silently skips the cast.
- `@CastAs` only takes effect through the opt-in generated mixin and requires a const no-argument cast constructor.

## API summary

### Core types

| Symbol | Signature sketch | Description |
| --- | --- | --- |
| `AttributeCast` | `abstract class; String get name; Object? decode(Object? raw); Object? encode(Object? value); castError({field, source, reason, targetType})` | Base contract. `null` passes through; bad input throws `CastException`. |
| `CastManager` | `CastManager([Map<String, AttributeCast>? casts])` | Maps field names to casts. Unregistered fields pass through. |
| `CastManager.hasCast` | `bool hasCast(String field)` | Whether a cast is registered for `field`. |
| `CastManager.registeredFields` | `Iterable<String> get registeredFields` | Field names with a registered cast. |
| `CastManager.register` / `unregister` | `void register(String field, AttributeCast cast)` / `void unregister(String field)` | Add or remove a cast at runtime. |
| `CastManager.decodeAll` / `encodeAll` | `Map<String, Object?> decodeAll(Map row)` / `encodeAll(Map values)` | Convert a whole row or value map. |
| `CastManager.decodeOne` / `encodeOne` | `Object? decodeOne(String field, Object? raw)` / `encodeOne(String field, Object? value)` | Convert a single value. |
| `Decimal` | `final class implements Comparable<Decimal>; Decimal.parse(String); static Decimal? tryParse(String); Decimal.fromInt(int); static const zero; String get value` | Lossless decimal backed by its canonical string. `parse` throws `FormatException`. |
| `CastException` | `CastException({field, fromType, toType, message, model?})` | Thrown by casts in both directions on unusable input. |

### Built-in casts

| Cast | Constructor | Description |
| --- | --- | --- |
| `IntCast` | `const IntCast({String field = 'value'})` | `int` stored as `int`. |
| `DoubleCast` | `const DoubleCast({String field = 'value'})` | `double` stored as `double`; encode converts `int`. |
| `BoolCast` | `const BoolCast({String field = 'value'})` | `bool` stored as `bool`; decodes ints and truthy strings. |
| `StringCast` | `const StringCast({String field = 'value'})` | `String` stored as `String`; decodes primitives via `toString()`. |
| `DateTimeCast` | `const DateTimeCast({String field = 'value'})` | UTC `DateTime` stored as ISO-8601 string; decodes epoch ms. |
| `DurationCast` | `const DurationCast({String field = 'duration'})` | `Duration` stored as `int` milliseconds. |
| `BigIntCast` | `const BigIntCast({String field = 'value'})` | `BigInt` stored as decimal string. |
| `DecimalCast` | `const DecimalCast({String field = 'value'})` | `Decimal` stored as its canonical string. |
| `EnumCast<T extends Enum>` | `const EnumCast(List<T> values, {String field = 'value'})` | Enum stored as its `name`; decodes by name, then index. |
| `UriCast` | `const UriCast({String field = 'value'})` | `Uri` stored as its string form. |
| `JsonMapCast` | `const JsonMapCast({String field = 'value'})` | `Map<String, Object?>` stored as a JSON string. |
| `JsonListCast` | `const JsonListCast({String field = 'value'})` | `List<Object?>` stored as a JSON string. |
| `CustomCast<T>` | `const CustomCast({required T Function(Object?) fromDb, required Object? Function(T) toDb, String name = 'custom'})` | Inline closure-based cast for one-off conversions. |
| `EncryptedCast` | `abstract; const EncryptedCast({String field = 'value'}); Object encryptString(String); String decryptString(Object)` | Bring-your-own-crypto skeleton; subclass supplies the cipher. |

## Continue reading

- [Serialization](./serialization.md): the other boundary; casts do not run when you render JSON.
- [Security](../guides/security.md): where encrypted columns fit in a wider threat model.
- [Exceptions](../reference/exceptions.md): `CastException` in the full exception hierarchy.
- [Code generation](./code-generation.md): what the opt-in annotations mixin actually emits.
