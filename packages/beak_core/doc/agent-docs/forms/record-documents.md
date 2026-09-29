# Printable record documents

> Configure an authorized persisted record document with typed values and related-row tables.

`BeakRecordAction.document` adds a working print action to a resource. The definition selects the document's heading, metadata, labelled sections and related-row tables. Generated fields and `BeakValueBinding` supply all data; the application does not implement fetching or maintain another record state.

Configure `BeakRecordDocument` with a title binding, optional subtitle bindings and a list of document parts. `BeakDocumentSection` contains labelled value bindings. `BeakDocumentCollection` takes a generated to-many field and scalar columns of its related model. Columns can use the same `.currency(minorUnits: true)` and `.formatted(...)` overrides as a table. Computed bindings must declare every field dependency, as they do in record templates.

Add the result to `BeakResource.recordActions`. It appears in the standard record header and is available to configured list action placement. Set `roles: {BeakScreenRole.list, BeakScreenRole.read}` on the document factory to expose printing only in list and read presentations. New unsaved records cannot be printed. The action always reloads the persisted record, even when launched while an edit form contains unsaved changes.

## Loading and authorization

Beak infers relation loads from every binding and collection column, then loads the record through the resource's normal data source. The server applies the same row, field and relationship authorization as any other query. A missing or inaccessible record cannot produce a document. The selected document fields are a presentation projection; this feature does not introduce another endpoint or weaken the source's read policy. Password fields remain redacted.

The action checks current presentation permission before loading and again before delivery. A denied action, failed load or disposed page closes the reserved empty print window. Pending controls prevent duplicate dispatch. Printing never changes data or saves the form.

## Formatting and delivery

The document freezes its values and the panel's locale, currency and date/time policy when invoked. Integer minor units retain exact formatting. Every text value, label, title and metadata attribute is HTML-escaped. The standalone document loads no external fonts, images or scripts and includes a restrictive content security policy.

On web, Beak reserves a separate window during the originating gesture, fills it after the authorized load, and invokes that window's print dialog. It does not print the Flutter canvas. The window remains available after cancelling the print dialog. If the browser blocks the window, or on a native host, Beak offers the same standalone HTML through the platform's file-saving capability; the saved file can be opened and printed. Cancelling file saving has no side effects.

Embedded hosts can supply `beginDelivery` with a `BeakDocumentDelivery` implementation. Its `show` receives one immutable `BeakDocumentSnapshot`; `cancel` releases any presentation reserved before loading. This is also the seam used by the document action tests.

## Continue reading

- [Composed lists and query state](../panel/composed-lists.md)
- [Actions](../panel/actions.md)
- [Workflow presentations](workflow-presentations.md)
- [Authorization and policies](../backend/auth-and-policies.md)
