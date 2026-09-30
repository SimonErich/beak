# Printable record documents

> Add a print action that renders a persisted record as a standalone HTML document with labelled sections and related-row tables, from typed bindings.

After this page you can add a Print action to a resource that produces a delivery note, a receipt or a work order from a saved record, without writing fetch code, print code or a second copy of the record's state.

The document is a snapshot: a title, some metadata, labelled sections of values and tables of related rows. You describe it with the same typed bindings that fill record templates. Beak loads the record through the panel's normal data source, formats it with the panel's policy, escapes it, and hands it to the browser's print dialog or to a file-save dialog.

## At a glance

Foodio prints a delivery note for an order:

```dart title="examples/foodio-adminpanel/lib/resources/orders/actions/order_documents.dart"
/// A print-ready snapshot of the persisted order, with no app fetch/print code.
BeakRecordAction deliveryNoteAction() => BeakRecordAction.document(
  key: 'delivery-note',
  label: 'Print delivery note',
  roles: const {BeakScreenRole.list, BeakScreenRole.read},
  document: BeakRecordDocument(
    title: BeakValueBinding.field(OrderModel.reference),
    subtitle: [
      BeakValueBinding.field(OrderModel.customer.name),
      BeakValueBinding.field(OrderModel.profile.name),
    ],
    fileName: 'delivery-note.html',
    sections: [
      BeakDocumentSection(
        title: 'Delivery',
        fields: [
          BeakValueBinding.field(OrderModel.deliveryDate, label: 'Date'),
          BeakValueBinding.field(OrderModel.slot.name, label: 'Time'),
          BeakValueBinding.field(OrderModel.location.name, label: 'Location'),
          BeakValueBinding.field(OrderModel.street, label: 'Street'),
          BeakValueBinding.field(OrderModel.postalCode, label: 'Postal code'),
          BeakValueBinding.field(OrderModel.city, label: 'City'),
          BeakValueBinding.field(OrderModel.handover, label: 'Handover'),
          BeakValueBinding.field(
            OrderModel.contactPhone,
            label: 'Contact phone',
          ),
          BeakValueBinding.field(
            OrderModel.deliveryNote,
            label: 'Instructions',
          ),
          BeakValueBinding.field(OrderModel.routeCode, label: 'Route'),
        ],
      ),
      BeakDocumentCollection(
        title: 'Dishes',
        field: OrderModel.items,
        columns: [
          OrderItemModel.label,
          OrderItemModel.variantName,
          OrderItemModel.quantity,
          OrderItemModel.allergens,
          OrderItemModel.note,
          OrderItemModel.grossCents.currency(minorUnits: true, label: 'Total'),
        ],
      ),
      BeakDocumentSection(
        title: 'Kitchen notes',
        fields: [
          BeakValueBinding.field(OrderModel.allergenNote, label: 'Allergens'),
          BeakValueBinding.field(
            OrderModel.customerNote,
            label: 'Customer note',
          ),
          BeakValueBinding.field(
            OrderModel.grossCents.currency(minorUnits: true),
            label: 'Order total, including VAT',
          ),
        ],
      ),
    ],
  ),
);
```

The order resource lists it in `recordActions`, next to a "Call customer" link action:

```dart
recordActions: [
  deliveryNoteAction(),
  // ...
],
```

That fence is illustrative and abridged. The real list is in `examples/foodio-adminpanel/lib/resources/orders/order_resource.dart`.

`BeakRecordAction.document` returns a `BeakRecordAction`, so the button appears where any record action does:

- as a row action in the list, when `roles` contains `BeakScreenRole.list`,
- in the header of the generated show page and of a form screen's page frame, for the roles it lists, once the record exists.

Here it is limited to `list` and `read`. The default roles are `list`, `read` and `edit`. On a create form a record action does not appear, because it needs a saved record.

## The definition

`BeakRecordDocument` has a `title` binding, optional `subtitle` bindings, a list of `sections`, and a `fileName` for the download (default `document.html`). Each section is one of two kinds.

| Part | Holds | Notes |
| --- | --- | --- |
| `BeakDocumentSection(title:, fields:)` | Labelled values from the record and its to-one paths | Each field is a `BeakValueBinding`. Set its `label:` to name it in the document |
| `BeakDocumentCollection(title:, field:, columns:)` | A table of a to-many relationship | `field` is a generated `BeakToManyField`. `columns` are generated scalar fields of the related model, one per column, in order |

A section is made of `BeakValueBinding`s, a collection of generated fields. A binding built with `.field(...)` reads a generated field with its normal formatting. A `.computed(...)` binding is a pure calculation and must list every field it reads in `dependencies`, exactly as in a record template. When a binding's `visibleIf` returns false, its line is left out of the page.

Formatting is set on the field, not on the document. `OrderModel.grossCents.currency(minorUnits: true)` says that an integer column holds cents, and the document prints euros. `.formatted(BeakValueFormat.date)` and the other overrides work as they do in tables. A collection column takes the same overrides, with a `label:` for its header: `OrderItemModel.grossCents.currency(minorUnits: true, label: 'Total')`. Password columns print as the empty value, whatever the binding says.

## What happens when you press Print

1. The action checks that the account may run it. An unsaved record fails with "Save the record before printing."
2. On the web, it opens an empty window right away, while the click is still a user gesture. Browsers block windows opened later.
3. It loads the persisted record. The query is inferred from the bindings and the collection columns, so one request brings the record and its related rows. The server applies the same row, field and relationship authorization as for any other query.
4. It checks permission again, renders the document, writes it into the window and calls print. A denied action or a failed load closes the empty window.

The action always prints the saved record. If the print button sits on an edit page with unsaved changes, those changes are not in the document, and printing does not save them. Pending controls prevent a second click while one is running.

If the browser blocks the window, or on a native platform, the same HTML is offered through the save-file dialog and can be opened and printed from there. Cancelling the dialog does nothing.

## What is in the file

The document is one standalone HTML page. Its values, labels and titles are frozen at the moment of the click together with the panel's locale, currency and date policy, so the numbers on paper are the numbers the person saw. Every text is HTML-escaped. The page loads no fonts, images or scripts and carries a content security policy of `default-src 'none'; style-src 'unsafe-inline'`. It has print styles for A4 and keeps table rows and value pairs from splitting across pages. A PDF is what a browser's print dialog can produce from it. Beak does not render PDFs.

## Delivering somewhere else

`BeakRecordAction.document(beginDelivery: ...)` takes a function that returns a `BeakDocumentDelivery`. That is the seam a host uses to send the document to a mail composer, a print service or a test:

| Member | Job |
| --- | --- |
| `show(BeakDocumentSnapshot)` | Receives the frozen document: `title`, `html`, `fileName` |
| `cancel()` | Releases anything reserved before loading, when loading fails or is cancelled |

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Persisted records only | A record without an identity cannot be printed. The document never contains draft values |
| Collection columns | Every column must belong to the related model of the collection, or the load throws a `BeakConfigurationException` |
| Sections read the record | A section reads the record and its to-one paths. Related rows go in a `BeakDocumentCollection` |
| Authorization | The server decides what is readable, with the same row, field and relationship rules as any query. A missing or inaccessible record fails with "The document record is unavailable." |
| Dependencies | A computed binding must declare its fields, or they may not be loaded |
| Wizard pages | A screen with steps has no page frame, so a print button does not appear on it |
| Not a report engine | One page of HTML per record. There is no pagination logic, page header or totals row beyond what the bindings compute |
| Web pop-ups | If the browser blocks the window, the download fallback opens instead |

## Verify it

The definition, the escaping and the delivery contract have package tests:

```bash
cd packages/beak_frontend
flutter test test/src/documents/beak_record_document_test.dart
```

The run ends with `All tests passed!`. To see a document, run Foodio (API on port 8081), open an order and press Print delivery note. Chrome opens a print preview with the delivery details, the dish table and the kitchen notes.

## Reference

| Symbol | Where it is documented |
| --- | --- |
| `BeakRecordAction.document` | [Behavior and actions](../reference/behavior-and-actions.md#beakrecordaction) |
| `BeakRecordDocument`, `BeakDocumentSection`, `BeakDocumentCollection`, `BeakDocumentSnapshot` | `packages/beak_frontend/lib/src/documents/beak_record_document.dart` |
| `BeakDocumentDelivery`, `BeakDocumentDownload` | `packages/beak_frontend/lib/src/documents/beak_document_delivery.dart` |
| `BeakValueBinding` | `packages/beak_frontend/lib/src/presentation/beak_record_template.dart` |

## Continue reading

- [Actions](../panel/actions.md) record actions, roles and where their buttons appear.
- [Workflow presentations](workflow-presentations.md) the bindings and templates the document reuses.
- [Composed lists](../panel/composed-lists.md) placing a document action in a list row.
- [Authorization and policies](../backend/auth-and-policies.md) what the load is allowed to read.
