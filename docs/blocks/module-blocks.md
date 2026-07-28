---
title: Module blocks
description: The nine app-sized blocks (chat, inbox, file manager, invoice, gallery, profile, pricing, FAQ, and wizard), each with its constructor and the demo screen that uses it.
---

# Module blocks

After this page you can drop a whole feature onto a screen with one block: a chat
thread, an inbox, a file manager, an invoice document, a gallery, a profile page,
a pricing table, an FAQ, or a multi-step wizard. These are the largest blocks
Beak ships, and most of them are data-bound: they resolve the panel's data source
and fetch their own records, bound to your model by typed `BeakColumn`, never by
string.

Most of the modules below have a demo in the showcase app
(`examples/superdashboard`, port 8180), built from real seeded data. Each demo is
one file under `lib/screens/` declaring a `BeakScreen`, which `beak prepare`
discovers, routes, and files in the sidebar. The file manager and the wizard have
no showcase screen, so their examples are the ones in the block's own dartdoc. If
a demo uses different model constants than another, that is expected: the
showcase has 49 models.

| Module | Block | Renders onto |
| --- | --- | --- |
| Chat | `BeakChatBlock` | `OiChat` |
| Inbox | `BeakInboxBlock` | `OiThreeColumnLayout` |
| File manager | `BeakFileManagerBlock` | `OiFileManager` |
| Invoice | `BeakInvoiceBlock` | composed (`OiImage`, `OiKeyValue`, a table) |
| Gallery | `BeakGalleryBlock` | `OiGallery` |
| Profile | `BeakProfileBlock` | `OiProfilePage` |
| Pricing | `BeakPricingBlock` | `OiPricingTable` |
| FAQ | `BeakFaqBlock` | `OiHelpCenter` |
| Wizard | `BeakWizardBlock` | `OiWizard` |

## Chat

`BeakChatBlock` renders a model's records as message bubbles, ordered by
`timeField`. When `composeRecord` is bound, the block shows a composer and
persists sent messages back through the data source.

```dart title="packages/beak_frontend/lib/src/blocks/beak_chat_block.dart"
const BeakChatBlock({
  required this.model,
  required this.authorField,
  required this.bodyField,
  required this.timeField,
  this.isMineField,
  this.composeRecord,
  this.label = 'Chat',
  super.span,
});
```

```dart title="examples/superdashboard/lib/screens/chat_screen.dart"
--8<-- "examples/superdashboard/lib/screens/chat_screen.dart:buildChatScreen"
```

`_composeMessage` builds the `BeakRecord` a new message needs (the sender,
the timestamp, the defaults), so a sent message survives a reload:

```dart title="examples/superdashboard/lib/screens/chat_screen.dart"
/// Builds the record persisted when the demo user sends [body] from the
/// chat composer.
BeakRecord _composeMessage(String body) => BeakRecord.fromRow({
  'sender_name': 'You',
  'body': body,
  'sent_at': DateTime.now().toUtc(),
  'is_read': true,
});
```

## Inbox

`BeakInboxBlock` is a three-pane mailbox: a folder rail, a message list, and a
detail pane bound to the selected row. Bind `folderRelation` and
`folderLabelField` and the rail is built from the data, and selecting a folder
filters the list.

```dart title="packages/beak_frontend/lib/src/blocks/beak_inbox_block.dart"
const BeakInboxBlock({
  required this.model,
  required this.senderField,
  required this.subjectField,
  this.previewField,
  this.timeField,
  this.unreadField,
  this.readField,
  this.folderRelation,
  this.folderLabelField,
  this.folders = const ['Inbox'],
  this.label = 'Inbox',
  this.leftWidthInPixels = 220,
  this.rightWidthInPixels = 360,
  super.span,
}) : assert(
       unreadField == null || readField == null,
       'Bind unreadField (true = unread) or readField (true = read), '
       'not both.',
     );
```

```dart title="examples/superdashboard/lib/screens/email_screen.dart"
body: BeakInboxBlock(
  model: EmailModel(),
  senderField: EmailColumns.senderName,
  subjectField: EmailColumns.subject,
  previewField: EmailColumns.preview,
  timeField: EmailColumns.sentAt,
  readField: EmailColumns.isRead,
  folderRelation: EmailRelations.folder,
  folderLabelField: MailFolderColumns.label,
  folders: ['Inbox', 'Starred', 'Sent', 'Drafts', 'Spam', 'Trash'],
),
```

!!! warning "unreadField or readField, not both"
    Models store one or the other. The constructor asserts you bind at most one:
    `unreadField` is `true` on unread rows, `readField` is `true` on read rows.
    The email demo stores `is_read`, so it binds `readField`.

## File manager

`BeakFileManagerBlock` renders a model's folder and file records on
`OiFileManager`. `nameField` names each entry; `isFolderField` separates
folders from files where a table stores both, and is left unbound for a table
of files only. The size, modified, and thumbnail fields enrich the file rows.

```dart title="packages/beak_frontend/lib/src/blocks/beak_file_manager_block.dart"
const BeakFileManagerBlock({
  required this.model,
  required this.nameField,
  this.isFolderField,
  this.sizeField,
  this.modifiedField,
  this.thumbnailField,
  this.label = 'Files',
  this.onOpen,
  super.span,
});
```

```dart
BeakFileManagerBlock(
  model: const AssetModel(),
  nameField: AssetColumns.name,
  isFolderField: AssetColumns.isFolder,
  sizeField: AssetColumns.sizeInBytes,
  modifiedField: AssetColumns.updatedAt,
  onOpen: (record) => print(record[AssetColumns.name.key]?.raw),
);
```

!!! note "The demo files screen composes tables instead"
    `BeakFileManagerBlock` fits a single folders-and-files table. The showcase's
    Files screen has a two-table schema (folders, files) plus a connected
    cloud-storage list, so it composes a `BeakThreePaneBlock` of three
    `BeakTableBlock`s rather than the single-model file manager. Reach for the
    file-manager block when one model holds both folders and files; reach for a
    [three-pane layout](layout-blocks.md) when the shape does not fit.

## Invoice

`BeakInvoiceBlock` composes a printable invoice document: a header with logo and
from/to blocks, a line-items table, and a totals column. obers_ui has no invoice
widget, so this block composes existing pieces (`OiImage`, `OiKeyValue`, and a
reused `BeakTableBlock`) rather than wrapping one.

```dart title="packages/beak_frontend/lib/src/blocks/beak_invoice_block.dart"
const BeakInvoiceBlock({
  required this.model,
  required this.recordId,
  required this.lineItemsModel,
  required this.totalField,
  this.logoField,
  this.fromFields = const [],
  this.toFields = const [],
  this.metaFields = const [],
  this.toRelation,
  this.toPartyFields = const [],
  this.lineItemsForeignKey,
  this.subtotalField,
  this.discountField,
  this.shippingField,
  this.taxField,
  this.title = 'Invoice',
  super.span,
});
```

```dart title="examples/superdashboard/lib/screens/invoice_screen.dart"
body: BeakInvoiceBlock(
  model: InvoiceModel(),
  recordId: SeedIds.invoice,
  lineItemsModel: InvoiceItemModel(),
  lineItemsForeignKey: InvoiceItemColumns.invoiceId,
  metaFields: [
    InvoiceColumns.number,
    InvoiceColumns.status,
    InvoiceColumns.issueDate,
    InvoiceColumns.dueDate,
  ],
  toRelation: InvoiceRelations.user,
  toPartyFields: [
    UserColumns.name,
    UserColumns.email,
    UserColumns.city,
    UserColumns.country,
  ],
  subtotalField: InvoiceColumns.subtotal,
  discountField: InvoiceColumns.discount,
  shippingField: InvoiceColumns.shipping,
  taxField: InvoiceColumns.tax,
  totalField: InvoiceColumns.total,
),
```

The "To" block reads the billed party's fields through a belongs-to relation
(`toRelation` + `toPartyFields`), and `lineItemsForeignKey` scopes the itemized
table to this one invoice.

## Gallery

`BeakGalleryBlock` renders one thumbnail per row of a query. It takes a
`BeakQuerySpec` directly, so you filter and sort the images with the same query
spec every data block speaks.

```dart title="packages/beak_frontend/lib/src/blocks/beak_gallery_block.dart"
const BeakGalleryBlock({
  required this.query,
  required this.imageUrlField,
  this.captionField,
  this.columns = 4,
  super.span,
});
```

```dart title="examples/superdashboard/lib/screens/gallery_screen.dart"
child: BeakGalleryBlock(
  query: BeakQuerySpec(
    table: 'media_assets',
    filter: _inCollection(MediaCollection.gallery),
    sorts: const [BeakSort('sort_index')],
  ),
  imageUrlField: MediaAssetColumns.url,
  captionField: MediaAssetColumns.title,
),
```

## Profile

`BeakProfileBlock` renders one record's identity fields on `OiProfilePage`:
a name headline, a role subtitle, an avatar URL, and the email and bio fields.

```dart title="packages/beak_frontend/lib/src/blocks/beak_profile_block.dart"
const BeakProfileBlock({
  required this.model,
  required this.recordId,
  required this.nameField,
  this.emailField,
  this.roleField,
  this.avatarField,
  this.bioField,
  this.label = 'Profile',
  super.span,
});
```

```dart title="examples/superdashboard/lib/screens/profile_screen.dart"
body: BeakProfileBlock(
  model: UserModel(),
  recordId: SeedIds.userAisha,
  nameField: UserColumns.name,
  emailField: UserColumns.email,
  roleField: UserColumns.role,
  avatarField: UserColumns.avatar,
  bioField: UserColumns.bio,
),
```

## Pricing

`BeakPricingBlock` renders a plans model on `OiPricingTable`. Bind
`featuresRelation` and `featureLabelField` and each plan's eager-loaded feature
records become its bullet list; `featuredField` flags the recommended plan.

```dart title="packages/beak_frontend/lib/src/blocks/beak_pricing_block.dart"
const BeakPricingBlock({
  required this.model,
  required this.nameField,
  required this.priceField,
  this.yearlyPriceField,
  this.featuredField,
  this.descriptionField,
  this.ctaField,
  this.featuresRelation,
  this.featureLabelField,
  this.sortField,
  this.label = 'Pricing',
  this.currencySymbol = r'$',
  super.span,
});
```

```dart title="examples/superdashboard/lib/screens/pricing_screen.dart"
body: BeakPricingBlock(
  model: PricingPlanModel(),
  nameField: PricingPlanColumns.name,
  priceField: PricingPlanColumns.monthlyPrice,
  yearlyPriceField: PricingPlanColumns.yearlyPrice,
  featuredField: PricingPlanColumns.featured,
  descriptionField: PricingPlanColumns.tagline,
  featuresRelation: PricingPlanRelations.features,
  featureLabelField: PlanFeatureColumns.label,
),
```

## FAQ

`BeakFaqBlock` renders a model's records on `OiHelpCenter`, which adds built-in
search and category grouping over the question/answer pairs. Bind `categoryField`
to group entries.

```dart title="packages/beak_frontend/lib/src/blocks/beak_faq_block.dart"
const BeakFaqBlock({
  required this.model,
  required this.questionField,
  required this.answerField,
  this.categoryField,
  this.sortField,
  this.label = 'Help',
  super.span,
});
```

```dart title="examples/superdashboard/lib/screens/faq_screen.dart"
body: BeakFaqBlock(
  model: FaqModel(),
  questionField: FaqColumns.question,
  answerField: FaqColumns.answer,
),
```

## Wizard

`BeakWizardBlock` paces a long flow across steps, each showing a block body
behind a step indicator, with next/previous navigation and optional per-step
gating. Unlike a single-page form, it is meant for a multi-part flow (seller
details, then documents, then bank, then confirm).

```dart title="packages/beak_frontend/lib/src/blocks/beak_wizard_block.dart"
const BeakWizardBlock({
  required this.steps,
  this.stepperStyle = OiStepperStyle.horizontal,
  this.onComplete,
  super.span,
});
```

Each step is a `BeakWizardStep`, whose `body` is an ordinary block and whose
`canAdvance` gate can block Next until the step validates:

```dart title="packages/beak_frontend/lib/src/blocks/beak_wizard_block.dart"
const BeakWizardStep({
  required this.title,
  required this.body,
  this.subtitle,
  this.icon,
  this.canAdvance,
});
```

```dart
BeakWizardBlock(
  onComplete: submitApplication,
  steps: [
    BeakWizardStep(title: 'Seller', body: sellerFields),
    BeakWizardStep(title: 'Bank', body: bankFields),
    BeakWizardStep(title: 'Confirm', body: reviewSummary),
  ],
);
```

!!! question "Wizard block or multi-step form"
    A `BeakWizardBlock` is free-form: the step bodies are any blocks, and you
    collect their values in your own signals and read them in `onComplete`. When
    each step is a set of a resource's fields and you want Beak to build,
    validate, and save the record for you, set `formSteps` on the resource in
    `lib/resources/<table>.dart` instead. The showcase's calendar events do
    that. See [Multi-step forms](../panel/multi-step-forms.md).

## Continue reading

- [Data blocks](data-blocks.md) the smaller data-bound blocks (KPI, table, calendar, kanban) these modules build on.
- [Custom screens](../panel/custom-screens.md) how a `BeakScreen` hosts a module block as a page in the nav.
- [Multi-step forms](../panel/multi-step-forms.md) the resource-driven cousin of the wizard block.
- [Layout blocks](layout-blocks.md) the three-pane and card blocks the file-manager and invoice demos compose with.
