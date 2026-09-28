part of 'beak_block.dart';

/// A data-bound chat transcript: a model's records rendered as message
/// bubbles on `OiChat`, ordered by [timeField].
///
/// [authorField] names the sender, [bodyField] is the message text, and
/// [timeField] both orders and timestamps the bubbles. When [isMineField] is
/// bound, records where it is `true` sit on the outgoing (right) side; every
/// other record sits on the incoming (left) side.
///
/// ```dart
/// BeakChatBlock(
///   model: const MessageModel(),
///   authorField: MessageModel.author.column,
///   bodyField: MessageModel.body.column,
///   timeField: MessageModel.sentAt.column,
///   isMineField: MessageModel.fromMe.column,
/// );
/// ```
final class BeakChatBlock extends BeakBlock {
  /// Creates a chat block over [model].
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

  /// The model whose records become messages.
  final BeakModel model;

  /// Column supplying each message's author name.
  final BeakColumn authorField;

  /// Column supplying each message's body text.
  final BeakColumn bodyField;

  /// Column supplying each message's timestamp; also the sort key.
  final BeakColumn timeField;

  /// Boolean column marking outgoing (own) messages, when bound.
  final BeakColumn? isMineField;

  /// Builds the record persisted when the user sends [body] from the
  /// composer — fill in the FKs and defaults a new message needs. When
  /// unbound the transcript is read-only and no composer is shown.
  final BeakRecord Function(String body)? composeRecord;

  /// Accessibility label for the transcript.
  final String label;
}
