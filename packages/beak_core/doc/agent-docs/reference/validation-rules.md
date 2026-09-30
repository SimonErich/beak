# Validation rules

> Every column rule, record rule and async rule with its constructor, what it checks and the exact message it emits on client and server.

Beak validates in three layers, all declared on the schema: column rules on one value, record rules across fields and related rows, and async rules that ask the database. This page lists every rule with its constructor, what it checks and the message it produces.

## Import

```dart
import 'package:beak/beak.dart';
```

Rules live in `beak_core`, so the client and the server run the same code. `BeakValidation`, `BeakAsyncValidation` and `BeakValidationReport` come from the same import.

## Summary

| Layer | Declared with | Sees | Runs on the client | Runs on the server |
| --- | --- | --- | --- | --- |
| [Column rules](#column-rules) | `@Column(rules: [...])` | One value | Yes, as form validators with the rule's own message | Yes, on every write |
| [Kind checks](#checks-a-column-kind-makes-itself) | The column type | One value | Yes | Yes |
| [Record rules](#record-rules) | `static List<BeakRecordRule> get validationRules` | The whole candidate record and its staged rows | Yes, on the draft | Yes, on the final state of the write |
| [Async rules](#async-rules) | `validationRules`, `unique: true`, belongs-to fields | The database | As a debounced preflight to `POST /api/{table}/validate` | Yes, authoritative |

| Rule | Kind | One line |
| --- | --- | --- |
| `BeakRequired` | column | Present, and non-empty for text and collections |
| `BeakMinLength`, `BeakMaxLength` | column | Text length bounds |
| `BeakMin`, `BeakMax` | column | Numeric bounds, exact for `BeakDecimal` |
| `BeakEmail`, `BeakUrl`, `BeakPattern` | column | Text format |
| `BeakInList<T>` | column | One of a fixed set |
| `BeakFutureDate` | column | After now |
| `BeakMaxFileSize`, `BeakAllowedFileTypes` | column, uploads | Size and type of an upload |
| `BeakRequiredIf` | record | Required when a condition holds |
| `BeakSameAs` | record | Two fields agree |
| `BeakBeforeField`, `BeakAfterField` | record | One ordered value precedes or follows another |
| `BeakCount` | record | Size of a collection |
| `BeakDistinct` | record | No repeated value among related rows |
| `BeakSum` | record | Bounds on a total across related rows |
| `BeakUnique` | async | Value unused, optionally within a scope |
| `BeakExists` | async | Value names an eligible row elsewhere |

## Column rules

`BeakRule` is sealed, so client and server switch over the twelve rules exhaustively. A rule pattern-matches the runtime type of the value and reports valid when it does not apply, so rules compose freely and presence is `BeakRequired`'s job alone.

```dart
@immutable
sealed class BeakRule {
  const BeakRule();

  /// Stable machine-readable identity for serialization to either side of
  /// the wire.
  String get id;

  /// Returns `null` when [value] is valid, else a human-readable message.
  String? validate(Object? value);
}

```

| Member | Meaning |
| --- | --- |
| `id` | Stable machine-readable identity, `required`, `min_length` and so on |
| `validate(Object? value)` | `null` when valid, else the message |

Constructors:

```dart
const BeakRequired({this.allowEmpty = false});

/// Whether a present empty string or collection is valid. Null still fails.
final bool allowEmpty;

const BeakMinLength(this.minLength);

/// Lowest accepted number of characters.
final int minLength;

const BeakMaxLength(this.maxLength);

/// Highest accepted number of characters.
final int maxLength;

const BeakMin(this.min);

/// Lowest accepted value (inclusive).
final num min;

const BeakMax(this.max);

/// Highest accepted value (inclusive).
final num max;

const BeakEmail();

const BeakUrl();

const BeakPattern(this.regex, {this.message});

/// Regular-expression source the value must match.
final String regex;

/// Custom error message, if any.
final String? message;

const BeakInList(this.allowed);

/// The accepted values.
final List<T> allowed;

const BeakFutureDate({this.message = 'Must be in the future.'});

/// Message returned for past or present values.
final String message;

const BeakMaxFileSize(this.maxSizeInBytes);

/// Highest accepted upload size in bytes.
final int maxSizeInBytes;

const BeakAllowedFileTypes(this.allowedTypes);

/// The accepted file types; empty means unrestricted.
final List<BeakFileType> allowedTypes;
```

| Rule | `id` | Applies to | Fails when | Message |
| --- | --- | --- | --- | --- |
| `BeakRequired` | `required` | any | the value is `null`; for `String`, blank after trimming; for `Iterable`, `Map` and `BeakJsonObject`, empty. `allowEmpty: true` lets empty values through and still rejects `null`. `false` and `0` are present. | `This field is required.` |
| `BeakMinLength` | `min_length` | `String` | `length < minLength`. The empty string fails too. | `Must be at least $minLength characters.` |
| `BeakMaxLength` | `max_length` | `String` | `length > maxLength` | `Must be at most $maxLength characters.` |
| `BeakMin` | `min` | `num`, `BeakDecimal` | the value is below `min`. A `BeakDecimal` is compared without rounding either side. | `Must be at least $min.` |
| `BeakMax` | `max` | `num`, `BeakDecimal` | the value is above `max` | `Must be at most $max.` |
| `BeakEmail` | `email` | `String` | not shaped `x@y.z`: exactly one `@` with text before it, a dot in the domain with a character on each side, no whitespace, at most 254 characters | `Must be a valid email address.` |
| `BeakUrl` | `url` | `String` | not an absolute `http` or `https` URL with a host | `Must be a valid URL.` |
| `BeakPattern` | `pattern` | `String` | the unanchored `regex` does not match. Add `^` and `$` to match the whole value. | `message`, else `Must match the expected format.` |
| `BeakInList<T>` | `in_list` | any | a non-null value is not in `allowed`. `null` passes. | `Must be one of: a, b.` |
| `BeakFutureDate` | `future_date` | `DateTime`, ISO string | the instant is not strictly after now | `message`, else `Must be in the future.` |
| `BeakMaxFileSize` | `max_file_size` | `int` (size in bytes) | the size exceeds `maxSizeInBytes` | `File must be at most $maxSizeInBytes bytes.` |
| `BeakAllowedFileTypes` | `allowed_file_types` | `BeakFileType`, file name, MIME type | the type is not in `allowedTypes`. An empty list allows everything. Names match by extension, case-insensitively. | `File type must be one of: jpg, png.` |

Details that trip people up:

- `BeakMaxLength` on a `String` field also sets the column's stored `maxLength`, and `BeakMin` and `BeakMax` on an `int` field also set the form stepper's bounds. See [Annotations](annotations.md#bounds-are-rules).
- `BeakMaxFileSize` and `BeakAllowedFileTypes` have no form validator. The upload field enforces them before the file leaves the client, and the server enforces them again.
- The other ten rules run in the form through a validator that calls the rule's own `validate`, so the message is byte-identical on both sides.
- `BeakMin(0)` on a `double` field and `BeakMin(0)` on a `BeakDecimal` field both work. The bound is a `num`.

A rule is reachable from `BeakSemantic` too: `email` and `url` semantics apply `BeakEmail` and `BeakUrl` for you, and `itemRules` applies rules to each item of a primitive list, with the message prefixed `Item 2: `.

## Checks a column kind makes itself

These need no rule. They run for every column of the kind, before its `rules`.

| Column | Check | Message |
| --- | --- | --- |
| any except enum and custom | The value has the column's wire type | `Must be an integer.`, `Must be a number.`, `Must be a boolean.`, `Must be a timestamp.`, `Must be a string.` |
| `BeakEnumColumn` | The value is one of the declared names | `Must be one of: draft, published.` |
| `BeakStringColumn` | `length <= maxLength` when the column has one | `Must be at most $maxLength characters.` |
| `BeakIntColumn` | Within `min` and `max` when set | `Must be at least $min.`, `Must be at most $max.` |
| `BeakDecimalColumn` | Finite, within `precision` fraction digits, within `totalDigits - precision` integer digits | `Must be a finite number.`, `Use at most $precision decimal places.`, `Must have at most $integerDigits integer digits.` |
| `BeakJsonColumn` | The text parses as JSON | `Must be valid JSON.` |
| `BeakColorColumn` | `#` plus 3, 4, 6 or 8 hexadecimal digits | `Use a hexadecimal color such as #663399.` |
| semantic `phone` | `+` optional, 5 to 25 characters from digits, spaces, `(`, `)`, `-`, at least 5 digits | `Must be a valid phone number.` |
| semantic `slug` | Lowercase letters and digits, single hyphens | `Use lowercase letters, numbers and single hyphens.` |
| semantic `uuid` | Canonical hyphenated form | `Must be a UUID.` |
| semantic `fileSize` | A non-negative integer | `Must be a nonnegative number of bytes.` |
| semantic `calendarDate`, `time`, `duration`, `exactDecimal`, `money` | The value decodes | the decoder's `FormatException` message, for example `Expected a valid calendar date (YYYY-MM-DD).` |
| semantic `primitiveList` | `minItems`, `maxItems`, `distinctItems`, `itemRules` | `Must contain at least $min items.`, `Must contain at most $max items.`, `Items must be distinct.` |
| semantic `object` | Declared child columns validate, and no unknown property unless `allowUnknown` | `Unknown property "x".`, and child messages prefixed with the child's label |

All failing checks and rules add their message: `BeakValidation.columnErrors` returns every message for the value, deduplicated. On a create, a column with `BeakRequired` is checked even when the payload omits it. On an update, only the submitted fields are checked.

## Record rules

A record rule sees the complete candidate record: submitted values merged over the stored record, with staged related rows. It reports errors keyed by field path, so the message lands on the right input. Declare them once on the schema as a `static` getter; every form and API write of the model applies them.

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
  /// Shared delivery eligibility and complete-order validation.
  static List<BeakRecordRule> get validationRules => [
    BeakCount(OrderModel.items, min: 1),
    BeakExists(
      OrderModel.profileId,
      UserProfileConnectionModel.id,
      matching: [
        BeakFieldMatch(
          target: UserProfileConnectionModel.userId,
          source: OrderModel.customerId,
        ),
      ],
    ),
  ];
```

`BeakRecordRule` is an abstract class, not sealed, so an application can define its own.

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
abstract class BeakRecordRule {
  /// Enables constant declarations where all references are constants.
  const BeakRecordRule();

  /// Root-model fields read by this rule.
  List<BeakFieldRef<Object>> get fields;

  /// Errors indexed by typed field paths; an empty map means valid.
  Map<String, List<String>> validate(BeakRecord record);

  /// Relationships needed to evaluate this rule on authoritative state.
  List<BeakRelationLoad> get relationLoads => [
    // ...
  ];
```

| Member | Meaning |
| --- | --- |
| `fields` | The typed fields the rule reads |
| `validate(BeakRecord record)` | Errors by field path, an empty map when valid |
| `relationLoads` | Relations to load so the server evaluates the rule on authoritative state. Derived from `fields`. |

Fields are typed references (`OrderModel.items`, `InvoiceModel.dueAt`), never strings. Errors are keyed by the field's qualified key.

### Conditions

`BeakWhen` is a typed condition that `BeakRequiredIf` evaluates on the complete candidate record.

| Member | Meaning |
| --- | --- |
| `BeakWhen.equals<T>(BeakFieldRef<T> field, T? value)` | The field equals `value`, `null` included |
| `BeakWhen.present(BeakFieldRef<Object> field)` | The field is present and non-empty, by `BeakRequired` semantics |
| `BeakWhen.all(List<BeakWhen>)` | Every condition matches |
| `BeakWhen.any(List<BeakWhen>)` | At least one matches |
| `not` | The opposite condition |
| `matches(BeakRecord record)` | Evaluates the condition |
| `fields` | References the condition reads |

### The record rules

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakRequiredIf(
  this.field, {
  required this.when,
  this.message = 'This field is required.',
});
```

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakSameAs(this.field, this.other, {this.message});
```

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakBeforeField(
  this.field,
  this.other, {
  this.inclusive = false,
  this.message,
});
```

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakAfterField(
  this.field,
  this.other, {
  this.inclusive = false,
  this.message,
});
```

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakCount(this.field, {this.min, this.max})
  : assert(min == null || min >= 0),
    assert(max == null || max >= 0),
    assert(min == null || max == null || min <= max);
```

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakDistinct(this.collection, this.by, {this.ignoreNull = true});
```

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakSum(this.collection, this.value, {this.min, this.max});
```

| Rule | Parameters | Error key | Fails when | Message |
| --- | --- | --- | --- | --- |
| `BeakRequiredIf` | `field`, `when`, `message` | `field` | `when` matches and `field` is blank | `message`, default `This field is required.` |
| `BeakSameAs<T>` | `field`, `other`, `message` | `field` | the two values are not equal. Absent optionals compare as equal `null`. | `message`, else `Must match ${other.label}.` |
| `BeakBeforeField<T>` | `field`, `other`, `inclusive`, `message` | `field` | `field` is not before `other` (or equal, with `inclusive`). Either side `null` passes. | `message`, else `Must be before ${other.label}.` or `Must be on or before ${other.label}.` |
| `BeakAfterField<T>` | `field`, `other`, `inclusive`, `message` | `field` | the mirror of the above | `message`, else `Must be after ${other.label}.` or `Must be on or after ${other.label}.` |
| `BeakCount` | `field`, `min`, `max` | `field` | a collection field or to-many relation has too few or too many items. A missing collection counts as zero. | `Add at least $min items.`, `Use at most $max items.`, `Must be a collection.` |
| `BeakDistinct<T>` | `collection`, `by`, `ignoreNull` | `collection` | two related rows share the `by` value. With `ignoreNull: true`, unset values may repeat. | `Each ${by.label} must be different.` |
| `BeakSum<T>` | `collection`, `value`, `min`, `max` | `collection` | the total of `value` across the rows is out of bounds | `The total must be at least $min.`, `The total must be at most $max.`, `The total must be finite.` |

Ordered comparison (`BeakBeforeField`, `BeakAfterField`, and the `BeakSum` bounds) accepts `DateTime`, `BeakDate`, `BeakTime`, `Duration`, `BeakDecimal` and `num`, in matching pairs. Mixed types throw a `BeakConfigurationException`. `BeakSum` adds `BeakDecimal` values at the greatest scale with integer arithmetic, and reports `The aggregate amount is too large.` past `BeakDecimal.maxUnits`.

```dart title="examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart"
  /// Conditions shared by local validation and authoritative API writes.
  static List<BeakRecordRule> get validationRules => [
    BeakAfterField(
      FulfillmentPolicyModel.promotionEndsAt,
      FulfillmentPolicyModel.promotionStartsAt,
      inclusive: true,
    ),
    BeakRequiredIf(
      FulfillmentPolicyModel.promotionEndsAt,
      when: BeakWhen.present(FulfillmentPolicyModel.promotionStartsAt),
    ),
  ];
```

## Async rules

An async rule needs the database. Locally its `validate` returns an empty map. The server evaluates it through `BeakAsyncValidation` against a query that applies the same row policy as ordinary reads, and the form preflights it. `BeakAsyncRecordRule` is sealed.

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakUnique(this.field, {this.scope = const [], this.ignoreNull = true});
```

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakFieldMatch({required this.target, required this.source});
```

```dart title="packages/beak_core/lib/src/validation/beak_record_rule.dart"
const BeakExists(
  this.field,
  this.target, {
  this.where,
  this.matching = const [],
});
```

| Rule | Parameters | Fails when | Message |
| --- | --- | --- | --- |
| `BeakUnique<T>` | `field` (a `BeakScalarField`), `scope`, `ignoreNull` | another row has the same `field` value and the same value for every `scope` field. The edited record's own id is excluded. With `ignoreNull: true`, `null` skips the check. | `This value is already in use.` |
| `BeakExists<T>` | `field`, `target`, `where`, `matching` | no row of the target model has `target` equal to the candidate's `field`, matches the `where` filter and satisfies every `matching` pair. A `null` value skips the check. | `The selected value is not available.` |

`BeakFieldMatch(target:, source:)` is one dependent equality: the `target` field of the selected row must equal the `source` field of the candidate. The order example above uses it to require that the chosen profile belongs to the chosen customer.

```dart title="examples/clean_beak_config/lib/resources/products/models/product_variant.dart"
  /// A product can sell a particular attribute combination only once.
  static List<BeakRecordRule> get validationRules => [
    BeakUnique(
      ProductVariantModel.combinationKey,
      scope: [ProductVariantModel.productId],
    ),
    BeakDistinct(ProductVariantModel.attributes, VariantAttributeModel.name),
  ];
```

Two checks run without a declaration:

| Source | Check | Message |
| --- | --- | --- |
| `@Column(unique: true)` (a column not already covered by an unscoped `BeakUnique`) | Uniqueness of the value | `This value is already in use.` |
| A belongs-to foreign key with a value | The related row exists | `The selected value is not available.` |

A preflight is advice. The generated migration also creates a unique index for `unique: true` and one over the field plus its scope for each `BeakUnique`, so the database has the final word and a concurrent insert cannot slip through. Fields of a `BeakUnique` must belong to the migrated model itself, not to a related one.

## Entry points

| Symbol | Use |
| --- | --- |
| `BeakValidation().validate(model, record, {isCreate, initial, includeRecordRules})` | Column, kind and record rules on a candidate. Returns `Map<String, List<String>>`. Applies defaults first on a create. |
| `BeakValidation().columnErrors(column, value)` | Every message for one value of one column |
| `BeakValidation().applyDefaults(model, record, {includeMissing})` | Fills omitted fields from `defaultValue`, keeping explicit `null` |
| `BeakAsyncValidation().validate(model, record, {query, recordId, registry})` | Uniqueness and existence against a `BeakValidationQuery`. Returns a `BeakValidationReport`. |
| `BeakValidationReport(fieldErrors:)` | `fieldErrors` by field path, `valid`, `toJson`, `fromJson` |
| `BeakValidationRequest(table, record, recordId)` | The candidate sent to `POST /api/{table}/validate`. It carries values, never rules. |
| `BeakValidationDataSource.validateRecord(request)` | The transport interface `HttpBeakDataSource` implements |

A rejected write answers `422` with a `BeakValidationException`: `message` and `fieldErrors`, which maps a field path to its messages. Graph commits validate each node and evaluate record rules once the final state of the whole commit exists.

Real output, `BeakValidation().validate` on the quickstart `NoteModel` with an over-long title, an unknown field and a missing `pinned`:

```text
{bogus: [Unknown field "bogus" on "notes".], title: [Must be at most 255 characters.], pinned: [This field is required.]}
```

## Rules and limits

- Record rules and column rules share one error map. A field can carry messages from both.
- Record rules read the complete candidate: stored values, submitted values and staged related rows. A rule reads the declaring model's fields and, through relationship paths such as `OrderModel.items`, the rows related to it.
- `BeakEmail` accepts anything shaped `x@y.z`. It filters typos and does not check that the address can receive mail. It is not a regular expression on purpose: the server validates on its only isolate, and a backtracking pattern let one long value of dots occupy it for minutes.
- `BeakPattern` compiles the `regex` you write, and the server runs it against whatever the caller sends. A pattern with nested quantifiers such as `^(a+)+$` can backtrack for minutes on a hostile value, so keep patterns flat. Every rule of a column runs, so a `BeakMaxLength` next to it does not stop the pattern from seeing a long value.
- Messages are English strings in `beak_core`. `BeakPattern`, `BeakFutureDate`, `BeakRequiredIf`, `BeakSameAs`, `BeakBeforeField` and `BeakAfterField` take a `message:` to replace theirs.
- Rules cannot read the request principal. Authorization is a policy on the server, see [Auth and policies](../backend/auth-and-policies.md).
- `BeakValidation.columnErrors` collects every failing message, not the first, so a field can carry several.

## Source

- `packages/beak_core/lib/src/rules/beak_rule.dart` and the rule files beside it hold the twelve column rules.
- `packages/beak_core/lib/src/validation/beak_record_rule.dart` holds `BeakWhen`, the record rules and the async rules.
- `packages/beak_core/lib/src/validation/beak_validation.dart` holds `BeakValidation`.
- `packages/beak_core/lib/src/validation/beak_async_validation.dart` holds `BeakAsyncValidation`.
- `packages/beak_core/lib/src/validation/beak_validation_data_source.dart` holds the preflight transport types.
- `packages/beak_frontend/lib/src/form/beak_form_controller_builder.dart` maps rules to form validators.
- `packages/beak_backend/lib/src/service/validation_service.dart` applies the validator at the write boundary.

## Continue reading

- [Validation](../models/validation.md) shows the rules in a worked model.
- [Behavior and actions](behavior-and-actions.md) covers value lifecycles and guards that run beside the rules.
- [Exceptions](exceptions.md) lists `BeakValidationException` and the other typed errors.
- [REST API](rest-api.md) documents the preflight route and the error shape.
