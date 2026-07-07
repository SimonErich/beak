part of 'beak_block.dart';

/// A data-bound inbox: a folder rail, a scrollable message list, and a
/// detail pane bound to the selected row — composed from
/// `OiThreeColumnLayout`, `OiListView`, and `OiListTile`.
///
/// [folders] labels the left rail. Each record is one message row:
/// [senderField] and [subjectField] head it, [previewField] and [timeField]
/// trail it, and [unreadField] (when bound) marks it unread. Selecting a row
/// fills the right pane with that record's fields; selection is local widget
/// state.
///
/// ```dart
/// BeakInboxBlock(
///   model: const MailModel(),
///   senderField: MailColumns.sender,
///   subjectField: MailColumns.subject,
///   previewField: MailColumns.preview,
///   timeField: MailColumns.receivedAt,
///   unreadField: MailColumns.unread,
///   folders: ['Inbox', 'Sent', 'Archive'],
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
    this.folders = const ['Inbox'],
    this.label = 'Inbox',
    this.leftWidthInPixels = 220,
    this.rightWidthInPixels = 360,
    super.span,
  });

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

  /// Boolean column marking unread rows, when bound.
  final BeakColumn? unreadField;

  /// The folder labels shown in the left rail.
  final List<String> folders;

  /// Accessibility label for the layout.
  final String label;

  /// Initial width of the folder rail.
  final double leftWidthInPixels;

  /// Initial width of the detail pane.
  final double rightWidthInPixels;
}
