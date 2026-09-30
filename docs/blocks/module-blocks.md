---
title: Module blocks
description: Chat, inbox, file manager, media, profile, invoice, pricing and FAQ views bound to your models, and the row limits, read failures and writes they come with.
type: guide
audience: [expert]
status: stable
---

# Module blocks

Module blocks are whole interfaces bound to a model: a chat transcript, a three-pane mailbox, a file manager, a pricing table. Each maps typed column bindings onto a ready-made obers_ui module, so you name which column is the sender and which is the body, and the block does the rest. After this page you know what each of the eleven reads, which of them write, and where their limits are.

## At a glance

| Block | Bound to | Draws | Writes |
| --- | --- | --- | --- |
| `BeakChatBlock` | a model | message bubbles and a composer | creates a record per sent message |
| `BeakInboxBlock` | a model, optionally a folder relation | folder rail, message list, detail pane | nothing |
| `BeakFileManagerBlock` | a model | files and folders | nothing |
| `BeakThreePaneBlock` | three blocks | a resizable three-pane layout | nothing |
| `BeakCarouselBlock` | a query | slides | nothing |
| `BeakGalleryBlock` | a query | a thumbnail grid with a preview | nothing |
| `BeakVideoBlock` | a query, first row | a video player | nothing |
| `BeakProfileBlock` | one record by id | a profile page | updates name, email and bio in place |
| `BeakInvoiceBlock` | one record by id, plus a line-item model | header, line items, totals | nothing |
| `BeakPricingBlock` | a model, plus a features relation | plan cards | nothing |
| `BeakFaqBlock` | a model | a searchable, categorized question list | nothing |

Three binding styles, and they set how much control you have. A **model-bound** block (chat, inbox, file manager, pricing, FAQ) takes the model and reads its rows itself, and takes a `filter:` if you want a subset. A **query-bound** block (carousel, gallery, video) takes a `BeakQuerySpec`, so you filter, sort and page it. A **record-bound** block (profile, invoice) takes one `recordId` and loads that row. All of them fetch through the panel's data source when they build. The model-bound and query-bound blocks fetch again after a confirmed write to their table; the record-bound ones load once per build.

Everything here is a full-height interface, so pages that hold one chat, inbox, file manager or FAQ set `framed: false` and let it fill the space:

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:faqPage"
```

## Conversations and files

### Chat

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:chat"
```

`authorField`, `bodyField` and `timeField` bind the columns. When `isMineField` is set, records where it is `true` sit on the outgoing side and every other record on the incoming one. The block fetches the newest 200 messages and shows them oldest first, so a longer thread loses its oldest messages, never the latest, and says so beneath the transcript.

`composeRecord` turns the block from a transcript into a chat. Without it there is no composer. With it, sending trims the text, ignores an empty message, builds the record with your function, creates it through the data source, as a graph commit, and appends what came back. The function is where you fill in the sender, foreign keys and defaults, and `model.record([...])` builds the record from typed `field.to(value)` pairs, so no column is a string. A refused send shows the reason in a toast (the panel's generic sentence for an infrastructure failure) and appends nothing.

### Inbox

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:inbox"
```

Three panes: a rail, a message list and a detail pane for the selected row. Bind `readField` when your model stores `is_read` or `unreadField` when it stores the opposite (asserted: not both), and unread rows get a leading dot. Selecting a row fills the detail pane with the subject, the sender, the preview and the time. The block never writes the read flag, so opening a message does not mark it read.

The rail has two modes. With `folderRelation` (a to-one field from message to folder) and `folderLabelField`, it is built from the data: one entry per distinct folder label, in the order of `folders` first, and selecting an entry filters the list to it. Selecting it again clears the filter. Without them, `folders` (default `['Inbox']`) is a static rail, meant to filter nothing. It does the opposite today: selecting a static entry filters by a folder the rows do not have, and the message list goes empty until the screen is built again. The Aviary's inbox uses the static rail and shows this when you click "Inbox". Bind the relation if the rail has to be clickable.

### File manager and three panes

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:files"
```

`BeakFileManagerBlock` lists the rows as files, or as folders where `isFolderField` is `true`, with size in bytes, modified time and a thumbnail when those columns are bound. It has no parent binding, so every row is a top-level entry and folders do not nest. Opening an entry only calls `onOpen` with its record.

`BeakThreePaneBlock` is the layout around it: a `left`, a `middle` and an optional `right` block, with initial widths of 260 and 320 pixels that the reader can drag. Its panes take any block. Give the tables inside a `heightInPixels`, as the example does, because a table needs a bounded height.

## Media

The three media blocks take a query, so they are the ones you can scope. The Aviary builds each query with a small helper that filters the assets by collection, sorts them by position and pages them at the largest page:

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:carousel"
```

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:gallery"
```

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:video"
```

The image and URL columns hold a URL, or an asset path for an image. The carousel autoplays unless you pass `autoplay: false`, draws slides at `heightInPixels` (320), and skips rows whose URL is empty. The gallery shows `columns` thumbnails per row (4) and opens a preview. In both, the caption column becomes the image's accessible description and is not drawn as visible text. The video block plays the first row of its query: `urlField` is the source, `posterField` an optional still, `title` the player's label, and `autoPlay` and `loop` are off by default. The Aviary points it at a video on the network.

## Documents

### Profile

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:profile"
```

The block loads the record by `recordId`, so a `const` tree is fixed to one row. To show the signed-in user, build the block at runtime with that id. The profile page is editable in place, and each edit of the name, the email or the bio is saved as an update of the bound column. A field without a bound column (the page also draws a Phone field) reports the save as failed. The panel's model rules are not re-applied in the block; the server validates the write.

### Invoice

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:invoice"
```

An invoice is composed from what exists: `metaFields` fill a "Details" group, `fromFields` a "From" group, and either `toFields` (columns on the invoice) or `toRelation` with `toPartyFields` (columns of the billed party, loaded with the invoice) a "To" group. The line items are a table of `lineItemsModel` scoped by `lineItemsForeignKey`. The totals group lists subtotal, discount, shipping, tax and `totalField`, each with its column's label and formatting.

The line-items table is a [`BeakTableBlock`](data-blocks.md) with `enableDelete: false`, so the invoice offers no delete button per line: the lines are part of the document, and the block does not edit the invoice. It still sorts, pages and filters like any table, and it refreshes itself when a write to the line-items table is confirmed. The header and totals do not: they load once per build.

### Pricing

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:pricing"
```

Each row is a plan. `featuredField` marks the recommended one, `yearlyPriceField` switches on a monthly and yearly toggle (the yearly view shows the yearly price divided by 12, still suffixed `/mo`), and `featuresRelation` with `featureLabelField` turns the plan's related rows into its bullet list (the block asks the server to load that relation with the plans). `currencySymbol` is a plain prefix and defaults to `$`. It does not follow the panel's currency, so pass yours. The call-to-action button is labeled from `ctaField` and is not wired to anything.

## Help

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:faq"
```

`BeakFaqBlock` is the help center's FAQ tab: search across all entries, grouping by `categoryField` and ordering by `sortField`. Answers support Markdown. Contact, knowledge base and feedback tabs are switched off. Reach for it over `BeakAccordionBlock` when the questions are data, because it brings search and categories that an accordion lacks.

## Rules and limits

- **A window of rows.** Chat, inbox, FAQ, pricing, file manager, kanban and calendar read one page of at most 200 rows (`BeakPagination.maxPerPage`). More matching rows are not there, and a line beneath the block says how many are shown. The query-bound blocks use the page size of the query you give them, and a bare `model.query()` means 25.
- **`filter:` narrows a model-bound block.** Without it the block shows every row of the model the user may read. Pass a filter built from generated field references to show a subset.
- **A failed read is shown.** Chat, inbox, file manager, pricing, FAQ and the media blocks put an error line above what they drew before and offer Retry, so an empty block means an empty result. The line carries the server's message for a domain failure and the panel's generic sentence for a configuration, storage, internal or transport one. Profile and invoice show "Loading…" until the record arrives, then the same error line with Retry when it cannot be read.
- **Refetched after a write.** Chat, inbox, file manager, pricing, FAQ, kanban, calendar and the media blocks fetch again when a write to their table is confirmed through this panel's data source. Profile and invoice do not: the profile shows what it saved, and the invoice header and totals stay as loaded until the screen is built again. A message added in another window appears after the next fetch: on a `refreshPolicy` tick, or when the screen is built again.
- **Two blocks write.** Chat creates and the profile updates, both as single-operation graph commits, so a model that only accepts graph commits works too. Chat shows a refused send in a toast. See [How data flows](../concepts/how-data-flows.md).
- **English defaults.** Each block's `label` defaults to an English word (`'Chat'`, `'Inbox'`, `'Files'`, `'Pricing'`, `'Profile'`, `'Help'`) that screen readers announce. The gallery, carousel, timeline and the invoice's groups ("Details", "From", "To", "Totals", "Line items") and loading text follow the panel's language. Visible English strings you cannot override: "Select a message" in the inbox, "Get Started" on a plan without a `ctaField`, and the text the obers_ui modules draw themselves: the chat composer's "Type a message…", the pricing table's "Monthly" and "Yearly" toggle and "Recommended" badge, and the profile page's field names.
- **Values are read leniently.** Numbers and dates are parsed from whatever the wire carries. A chat message without a readable time is stamped with the moment the block builds; a timeline or calendar row without one is left out.
- **Bindings are columns, not fields.** These blocks take `BeakColumn`s (`MessageModel.body.column`) and `BeakRelationship`s, not the typed field references the table block uses, so a related field path is not available.

## Verify it

Every module block is built by the Aviary's pages, and the page tests fail on any exception:

```console
$ cd examples/showcase
$ flutter test --no-pub test/aviary_pages_test.dart
...
00:05 +7: Inbox renders
00:05 +8: Files renders
00:06 +9: Media renders
00:07 +10: Documents renders
00:07 +11: FAQ renders
00:08 +12: All tests passed!
```

The fixture rows come from `BeakRecordFactory`, so the test knows every column. It does not send a chat message or edit a profile. To watch those, run the panel against the API as the [Showcase](../examples/showcase.md) page describes, and use the composer and the profile fields.

## Reference

Required parameters are marked with a star. Every block also takes `span`.

| Block | Parameters (default) |
| --- | --- |
| `BeakChatBlock` | `model`*, `authorField`*, `bodyField`*, `timeField`*, `isMineField`, `composeRecord`, `label` (`'Chat'`), `filter` |
| `BeakInboxBlock` | `model`*, `senderField`*, `subjectField`*, `previewField`, `timeField`, `unreadField`, `readField`, `folderRelation`, `folderLabelField`, `folders` (`['Inbox']`), `label` (`'Inbox'`), `leftWidthInPixels` (220), `rightWidthInPixels` (360), `filter` |
| `BeakFileManagerBlock` | `model`*, `nameField`*, `isFolderField`, `sizeField`, `modifiedField`, `thumbnailField`, `label` (`'Files'`), `onOpen`, `filter` |
| `BeakThreePaneBlock` | `label`*, `left`*, `middle`*, `right`, `leftWidthInPixels` (260), `rightWidthInPixels` (320) |
| `BeakCarouselBlock` | `query`*, `imageUrlField`*, `captionField`, `heightInPixels` (320), `autoplay` (true) |
| `BeakGalleryBlock` | `query`*, `imageUrlField`*, `captionField`, `columns` (4) |
| `BeakVideoBlock` | `query`*, `urlField`*, `posterField`, `title`, `autoPlay` (false), `loop` (false) |
| `BeakProfileBlock` | `model`*, `recordId`*, `nameField`*, `emailField`, `roleField`, `avatarField`, `bioField`, `label` (`'Profile'`) |
| `BeakInvoiceBlock` | `model`*, `recordId`*, `lineItemsModel`*, `totalField`*, `logoField`, `fromFields`, `toFields`, `metaFields`, `toRelation`, `toPartyFields`, `lineItemsForeignKey`, `subtotalField`, `discountField`, `shippingField`, `taxField`, `title` (`'Invoice'`) |
| `BeakPricingBlock` | `model`*, `nameField`*, `priceField`*, `yearlyPriceField`, `featuredField`, `descriptionField`, `ctaField`, `featuresRelation`, `featureLabelField`, `sortField`, `label` (`'Pricing'`), `currencySymbol` (`$`), `filter` |
| `BeakFaqBlock` | `model`*, `questionField`*, `answerField`*, `categoryField`, `sortField`, `label` (`'Help'`), `filter` |

Every block class with its constructor is on [Blocks](../reference/blocks.md).

## Continue reading

- [Charts](charts.md) the query-bound blocks that draw numbers instead of media.
- [Record blocks](record-blocks.md) read a record from a scope instead of loading it by id.
- [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) when a module needs one more behavior than its parameters allow.
- [Showcase](../examples/showcase.md) the Aviary, which builds every block on this page.
