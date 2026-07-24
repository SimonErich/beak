---
title: Forms
description: How Beak turns a model's form columns into a validated create/edit form with pickers, uploads, sections, and conditional visibility.
---

# Forms

After this page you can render a full create and edit form for any model with one widget, group its fields into sections that appear and disappear as the user types, and know exactly how a column's validation rules travel to the field.

Beak's form is `BeakDataForm`. You give it a model and a data source; it reads the model's form-context columns, builds a typed input for each, mirrors each column's rules as client-side validators, wires belongs-to pickers and upload fields, prefills in edit mode, and maps a 422 back onto the offending fields. There is no per-resource form code to write. The generated create and edit pages construct one for you, so most apps never touch it directly.

## The one widget

`BeakDataForm` is a `HookWidget`. A `null` `recordId` renders the create form; any other value loads that record and switches to edit mode.

```dart title="packages/beak_frontend/lib/src/form/beak_data_form.dart"
const BeakDataForm({
  required this.model,
  required this.dataSource,
  this.recordId,
  this.sections,
  this.steps,
  this.layout,
  this.onSaved,
  this.uploader,
  this.filePicker,
  super.key,
});
```

The generated create and edit pages wire it straight from the resource:

```dart title="packages/beak_frontend/lib/src/pages/beak_resource_pages.dart"
child: BeakDataForm(
  model: resource.model,
  dataSource: dataSource,
  steps: resource.formSteps,
  layout: resource.formLayout,
  onSaved: (_) => router.go(BeakRoutes.list(resource.model.table)),
),
```

`onSaved` fires with the stored record after a successful submit. `sections`, `steps`, and `layout` are three ways to structure the same fields: a flat form with grouped sections (this page), a wizard ([Multi-step forms](multi-step-forms.md)), or a record-bound block layout shared with the show page ([Detail views and dual-mode blocks](detail-and-dual-mode.md)). When more than one is set, `steps` wins, then `layout`, then `sections`.

!!! note "What just happened"
    - You handed the form a `BeakModel` and a `BeakDataSource`. It did the rest.
    - The form registered one typed field per form-context column, skipping the primary key.
    - `recordId: null` means create; any id means load-then-edit.

## Columns become typed fields

Each column type maps to exactly one `OiAf*` field. This is the single place a column type turns into a form input, so the mapping is worth keeping nearby.

```dart title="packages/beak_frontend/lib/src/form/field_widget_mapper.dart"
return switch (column) {
  BeakCustomColumn() => null,
  BeakStringColumn(:final placeholder, :final maxLength) => OiAfTextInput(
    field: slot(),
    label: column.label,
    placeholder: placeholder.isEmpty ? null : placeholder,
    maxLength: maxLength,
  ),
  BeakTextColumn() || BeakJsonColumn() => OiAfTextInput.multiline(
    field: slot(),
    label: column.label,
  ),
  BeakIntColumn(:final min, :final max) => OiAfNumberInput(...),
  BeakDecimalColumn(:final precision) => OiAfNumberInput(...),
  BeakBoolColumn() => OiAfSwitch(field: slot(), label: column.label),
  final BeakEnumColumn<Enum> enumColumn => OiAfSelect<BeakFormSlot, Enum>(...),
  BeakDateTimeColumn() => OiAfDateTimeInput(field: slot(), label: column.label),
  BeakColorColumn() => OiAfColorInput(field: slot(), label: column.label),
  BeakRichTextColumn() => OiAfRichEditor(field: slot(), label: column.label),
  BeakUploadColumn() => BeakUploadField(...),
};
```

The full table:

| Column | Field widget |
| --- | --- |
| `BeakStringColumn` | `OiAfTextInput` (carries `placeholder`, `maxLength`) |
| `BeakTextColumn`, `BeakJsonColumn` | `OiAfTextInput.multiline` |
| `BeakIntColumn` | `OiAfNumberInput` (`decimalPlaces: 0`, honors `min`/`max`) |
| `BeakDecimalColumn` | `OiAfNumberInput` (`decimalPlaces: precision`) |
| `BeakBoolColumn` | `OiAfSwitch` |
| `BeakEnumColumn<T>` | `OiAfSelect` (options from the enum's values and labels) |
| `BeakDateTimeColumn` | `OiAfDateTimeInput` |
| `BeakColorColumn` | `OiAfColorInput` |
| `BeakRichTextColumn` | `OiAfRichEditor` |
| `BeakImageColumn`, `BeakFileColumn` | `BeakUploadField` |
| `BeakCustomColumn` | no field (rendered through the custom escape hatch) |
| a `BeakBelongsTo` foreign key | `BeakBelongsToField` picker |

You address a field by its column constant, never by a string. Under the hood `obers_ui_autoforms` keys fields by a Dart enum, so `BeakFormController` claims one `BeakFormSlot` per form column in declaration order and hands you a column-addressed API on top:

```dart title="packages/beak_frontend/lib/src/form/beak_form_controller_builder.dart"
final String? name = controller.valueOf<String>(ProductColumns.name);
controller.setValue<bool>(ProductColumns.onSale, true);
```

The slot pool caps at 32 fields. A model that declares more form columns than that throws a `BeakConfigurationException` asking you to split the form with sections or hide columns from the form context. See [Column types](../models/column-types.md) for how `visibleOn` keeps a column out of the form.

## Rules mirror the server, message for message

A column's [validation rules](../models/validation-rules.md) run on both sides of the wire from a single declaration. The form does not re-implement them: every client-side validator delegates to the rule's own `validate`, so the client and the server produce byte-identical messages.

```dart title="packages/beak_frontend/lib/src/form/beak_form_controller_builder.dart"
OiAfValidator<BeakFormSlot, T>? _mirror<T>(BeakRule rule) => switch (rule) {
  BeakRequired() => OiAfValidators.custom<BeakFormSlot, T>(
    (context) => rule.validate(context.value),
  ),
  BeakMaxFileSize() || BeakAllowedFileTypes() => null,
  BeakMinLength() ||
  BeakMaxLength() ||
  BeakEmail() ||
  BeakUrl() ||
  BeakPattern() ||
  BeakMin() ||
  BeakMax() ||
  BeakInList() => OiAfValidators.custom<BeakFormSlot, T>(
    (context) => _mirrorContent(rule, context.value),
  ),
};
```

Two details make the mirror faithful to the backend, which validates only the values a request actually submitted:

- **Presence is `BeakRequired`'s job alone.** Content rules skip an absent (`null`) value and only run once something is entered. A submitted empty or whitespace string still gets validated, exactly as the server's `ValidationService` treats every provided value.
- **Upload rules mirror to `null` here.** `BeakMaxFileSize` and `BeakAllowedFileTypes` return no form validator because the upload field enforces them before the file ever leaves the client (see [Uploads](#uploads)).

The server side reads the same rules the same way, calling `rule.validate(raw)` in `ValidationService`. One rule, two runners, identical text.

When the server rejects a submit with a 422, the form maps each field error back onto the matching field; errors under an unknown key surface as a global form error:

```dart title="packages/beak_frontend/lib/src/form/beak_form_controller_builder.dart"
void applyServerErrors(Map<String, List<String>> errorsByColumnKey) {
  for (final MapEntry(:key, :value) in errorsByColumnKey.entries) {
    final BeakFormSlot? slot = _slotByKey[key];
    if (slot != null) {
      setBackendErrors(slot, value);
    } else {
      setGlobalError('$key: ${value.join(' ')}');
    }
  }
}
```

## Sections group and gate the fields

Pass `sections` to slice a large model's form into titled groups and to control field order. A section lists the columns it renders; columns in no section carry no field at all, so sectioning is also how you subset a form.

```dart title="packages/beak_frontend/lib/src/form/beak_form_controller_builder.dart"
final class BeakFormSection {
  const BeakFormSection({
    required this.title,
    required this.columns,
    this.visibleWhen,
  });

  final String title;
  final List<BeakColumn> columns;
  final BeakFormPredicate? visibleWhen;
}
```

`visibleWhen` is a typed predicate over the form's current values, never a `Map<String, dynamic>`. Reads go through a column-addressed reader that tracks dependencies, so a section re-evaluates automatically whenever a value it read changes.

```dart title="packages/beak_frontend/lib/src/form/beak_data_form.dart"
sections: [
  const BeakFormSection(
    title: 'Basics',
    columns: [ProductColumns.name, ProductColumns.onSale],
  ),
  BeakFormSection(
    title: 'Pricing',
    columns: const [ProductColumns.salePrice],
    // Only shown while the "on sale" switch is on.
    visibleWhen: (values) =>
        values.valueOf<bool>(ProductColumns.onSale) ?? false,
  ),
],
```

`values.valueOf<T>(column)` returns the field's current typed value, or `null` when the field is unset or the column carries no field. A section with no predicate is always visible.

!!! tip "Sections vs the block layout"
    Sections are the quickest way to organize a flat form. When you want the create form to share the exact cards, tabs, and grids of the show page, reach for a record-bound `layout` instead. See [Detail views and dual-mode blocks](detail-and-dual-mode.md).

## Relationship pickers

For each `BeakBelongsTo` relationship, the form wires a `BeakBelongsToField`: an async-searching combobox over the related table. It searches the relation's search columns, shows its display column, and stores the selected record's id in the foreign-key field. In edit mode it resolves the prefilled foreign key into a labelled record, so the picker opens on the current selection.

```dart title="packages/beak_frontend/lib/src/form/relation_field.dart"
return OiComboBox<BeakRecord>(
  label: relation.label,
  labelOf: relation.displayLabelOf,
  value: selected.value,
  error: controller.getError(slot),
  search: (query) => beakSearchRelated(
    repository,
    table: relation.relatedTable,
    columnKeys: relation.effectiveSearchColumnKeys,
    term: query,
  ),
  onSelect: (record) {
    selected.value = record;
    controller.set(slot, record?[relatedPrimaryKeyKey]?.raw);
  },
);
```

A many-to-many relationship needs a saved parent (a pivot row needs both keys), so `BeakBelongsToManyField` appears only in edit mode. It is a multi-select combobox seeded with the currently attached records; each change diffs against the attached set and issues just the `attach`/`detach` calls needed, reverting the optimistic selection if a mutation is rejected. Has-many relations render an embedded `BeakRelationManager` under the form in edit mode. Both are covered in [Relationships](../models/relationships.md) and [Detail views and dual-mode blocks](detail-and-dual-mode.md).

## Uploads

Image and file columns render a `BeakUploadField`. Picking a file validates the column's size and type rules on the client (again, the same messages as the backend), uploads through the configured `BeakUploadClient`, and stores the returned storage key as the field value. Images also get a thumbnail preview.

Two things must be supplied for the field to be interactive: an `uploader` (the transport) and a `filePicker` (the strategy that returns picked bytes). Without both, the field renders read-only.

```dart title="packages/beak_frontend/lib/src/form/upload_field.dart"
typedef BeakFilePicker = Future<BeakUpload?> Function();
```

The `uploader` defaults to the form's `dataSource` when it also implements `BeakUploadClient`, which the HTTP data source does:

```dart title="packages/beak_frontend/lib/src/form/beak_data_form.dart"
final BeakUploadClient? effectiveUploader =
    uploader ??
    switch (dataSource) {
      final BeakUploadClient client => client,
      _ => null,
    };
```

The `filePicker` is yours to provide, because platform pickers surface names while Beak needs bytes to validate and upload. The reference app wires a `file_picker`-based one:

```dart title="packages/beak_frontend/lib/src/form/upload_field.dart"
Future<BeakUpload?> pickImageFromDisk() async {
  final result = await FilePicker.platform.pickFiles(withData: true);
  final file = result?.files.single;
  if (file == null || file.bytes == null) {
    return null;
  }
  return BeakUpload(
    filename: file.name,
    mimeType: 'image/png',
    bytes: file.bytes!,
  );
}
```

See [Files and storage columns](../models/files-and-storage-columns.md) for the column side and [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) for the server side.

## The teaching store, end to end

The reference admin app declares its Products resource with a filter and a custom action and gets create and edit forms for free, because a resource's form is generated from its model. This is the whole panel config for the store, on port 8080:

```dart title="apps/reference_admin/lib/main.dart"
BeakPanelConfig buildReferencePanelConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: apiBaseUrl,
  resources: const [
    BeakResource(
      model: ProductModel(),
      icon: BeakIconToken(OiIcons.package),
      filters: [
        BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
        BeakTextFilter(column: ProductColumns.name, label: 'Name'),
      ],
      recordActions: [
        BeakRecordAction(
          key: 'duplicate',
          label: 'Duplicate',
          icon: OiIcons.copy,
          onExecute: duplicateProduct,
        ),
      ],
    ),
    // ...five more resources
  ],
);
```

Nowhere does the store write a form. The Product form, its category picker, its tag multi-select, and its client validation all fall out of `ProductModel`.

!!! question "What this skipped"
    - Wizards for long entities: [Multi-step forms](multi-step-forms.md).
    - Sharing one block layout between the form and the show page: [Detail views and dual-mode blocks](detail-and-dual-mode.md).
    - The REST routes a submit calls: [The generated API](../backend/the-generated-api.md).

## Continue reading

- [Multi-step forms](multi-step-forms.md) break a long form into validated wizard steps.
- [Detail views and dual-mode blocks](detail-and-dual-mode.md) drive the form and the show page from one layout.
- [Validation rules](../models/validation-rules.md) are the rules the form mirrors.
- [Files and storage columns](../models/files-and-storage-columns.md) back the upload field.
- [Actions](actions.md) add the buttons that live around the form.
