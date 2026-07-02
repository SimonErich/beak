---
title: Validation
description: Declare per-field rules that run automatically on save, and browse the full catalog of built-in validation rules.
---

Worm validates models declaratively: you attach rules to fields, and every `save()` runs them before anything reaches the database. This page builds on [saving and updating](./saving-and-updating.md).

## Declaring rules

Override the `rules` getter on your model. Keys are typed `Field` references; values are lists of `ValidationRule` instances.

```dart title="lib/models/user.dart"
@Table(name: 'users')
final class User extends Model {
  // ... constructor, id, toRow ...

  @override
  Map<Field<Object?>, List<ValidationRule>> get rules => {
        User$.email: const [Required(), Email()],
        User$.name: const [Required(), MinLength(2)],
      };
}
```

`User$.email` is a generated companion constant (see [code generation](./code-generation.md)). Hand-written models construct the keys directly:

```dart
@override
Map<Field<Object?>, List<ValidationRule>> get rules => {
      const Field<Object?>('name'): const [Required(), MinLength(2)],
    };
```

Each rule validates the attribute stored under the field's column name. The default `rules` is empty, and models with empty rules skip validation entirely, so unvalidated models pay no cost.

:::note[The map cannot be const]
`Field` overrides `==`, and Dart forbids such types as const map keys. Keep the getter body a plain (non-const) map literal; the keys and rule lists themselves can be const.
:::

## When rules run

Validation runs inside `save()`, between the `beforeValidate` and `afterValidate` lifecycle events (see [the save lifecycle](./lifecycle-hooks-and-observers.md#the-save-lifecycle)):

- **Insert path** (model not yet persisted): every field in `rules` is validated.
- **Update path** (model exists): `updateRules` applies instead, and only for **dirty fields**. An unchanged column never blocks an unrelated edit, even if its current value would fail its rules.

Any failure throws `ValidationException` and cancels the write. Nothing is inserted or updated, `afterValidate` and all later hooks are skipped, and the model's `exists` flag is unchanged.

Two distinct signals come out of `save()`: validation failure **throws**, while hook cancellation makes `save()` **return `false`**. Handle them separately.

## Update rules

`updateRules` defaults to `rules`. Override it to run a different set on edits, for example to add a uniqueness check that excludes the current row:

```dart
@override
Map<Field<Object?>, List<ValidationRule>> get updateRules => {
      User$.email: [
        const Required(),
        const Email(),
        Unique(
          adapter: Worm.adapter(),
          table: 'users',
          column: 'email',
          exceptId: id,
        ),
      ],
    };
```

Because the update path only validates dirty fields, this `Unique` check runs only when the email actually changed.

## The built-in rules

Worm ships 16 built-in rules. All are `const`, and every rule accepts an optional `message` parameter that replaces the default error text.

One doctrine governs them all: **every rule except `Required` treats `null` as valid.** Fields are optional unless you say otherwise. To make a field mandatory, chain `Required()` first.

| Rule | Constructor | Valid when | Notes |
| --- | --- | --- | --- |
| `Required` | `Required({message})` | Value is non-null and not an empty `String`, `Iterable`, or `Map` | The only rule that rejects `null` |
| `Email` | `Email({message})` | `String` matching a pragmatic, RFC 5321-inspired email pattern | Non-strings fail |
| `Min` | `Min(num bound, {message})` | `num` greater than or equal to `bound` | Inclusive; non-numeric values fail |
| `Max` | `Max(num bound, {message})` | `num` less than or equal to `bound` | Inclusive; non-numeric values fail |
| `MinLength` | `MinLength(int length, {message})` | `String` or `Iterable` with length at least `length` | Inclusive; asserts `length >= 0`; other types fail |
| `MaxLength` | `MaxLength(int length, {message})` | `String` or `Iterable` with length at most `length` | Inclusive; asserts `length >= 0`; other types fail |
| `In` | `In(List<Object?> allowed, {message})` | Value contained in `allowed` | Whitelist membership |
| `NotIn` | `NotIn(List<Object?> forbidden, {message})` | Value not contained in `forbidden` | Blacklist exclusion |
| `Regex` | `Regex(RegExp pattern, {message})` | `String` matching `pattern` | Non-strings fail |
| `Url` | `Url({message})` | `String` parsing to an absolute URL with scheme and host | `mailto:`, opaque URIs, and relative paths fail |
| `Uuid` | `Uuid({message})` | Canonical UUID string, versions 1 through 8, in the 8-4-4-4-12 hex layout | Non-strings fail |
| `DateRule` | `DateRule({message})` | A `DateTime`, or a `String` that `DateTime.tryParse` accepts | Rule id is `date` |
| `After` | `After(DateTime bound, {message})` | Date strictly after `bound` | Strict: equal timestamps fail; ISO-8601 strings are coerced |
| `Before` | `Before(DateTime bound, {message})` | Date strictly before `bound` | Strict: equal timestamps fail; ISO-8601 strings are coerced |
| `Confirmed` | `Confirmed(Object? other, {message})` | Value equals `other` | Password-confirmation style equality match |
| `Unique` | `Unique({required adapter, required table, required column, exceptId, primaryKey = 'id', message})` | No existing row has the same value in `table.column` | The only async built-in; see below |

Note the bounds convention: `Min`, `Max`, `MinLength`, and `MaxLength` are inclusive, while `After` and `Before` are strict.

Every rule also exposes a stable `name` id used in diagnostics: `required`, `email`, `min`, `max`, `minLength`, `maxLength`, `in`, `notIn`, `regex`, `url`, `uuid`, `date`, `after`, `before`, `confirmed`, and `unique`.

## The async rule: Unique

`Unique` is the only built-in rule that touches the database. It runs a `count` query for rows where `column` equals the value. When `exceptId` is set, the row whose `primaryKey` matches `exceptId` is excluded, so an update never collides with the row being updated.

```dart
final rule = Unique(
  adapter: Worm.adapter(),
  table: 'users',
  column: 'email',
  exceptId: user.id, // on updates: ignore this row
);
```

The default failure message reads `The email has already been taken.` (with your column name substituted).

:::caution[Unique is a pre-check, not a lock]
Two concurrent saves can both pass the check before either row lands. Keep a unique index on the column as the database-level backstop, and translate the driver error into the same JSON-API shape:

```dart
try {
  await user.save();
} on UniqueConstraintException catch (e) {
  throw ValidationException.fromUniqueConstraint(e);
}
```

:::

## Handling failures

`save()` throws a `ValidationException` when any rule fails. Its `errors` getter always yields a `Map<String, List<String>>` keyed by field name, ready for a JSON API response:

```dart
try {
  await user.save();
} on ValidationException catch (e) {
  print(e.errors);
  // {email: [Must be a valid email address.], name: [This field is required.]}
}
```

The engine runs **every rule for every field**, with no short-circuiting, so `errors` is always the complete picture, not just the first failure. The returned map and its inner lists are unmodifiable, so it is safe to hand to response serializers. Exceptions built from the single-field constructor expose the same shape: `{field: [message]}`.

## Standalone Validator

The same engine works outside models. `Validator` takes rules keyed by plain field-name strings:

```dart
const validator = Validator({
  'email': [Required(), Email()],
  'name': [Required(), MinLength(2)],
});

final errors = await validator.validate({'name': '', 'email': 'nope'});
// {email: [Must be a valid email address.],
//  name: [This field is required., Must be at least 2 characters long.]}

await validator.validateOrThrow({'name': 'Ada', 'email': 'ada@example.com'});
// passes; throws ValidationException.fromMap on failure
```

Use it for request payloads, config maps, or anything else that never becomes a model.

`validateSync` is the synchronous variant for rule sets you know contain no async rules. If any rule returns a `Future` (which `Unique` always does), it throws a `StateError` telling you to fall back to `validate`.

For objects implementing the `Validatable` interface (rules, values, primary key, and table name), the top-level `validateModel(validatable)` helper composes a `Validator` and throws on failure.

## Gotchas

- Every rule except `Required` passes `null`. A lone `Email()` on a null field validates fine; chain `Required()` first to make it mandatory.
- `Min`/`Max`/`MinLength`/`MaxLength` bounds are inclusive; `After`/`Before` are strict, so equal timestamps fail.
- Type mismatches fail rather than pass: a `String` under `Max`, or an `int` under `MinLength`, produces the rule's error message.
- The update path validates dirty fields only. A stored value that predates a new rule is not re-checked until that field changes.
- The `rules` map literal cannot be `const` because `Field` overrides `==`; the keys and rule lists can be.
- `validateSync` throws `StateError` on any async rule; `Unique` is always async.
- Validation failure throws `ValidationException`; hook cancellation returns `false` from `save()`. They are different signals.
- `Worm.withoutEvents` mutes lifecycle hooks but never validation. There is no switch that skips rules on `save()`.
- Bulk query-builder writes (`update`/`delete` on a query) bypass validation entirely; see [advanced queries](../queries/advanced-queries.md).

## API summary

### Built-in rules

| Symbol | Signature | Purpose |
| --- | --- | --- |
| `Required` | `const Required({String message})` | Rejects null and empty `String`/`Iterable`/`Map` |
| `Email` | `const Email({String message})` | Well-formed email address string |
| `Min` | `const Min(num bound, {String? message})` | Numeric minimum, inclusive |
| `Max` | `const Max(num bound, {String? message})` | Numeric maximum, inclusive |
| `MinLength` | `const MinLength(int length, {String? message})` | Minimum `String`/`Iterable` length, inclusive |
| `MaxLength` | `const MaxLength(int length, {String? message})` | Maximum `String`/`Iterable` length, inclusive |
| `In` | `const In(List<Object?> allowed, {String? message})` | Value must be in the whitelist |
| `NotIn` | `const NotIn(List<Object?> forbidden, {String? message})` | Value must not be in the blacklist |
| `Regex` | `const Regex(RegExp pattern, {String? message})` | String must match the pattern |
| `Url` | `const Url({String message})` | Absolute URL with scheme and host |
| `Uuid` | `const Uuid({String message})` | Canonical UUID, versions 1 through 8 |
| `DateRule` | `const DateRule({String message})` | `DateTime` or ISO-8601 parseable string |
| `After` | `const After(DateTime bound, {String? message})` | Date strictly after the bound |
| `Before` | `const Before(DateTime bound, {String? message})` | Date strictly before the bound |
| `Confirmed` | `const Confirmed(Object? other, {String? message})` | Value must equal the confirmation value |
| `Unique` | `const Unique({required DatabaseAdapter adapter, required String table, required String column, Object? exceptId, String primaryKey = 'id', String? message})` | Async: no other row may hold the same value |

### Engine and model surface

| Symbol | Signature | Purpose |
| --- | --- | --- |
| `ValidationRule` | `abstract; String get name; FutureOr<ValidationResult> validate(Object? value)` | Base contract every rule implements |
| `ValidationResult` | `const ValidationResult.valid()` / `const ValidationResult.invalid(String message)`; `isValid`, `isInvalid`, `message` | Outcome of one rule against one value |
| `Validator` | `const Validator(Map<String, List<ValidationRule>> rules)`; `validate(values)`, `validateOrThrow(values)`, `validateSync(values)` | Standalone engine keyed by field-name strings |
| `Validatable` | `validationRules()`, `validationValues()`, `primaryKeyValue`, `tableName` | Interface for model-level validation participants |
| `validateModel` | `Future<void> validateModel(Validatable validatable)` | Builds a `Validator` from a `Validatable` and throws on failure |
| `Model.rules` | `Map<Field<Object?>, List<ValidationRule>> get rules` | Rules auto-run on save; defaults to empty |
| `Model.updateRules` | `Map<Field<Object?>, List<ValidationRule>> get updateRules` | Update-path rules; defaults to `rules`; dirty fields only |
| `ValidationException` | `const ValidationException({field, rule, message, value, model})`; `ValidationException.fromMap(errors)`; `ValidationException.fromUniqueConstraint(violation)`; `errors` | Thrown on failure; unmodifiable JSON-API shaped `errors` map |

## Continue reading

- [Saving and updating](./saving-and-updating.md): where the dirty tracking that gates update validation comes from.
- [Lifecycle hooks and observers](./lifecycle-hooks-and-observers.md): where validation sits in the save pipeline, and why hooks cancel differently.
- [Security](../guides/security.md): validation as a boundary defense, together with strict mass assignment.
- [Exceptions](../reference/exceptions.md): the full `ValidationException` reference and its siblings.
