part of 'beak_block.dart';

/// A data-bound inbox: a folder rail, a scrollable message list, and a
/// detail pane bound to the selected row — composed from
/// `OiThreeColumnLayout`, `OiListView`, and `OiListTile`.
///
/// The left rail: bind [folderRelation] + [folderLabelField] and the rail is
/// built from the data — one entry per distinct related folder label, and
/// selecting one filters the list to that folder's rows. Without the
/// relation, [folders] labels a static (non-filtering) rail.
///
/// Each record is one message row: [senderField] and [subjectField] head it,
/// [previewField] and [timeField] trail it, and rows are marked unread when
/// [unreadField] is `true` (or [readField] is `false` — bind whichever your
/// model stores, not both). Selecting a row fills the right pane; selection
/// is local widget state.
///
/// ```dart
/// BeakInboxBlock(
///   model: const MailModel(),
///   senderField: MailModel.sender.column,
///   subjectField: MailModel.subject.column,
///   previewField: MailModel.preview.column,
///   timeField: MailModel.receivedAt.column,
///   readField: MailModel.isRead.column,
///   // The rail needs the typed belongs-to, which the generated
///   // MailRelations keeps; `MailModel.folder.relation` is a plain
///   // BeakRelationship.
///   folderRelation: MailRelations.folder,
///   folderLabelField: FolderModel.label.column,
/// );
/// ```
final class BeakInboxBlock extends BeakBlock {
  /// Creates an inbox block over [model].
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

  /// The model whose records become message rows.
  final BeakModel model;

  /// Column supplying each row's sender.
  final BeakColumn senderField;

  /// Column supplying each row's subject.
  final BeakColumn subjectField;

  /// Column supplying each row's preview snippet, when bound.
  final BeakColumn? previewField;

  /// Column supplying each row's received time, when bound.
  final BeakColumn? timeField;

  /// Boolean column that is `true` on unread rows, when bound.
  final BeakColumn? unreadField;

  /// Boolean column that is `true` on read rows, when bound — the inverse
  /// convention of [unreadField], for models that store `is_read`.
  final BeakColumn? readField;

  /// The belongs-to relation from a message to its folder; when bound (with
  /// [folderLabelField]) the rail is data-driven and filters the list.
  final BeakBelongsTo? folderRelation;

  /// The related folder model's label column backing the rail entries.
  final BeakColumn? folderLabelField;

  /// The folder labels shown in the left rail when [folderRelation] is
  /// unbound (static, non-filtering) — or, when it is bound, the preferred
  /// ordering of the data-driven rail.
  final List<String> folders;

  /// Accessibility label for the layout.
  final String label;

  /// Initial width of the folder rail.
  final double leftWidthInPixels;

  /// Initial width of the detail pane.
  final double rightWidthInPixels;
}
