# Phase 02 — beak_core: column system + validation rules

## Objective
Build Beak's central abstraction: the typed, `const`, "define-once/render-everywhere"
column system plus the validation-rule classes. This is the heart of the framework.

## Prerequisites
- Phase 01 `✅ DONE`.

## Files created (in `packages/beak_core/lib/src/`)
- `columns/beak_column.dart` (sealed base)
- `columns/*.dart` (one file per concrete column type)
- `columns/beak_render_config.dart`
- `rules/beak_rule.dart` (sealed base) + `rules/*.dart`
- barrel updates

## Public API to implement (contract)

### Sealed base
```dart
sealed class BeakColumn {
  const BeakColumn({
    required this.key,               // storage/DB column name (snake_case), never exposed as a magic string to users
    required this.label,
    this.visibleOn = const {BeakContext.table, BeakContext.form, BeakContext.detail},
    this.sortable = false,
    this.searchable = false,
    this.filterable = false,
    this.rules = const [],
  });
  final String key;
  final String label;
  final Set<BeakContext> visibleOn;
  final bool sortable;
  final bool searchable;
  final bool filterable;
  final List<BeakRule> rules;

  /// The rendering hint for a given context (frontend maps to obers_ui).
  BeakRenderIntent intentFor(BeakContext context);

  /// The Dart type this column's value takes (for typed form/data access).
  Type get valueType;
}
```

### Concrete column types (each a `final class` extending `BeakColumn`, `const` ctor)
- `BeakStringColumn` (`placeholder`, `maxLength?`) → intent `text`; valueType `String`.
- `BeakTextColumn` (multiline) → `text`/detail full; `String`.
- `BeakIntColumn` (`min?`, `max?`) → `number`; `int`.
- `BeakDecimalColumn` (`precision`, `prefix?`, `suffix?`) → `currency`/`number`; `double`.
- `BeakBoolColumn` (`trueLabel?`, `falseLabel?`) → `boolean`; `bool`.
- `BeakEnumColumn<T extends Enum>` (`values: List<T>`, `defaultValue?`,
  `badgeColors: Map<T, BeakColor>`, `labelOf: String Function(T)?`) → `badge`; `T`.
- `BeakDateTimeColumn` (`format: BeakDateFormat`) → `date`/`relativeDate`; `DateTime`.
  Add `enum BeakDateFormat { standard, relative, dateOnly, timeOnly, iso }` and a
  `.withFormat(BeakDateFormat)` returning a copy.
- `BeakImageColumn` (`storagePath`, `maxSizeInBytes?`, `allowedTypes: List<BeakFileType>`,
  `maxDimensions: BeakDimensions?`, `aspectRatio?`, `thumbnail: BeakDimensions?`,
  `transforms: List<BeakImageTransform>`) → table `thumbnail`, form `image`, detail
  `image`; valueType `String` (the stored key/url). NOTE: `BeakImageTransform`,
  `BeakDimensions`, `BeakFileType` are DEFINED in Phase 05 (storage); in this phase
  declare the image column against forward-declared types by putting those value objects
  in a small `columns/file_support.dart` now and having Phase 05 build the driver layer
  on top. Keep them pure data classes here.
- `BeakFileColumn` (`storagePath`, `maxSizeInBytes?`, `allowedTypes`) → `custom`(file);
  `String`.
- `BeakJsonColumn` → `json`; typed as a sealed `BeakJson` value (NOT `Map<String,dynamic>`
  — model JSON as a `sealed class BeakJson` tree: `BeakJsonObject`, `BeakJsonArray`,
  `BeakJsonString`, `BeakJsonNumber`, `BeakJsonBool`, `BeakJsonNull`, with encode/decode).
- `BeakColorColumn` → `color`; `String` (hex).
- `BeakRichTextColumn` → `richText`; `String`.
- `BeakCustomColumn` — carries a `String label` + an opaque `BeakColumnTag` id (the actual
  builder lives in `beak_frontend`); intent `custom`. This is the escape hatch.

### Validation rules
```dart
sealed class BeakRule {
  const BeakRule();
  /// Returns null when valid, else an error message. Value is typed via generics at the
  /// call site; core validates against Object? but concrete rules pattern-match types.
  String? validate(Object? value);
  /// Machine-readable identity for serialization to the frontend/back.
  String get id;
}
```
Concrete: `BeakRequired`, `BeakMaxLength(int)`, `BeakMinLength(int)`, `BeakMin(num)`,
`BeakMax(num)`, `BeakEmail`, `BeakUrl`, `BeakPattern(String regex, {String? message})`,
`BeakInList<T>(List<T>)`, `BeakMaxFileSize(int bytes)`, `BeakAllowedFileTypes(List<
BeakFileType>)`. Each is `const`, has a stable `id`, and produces a clear message.

## Tests to write FIRST
- One test file per column type: `intentFor` returns the right intent per context;
  `valueType` is correct; `visibleOn` defaults and overrides behave; copy helpers
  (`withFormat`) don't mutate the original (immutability).
- `BeakEnumColumn` generic behavior with a sample enum; badge color lookup.
- `beak_json_test.dart` — round-trip encode/decode of the sealed JSON tree; no `dynamic`.
- One test per rule: valid + invalid + boundary; `id` stability (iterate all rule ids so
  adding a rule without a test breaks the suite).
- A `columns_registry_test.dart` verifying `BeakColumn` is sealed (exhaustive `switch`
  over all subtypes compiles — a helper function must `switch` every variant).

## Implementation notes / constraints
- All columns `const`-constructible so users can declare them as `static const`.
- No Flutter. No worm. `BeakColumn` stays UI-agnostic (intents only).
- The exhaustive-`switch` test is the guard that keeps every consumer (frontend renderer,
  backend mapper) forced to handle new column types.

## Definition of Done (gate)
- [ ] analyze 0 issues · all tests green · `beak_core` coverage 100% · format clean.
- [ ] Exhaustive `switch` over `BeakColumn` and over `BeakRule` compiles and is tested.
- [ ] STATE.md row 02 → `✅ DONE` + SHA.

## Commit
`feat(beak_core): add typed column system and validation rules`
