# Phase 13 — beak_frontend: BeakDataForm (autoforms) + BeakDetailView

## Objective
Auto-generate create/edit forms from a model's `BeakColumn`s using
`obers_ui_autoforms` (typed, enum-keyed), including relationship pickers and image/file
upload fields wired to the backend, conditional visibility, and form sections; plus the
read-only `BeakDetailView` and an embedded relation manager.

## Prerequisites
- Phases 09 (uploads), 11 (client), 12 (renderer) `✅ DONE`.

## Files created (in `packages/beak_frontend/lib/src/form/` and `.../detail/`)
- `beak_data_form.dart`, `beak_form_controller_builder.dart`, `field_widget_mapper.dart`
- `relation_field.dart`, `upload_field.dart`, `form_view_model.dart`
- `beak_detail_view.dart`, `relation_manager.dart`
- barrel updates

## Public API to implement (contract)

### Form
```dart
class BeakDataForm extends HookWidget {
  const BeakDataForm({super.key, required this.model, required this.dataSource,
      this.recordId, this.sections, this.onSaved});   // recordId null => create
  final BeakModel model; final BeakDataSource dataSource; final Object? recordId; ...
}
```
Because `obers_ui_autoforms` is enum-keyed and Beak's columns are known at runtime (not
compile time), bridge them with a **`BeakColumnKey` value type** used as the field key
(an `OiAfController` parameterized over `BeakColumnKey`), OR generate the controller
dynamically keyed by `column.key`. Implement `beak_form_controller_builder.dart` to build
an `OiAfController<BeakColumnKey, BeakRecord>` from the column list:
- For each form-context column, call the matching `addXField` with validators derived from
  the column's `BeakRule`s (map each rule → an `OiAfValidators` entry; e.g.
  `BeakRequired→required:true`, `BeakMaxLength→OiAfValidators.maxLength`, `BeakEmail→
  OiAfValidators.email`, ...). `field_widget_mapper.dart` maps each column's form intent
  to the corresponding `OiAf*` widget (`BeakStringColumn→OiAfTextInput`,
  `BeakDecimalColumn→OiAfNumberInput`, `BeakEnumColumn→OiAfSelect`,
  `BeakBoolColumn→OiAfSwitch`, `BeakDateTimeColumn→OiAfDateTimeInput`,
  `BeakColorColumn→OiAfColorInput`, `BeakRichTextColumn→OiAfRichEditor`,
  `BeakTextColumn→multiline OiAfTextInput`).
- `buildData()` returns a typed `BeakRecord`; submit calls `dataSource.create/update`
  through the repository (optimistic where appropriate), maps 422 field errors back onto
  the form fields (so server validation shows inline).
- Sections: default single section, or user-supplied `List<BeakFormSection>` grouping
  column keys (renders with obers_ui layout).
- Conditional visibility: `BeakFormSection`/field can carry a predicate over current
  values to show/hide (typed, not `Map<String,dynamic>`).

### Relationship + upload fields
```dart
// relation_field.dart
//   BeakBelongsTo -> OiAfComboBox/OiComboBox with async options from dataSource.query on
//     the related table (search by the relation's searchColumnKeys, show displayColumn).
//   BeakBelongsToMany/HasMany -> multi-select / OiAfTagInput-style, or an embedded
//     relation manager for full CRUD on children.
// upload_field.dart
//   BeakImageColumn/BeakFileColumn -> an OiAf file field that on pick calls
//     dataSource.upload(table, columnKey, BeakUpload) and stores the returned key/url as
//     the field value; shows a thumbnail preview (image) using the returned variant.
//     Enforces the column's rules client-side too (fast feedback) before upload.
```

### Detail view + relation manager
```dart
class BeakDetailView extends HookWidget {
  const BeakDetailView({super.key, required this.model, required this.record});
  // Maps detail-context columns -> OiDetailView sections/fields, reusing the intent
  // renderer from Phase 12 for value formatting.
}
class BeakRelationManager extends HookWidget {
  const BeakRelationManager({super.key, required this.parentModel, required this.parentId,
      required this.relationship, required this.dataSource});
  // Embedded BeakDataTable of the related records with attach/detach/create actions.
}
```

## Tests to write FIRST
- `beak_form_controller_builder_test.dart` — from a sample model, the built controller has
  a field per form column with the right type and validators (rule→validator mapping
  exhaustive); `buildData()` yields the correct typed `BeakRecord`.
- `beak_data_form_test.dart` (widget) — create mode renders the right `OiAf*` widgets;
  client-side validation blocks submit and shows messages; a successful submit calls
  `dataSource.create` with the typed record; a 422 from the source maps errors onto the
  correct fields; edit mode pre-populates from `getOne`.
- `relation_field_test.dart` (widget) — belongsTo picker queries the related table and
  filters by search columns; selecting sets the FK value; many-relation multi-select
  attaches/detaches.
- `upload_field_test.dart` (widget) — picking a file calls `dataSource.upload` and stores
  the returned key; oversize/disallowed rejected client-side with the rule message;
  thumbnail preview shows.
- `beak_detail_view_test.dart` (widget) — detail columns render read-only with correct
  formatting; **no Material**.

## Implementation notes / constraints
- `HookWidget`, Signals, GetIt, zero Material. Reuse the Phase 12 intent renderer for
  display formatting (no duplication).
- Server validation is the source of truth; client validation is a fast mirror derived
  from the same `BeakRule`s.
- Keep the autoforms bridge (`BeakColumnKey`) fully typed — no stringly-typed field maps
  leaking to users.

## Definition of Done (gate)
- [ ] `flutter analyze` 0 · `flutter test` green · coverage ≥ 85% · format clean · Material ban green.
- [ ] Rule→validator mapping exhaustive + tested; 422 round-trips to inline field errors.
- [ ] Upload field stores backend keys; relation pickers work.
- [ ] STATE.md row 13 → `✅ DONE` + SHA.

## Commit
`feat(beak_frontend): add autoforms-driven BeakDataForm, upload/relation fields and detail view`
