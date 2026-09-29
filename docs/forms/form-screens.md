---
title: Form screens
description: Use one declarative form runtime for values, rules, related drafts and saves.
type: guide
audience: [beginner]
status: draft
---

# Form screens

Place generated typed inputs inside a `BeakFormLayout`. A resource supplies its model, identity and data source; `BeakConfiguredForm` provides the same runtime when embedded directly.

```dart title="examples/clean_beak_config/lib/resources/users/screens/user_form_screen.dart"
--8<-- "examples/clean_beak_config/lib/resources/users/screens/user_form_screen.dart"
```

## Layout and behavior

Use `BeakCard`, `BeakColumns`, `BeakSection` and `BeakTabs` for structure. `BeakFormSections` reuses a section definition across plain, tabbed and wizard presentations. Conditions can apply to a group or an individual input.

Model rules and behavior supply shared constraints and values. Placement rules add local restrictions. Model value lifecycles distinguish defaults, suggestions, derived values and action snapshots. Explicit custom calculations and validators remain ordinary Dart functions.

## Choice cards

`inputRadio(cards: true)` presents typed scalar choices as bordered radio cards.

Choice presentation follows the panel theme: Obers `radio.groupLabelStyle`
styles the section heading, while `radio` controls the indicator and `radioTile`
controls card padding, radius, minimum height and selected outlines. The same
card theme applies to relationship choices. Outline changes do not move content
or create extra state; the form keeps owning binding and validation.
`BeakInputOption.description` supplies supporting text and `icon` an optional
Obers icon. The field keeps its normal binding, model validation, disabled
options and read-mode labels.

```dart
OrderModel.paymentMode.inputRadio(
  label: 'Payment method',
  cards: true,
  options: (state) => const [
    BeakInputOption(
      'monthlyInvoice',
      'Company invoice',
      description: 'Billed to the company profile',
      icon: OiIcons.landmark,
    ),
    BeakInputOption(
      'paymentLink',
      'Payment link',
      description: 'The customer pays before preparation',
      icon: OiIcons.link,
    ),
  ],
)
```

The options callback receives the tracked form reader, so options can follow
other fields without a separate controller. Relationship records use
`inputCards(template: ...)`, described in [Workflow presentations](workflow-presentations.md).

## Exact code lookup

Use `inputCode` for a voucher, reference or other unique identifier. Beak provides
the text input, Apply/Remove actions, loading and error states. Applying a code
only stages the relationship; the normal form submission persists it.

```dart
OrderModel.voucher.inputCode(
  label: 'Voucher code',
  codeField: VoucherModel.code,
  normalizeCode: (code) => code.toUpperCase(),
  placeholder: 'e.g. WELCOME10',
  template: BeakRecordTemplate.fields(
    title: VoucherModel.code,
    subtitle: [VoucherModel.description],
  ),
)
```

`codeField` must be a string field directly on the related model. The exact
query retains the model's eligibility constraints, dependent filters and access
policy. Unknown, unavailable and ambiguous codes are rejected. A changed
dependency invalidates an outstanding lookup; a network error remains visible
and retryable. `normalizeCode` is optional; omit it for case-sensitive identifiers.

## Calculated fields and requirements

`BeakCalculated` reads the same draft without adding a stored model field.
Its default presentation is inline text. `presentation: BeakCalculatedPresentation.field`
shows a labelled, subdued value, while `.checkbox` displays a locked boolean
requirement such as automatic company approval. Supply `dependencies` for
related values used by the calculation; they are loaded and checked for read
access before rendering. `labelBuilder` and `description` can explain the current
calculated result. These presentations never add writes to the save graph.

An ordinary editable checkbox can use `inputCheckbox(labelBuilder: ...)` to
name its current recipient or other draft context. Its boolean value still uses
the normal model binding and validation.

## Date shortcuts and multiline text

`inputDate(shortcuts: (state) => [...])` places typed `BeakInputOption<BeakDate>`
shortcuts beside the normal calendar picker. They are suggestions, so a different
calendar date remains valid unless model/placement rules reject it. Disabled
shortcuts cannot be selected. The callback uses the same tracked draft reader
as other input configuration; date values never pass through an instant timezone.

```dart
OrderModel.deliveryDate.inputDate(
  label: 'Delivery date',
  shortcuts: (_) => [BeakInputOption(tomorrow, 'Tomorrow')],
)
OrderModel.deliveryNote.inputText(maxLines: 3)
```

`inputText(maxLines: 3)` keeps an ordinary string column and uses a three-line
editor. A model `BeakMaxLength` rule supplies its character limit and counter;
server validation continues enforcing the same rule.

## Drafts

Related edits, new picker records and uploads belong to the form draft. A modal checkpoint supports cancellation without persisting intermediate work. Validation observes current dependencies and ignores stale asynchronous responses.

The final submission validates visible submitted values and produces a graph save plan. The source reports its atomic or staged guarantee; the UI preserves an interrupted draft and recovery information. Hidden fields are excluded unless their placement explicitly opts into submission.

## Escape hatches

`onSession` exposes the live session for a custom editor or workflow. Use its typed draft operations rather than maintaining a parallel state map. Read mode uses the same layout and panel-wide formatters.

## Continue reading

- [Multi-step forms](multi-step-forms.md)
- [Shared model behavior](../models/behavior.md)

### Preferred eligible choices

`inputCards(defaultOptionMatch: ..., selectDefaultOption: true)` can resolve a
recurring preference into a currently eligible option. Declare the fields used
by the matcher in `dependencies`, and put date, availability and ownership
restrictions in `options`. Matching runs only against loaded options when the
selection is blank and the search term is empty; disabled options are excluded.
A valid manual choice is preserved. `defaultOptionMatch` also identifies the
choice's Default badge without enabling selection unless `selectDefaultOption`
is set. Existing `defaultOption` can reference a concrete related record.

### Pending edit indicators

Set `BeakFormLayout(showChangeIndicators: true, children: [...])` to mark
editable fields that differ from an existing record's loaded baseline. Markers
use the existing typed draft comparison; restoring a value or discarding the
draft removes them. New-record forms and read-only or inaccessible fields do
not show modified markers. Inline command argument forms inherit their owning
persisted edit context. Compact relationship rows mark newly added items until
they are removed or saved. This presentation does not add a history store. The marker theme wrapper remains
mounted as a field changes, preserving focus, cursor position and IME composition.

`BeakFormSession.compactReviewChanges` returns actual graph operations, excluding
field updates already represented by a newly created row.
`reviewChangeCount` and `reviewChangeSummary` derive from that same list. The full
`reviewChanges` remains available for the detailed review. The shared floating
bar uses the compact count and labels rather than a separate app counter; its
error action opens the first invalid region and focuses the matching editor,
including keyboard activation.

### Shared action and heading presentation

`BeakConfiguredForm` accepts `editLabel`, `prominentEdit`, `compactActions`,
`submitIcon`, `outlinedCancel` and `showActionsWhileEditing`. These change the
existing controls' presentation; model commands still resolve permissions,
arguments and execution through the same session. Defaults retain the ordinary
Edit button, visible commands and existing save/cancel treatment.

`BeakRelationAdd(presentation: BeakRelationAddPresentation.search, ...)` opens
the declared collection editor through the same draft checkpoint as the dashed
presentation. Its search-shaped surface remains one named action button; it
does not create another query or editable text field. Cancelling restores the
checkpoint, and row permissions and table availability still apply.

`inputRadio(groupLabelAsField: true)` uses the text-input label style and label
gap for a field heading. The default uses the radio group's heading role and
`groupLabelSpacing`; spacing between options remains 8px. Quantity inputs accept
`inputQuantity(controlWidth: 90)` without bypassing numeric bounds or binding.
`BeakFormCapacity.valueStyle` styles the displayed ratio independently of its
label; omitting it preserves the earlier label-style fallback.


Relationship `inputCards(cardPadding: ...)` overrides the declared choice inset;
its nullable default preserves existing rich and compact card spacing. Scalar
`inputRadio(cardPadding: ...)` has a separate choice-card placement override.
The shared radio tile still paints its selected outline over the same bounds.


Multiline scalar placements can set `inputText(multilineContentPadding: ...)`.
The nullable override is scoped to that editor and resolves the current text
direction; other multiline notes retain the input theme's padding and height.
