import 'package:beak_core/beak_core.dart';

import '../shared/enums.dart';
import '../shared/shared_columns.dart';

/// Typed columns of the chat-attachments resource.
abstract final class ChatAttachmentColumns {
  /// The owning message.
  static const messageId = BeakStringColumn(
    key: 'message_id',
    label: 'Message',
    visibleOn: {BeakContext.form},
  );

  /// File name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  /// File kind.
  static const kind = BeakEnumColumn<AttachmentKind>(
    key: 'kind',
    label: 'Kind',
    values: AttachmentKind.values,
    defaultValue: AttachmentKind.image,
    filterable: true,
    badgeColors: {
      AttachmentKind.image: BeakColor.success,
      AttachmentKind.document: BeakColor.primary,
      AttachmentKind.pdf: BeakColor.error,
      AttachmentKind.video: BeakColor.info,
      AttachmentKind.audio: BeakColor.warning,
      AttachmentKind.archive: BeakColor.muted,
      AttachmentKind.spreadsheet: BeakColor.success,
      AttachmentKind.code: BeakColor.secondary,
    },
  );

  /// File size in bytes.
  static const size = BeakIntColumn(
    key: 'size',
    label: 'Size',
    min: 0,
    sortable: true,
  );

  /// The stored file.
  static const file = BeakFileColumn(
    key: 'url',
    label: 'File',
    storagePath: 'chat/files',
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    messageId,
    name,
    kind,
    size,
    file,
  ];
}

/// Typed relationships of the chat-attachments resource.
abstract final class ChatAttachmentRelations {
  /// The owning message.
  static const message = BeakBelongsTo(
    key: 'message',
    label: 'Message',
    relatedTable: 'chat_messages',
    displayColumnKey: 'body',
    foreignKey: 'message_id',
  );
}

/// The chat-attachments resource — a file on a chat message.
final class ChatAttachmentModel extends BeakModel {
  /// Creates the chat-attachments model.
  const ChatAttachmentModel();

  @override
  String get table => 'chat_attachments';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => ChatAttachmentColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ChatAttachmentRelations.message,
  ];
}
