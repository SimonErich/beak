import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../shared/enums.dart';
import 'chat_message.dart';

part 'chat_attachment.beak.dart';

/// The chat-attachments resource — a file on a chat message.
@Resource()
final class ChatAttachment extends BeakSchema {
  /// The owning message.
  @BelongsTo()
  late final ChatMessage? message;

  /// File name.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(160)])
  late final String name;

  /// File kind.
  @Column(filterable: true, defaultValue: AttachmentKind.image)
  @Badges({
    AttachmentKind.image: BeakColor.success,
    AttachmentKind.document: BeakColor.primary,
    AttachmentKind.pdf: BeakColor.error,
    AttachmentKind.video: BeakColor.info,
    AttachmentKind.audio: BeakColor.warning,
    AttachmentKind.archive: BeakColor.muted,
    AttachmentKind.spreadsheet: BeakColor.success,
    AttachmentKind.code: BeakColor.secondary,
  })
  late final AttachmentKind? kind;

  /// File size in bytes.
  @Column(min: 0, sortable: true)
  late final int? size;

  /// The stored file.
  @FileField(storagePath: 'chat/files')
  @Column(columnName: 'url')
  late final BeakFileRef? file;
}
