import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'message.beak.dart';

/// A note between keepers, read as a chat thread and as a mailbox.
@Resource()
final class Message extends BeakSchema {
  /// Who wrote it.
  @Display()
  @Column(searchable: true)
  late final String sender;

  /// The subject line (the inbox lists it).
  late final String subject;

  /// The message text.
  late final BeakText body;

  /// When it was sent.
  @Column(sortable: true)
  late final DateTime sentAt;

  /// Whether the signed-in keeper wrote it (which side the chat bubble is on).
  late final bool isMine;

  /// Whether it has been opened.
  late final bool isRead;
}
