import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../resources/assets/models/asset.dart';
import '../resources/faqs/models/faq.dart';
import '../resources/invoices/models/invoice.dart';
import '../resources/invoices/models/invoice_item.dart';
import '../resources/keepers/models/keeper.dart';
import '../resources/messages/models/message.dart';
import '../resources/plans/models/plan.dart';
import '../resources/plans/models/plan_perk.dart';
import '../seeders/aviary_ids.dart';
import 'chart_data.dart';

/// A chat thread built from messages; the composer saves what is typed.
BeakScreen chatPage() => BeakScreen(
  path: '/chat',
  title: 'Chat',
  icon: const BeakIconToken(OiIcons.messageCircle),
  navigationGroup: 'Modules',
  framed: false,
  body: _chat(),
);

/// A three-pane mailbox over the same messages.
BeakScreen inboxPage() => BeakScreen(
  path: '/inbox',
  title: 'Inbox',
  icon: const BeakIconToken(OiIcons.mail),
  navigationGroup: 'Modules',
  framed: false,
  body: _inbox(),
);

/// A file manager between two tables, in a three-pane layout.
BeakScreen filesPage() => BeakScreen(
  path: '/files',
  title: 'Files',
  icon: const BeakIconToken(OiIcons.folder),
  navigationGroup: 'Modules',
  framed: false,
  body: _files(),
);

/// A carousel, a gallery and a video, each over a slice of the assets.
BeakScreen mediaPage() => BeakScreen(
  path: '/media',
  title: 'Media',
  icon: const BeakIconToken(OiIcons.images),
  navigationGroup: 'Modules',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [_carousel(), _gallery(), _video()],
  ),
);

/// A profile, an invoice and pricing plans, each over its own model.
BeakScreen documentsPage() => BeakScreen(
  path: '/documents',
  title: 'Documents',
  icon: const BeakIconToken(OiIcons.fileText),
  navigationGroup: 'Modules',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [_profile(), _invoice(), _pricing()],
  ),
);

/// A help center: it fills the height it is given, so the page is unframed.
// --8<-- [start:faqPage]
BeakScreen faqPage() => BeakScreen(
  path: '/faq',
  title: 'FAQ',
  icon: const BeakIconToken(OiIcons.circleHelp),
  navigationGroup: 'Modules',
  framed: false,
  body: _faq(),
);
// --8<-- [end:faqPage]

/// The chat block.
// --8<-- [start:chat]
BeakBlock _chat() => BeakChatBlock(
  model: const MessageModel(),
  authorField: MessageModel.sender.column,
  bodyField: MessageModel.body.column,
  timeField: MessageModel.sentAt.column,
  isMineField: MessageModel.isMine.column,
  composeRecord: (String body) => const MessageModel().record([
    MessageModel.sender.to('You'),
    MessageModel.subject.to('Chat'),
    MessageModel.body.to(body),
    MessageModel.sentAt.to(DateTime.now().toUtc()),
    MessageModel.isMine.to(true),
    MessageModel.isRead.to(true),
  ]),
);
// --8<-- [end:chat]

/// The inbox block.
// --8<-- [start:inbox]
BeakBlock _inbox() => BeakInboxBlock(
  model: const MessageModel(),
  senderField: MessageModel.sender.column,
  subjectField: MessageModel.subject.column,
  previewField: MessageModel.body.column,
  timeField: MessageModel.sentAt.column,
  readField: MessageModel.isRead.column,
);
// --8<-- [end:inbox]

/// The file manager and its neighbours.
// --8<-- [start:files]
BeakBlock _files() => BeakThreePaneBlock(
  label: 'Asset library',
  leftWidthInPixels: 260,
  rightWidthInPixels: 320,
  left: BeakTableBlock(
    title: 'Collections',
    model: const AssetModel(),
    fields: [AssetModel.collection],
    enableDelete: false,
    heightInPixels: 640,
  ),
  middle: BeakFileManagerBlock(
    label: 'Files',
    model: const AssetModel(),
    nameField: AssetModel.name.column,
    isFolderField: AssetModel.isFolder.column,
    sizeField: AssetModel.sizeInBytes.column,
    modifiedField: AssetModel.modifiedAt.column,
  ),
  right: BeakTableBlock(
    title: 'Keepers',
    model: const KeeperModel(),
    fields: [KeeperModel.name, KeeperModel.role],
    enableDelete: false,
    heightInPixels: 640,
  ),
);
// --8<-- [end:files]

BeakQuerySpec _assets(AssetCollection collection) => const AssetModel().query(
  filter: AssetModel.collection.eq(collection),
  sorts: [AssetModel.position.ascending()],
  pagination: chartPage,
);

/// A carousel over the assets tagged `carousel`.
// --8<-- [start:carousel]
BeakBlock _carousel() => BeakCardBlock(
  title: 'Carousel',
  child: BeakCarouselBlock(
    query: _assets(AssetCollection.carousel),
    imageUrlField: AssetModel.url.column,
    captionField: AssetModel.caption.column,
    autoplay: false,
  ),
);
// --8<-- [end:carousel]

/// A gallery with a lightbox over the assets tagged `gallery`.
// --8<-- [start:gallery]
BeakBlock _gallery() => BeakCardBlock(
  title: 'Gallery',
  child: BeakGalleryBlock(
    query: _assets(AssetCollection.gallery),
    imageUrlField: AssetModel.url.column,
    captionField: AssetModel.name.column,
    columns: 4,
  ),
);
// --8<-- [end:gallery]

/// A video player over the assets tagged `video`.
// --8<-- [start:video]
BeakBlock _video() => BeakCardBlock(
  title: 'Video',
  child: BeakVideoBlock(
    title: 'Morning chorus',
    query: _assets(AssetCollection.video),
    urlField: AssetModel.url.column,
  ),
);
// --8<-- [end:video]

/// A profile card for one keeper.
// --8<-- [start:profile]
BeakBlock _profile() => BeakProfileBlock(
  model: const KeeperModel(),
  recordId: AviaryIds.ada,
  nameField: KeeperModel.name.column,
  emailField: KeeperModel.email.column,
  roleField: KeeperModel.role.column,
  avatarField: KeeperModel.avatar.column,
  bioField: KeeperModel.bio.column,
);
// --8<-- [end:profile]

/// An invoice with lines, a bill-to party and totals.
// --8<-- [start:invoice]
BeakBlock _invoice() => BeakInvoiceBlock(
  model: const InvoiceModel(),
  recordId: AviaryIds.invoice,
  lineItemsModel: const InvoiceItemModel(),
  lineItemsForeignKey: InvoiceItemModel.invoiceId.column,
  totalField: InvoiceModel.total.column,
  fromFields: [InvoiceModel.supplier.column],
  metaFields: [
    InvoiceModel.number.column,
    InvoiceModel.status.column,
    InvoiceModel.issuedOn.column,
    InvoiceModel.dueOn.column,
  ],
  toRelation: InvoiceRelations.orderedBy,
  toPartyFields: [KeeperModel.name.column, KeeperModel.email.column],
  subtotalField: InvoiceModel.subtotal.column,
  discountField: InvoiceModel.discount.column,
  shippingField: InvoiceModel.shipping.column,
  taxField: InvoiceModel.tax.column,
  title: 'Feed invoice',
);
// --8<-- [end:invoice]

/// Plan cards with a feature list and a highlighted plan.
// --8<-- [start:pricing]
BeakBlock _pricing() => BeakPricingBlock(
  model: const PlanModel(),
  nameField: PlanModel.name.column,
  priceField: PlanModel.monthlyPrice.column,
  yearlyPriceField: PlanModel.yearlyPrice.column,
  featuredField: PlanModel.featured.column,
  descriptionField: PlanModel.tagline.column,
  featuresRelation: PlanModel.perks.relation,
  featureLabelField: PlanPerkModel.label.column,
  currencySymbol: '€',
  label: 'Sponsor a bird',
);
// --8<-- [end:pricing]

/// A searchable, categorised question list.
// --8<-- [start:faq]
BeakBlock _faq() => BeakFaqBlock(
  model: const FaqModel(),
  questionField: FaqModel.question.column,
  answerField: FaqModel.answer.column,
  categoryField: FaqModel.category.column,
  sortField: FaqModel.position.column,
  label: 'Visiting the aviary',
);
// --8<-- [end:faq]
