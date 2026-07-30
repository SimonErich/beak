import 'package:superdashboard/models/models.dart';
import 'package:beak/migrations.dart';

/// Creates the Chat domain: conversations, memberships, messages, and
/// attachments.
final class CreateChatTables extends Migration {
  /// Creates the migration.
  const CreateChatTables();

  @override
  String get name => '20260707_000500_create_chat_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create(
      'conversations',
      (table) => BeakBlueprint.defineColumns(table, const ConversationModel()),
    );
    await schema.create('chat_messages', (table) {
      BeakBlueprint.defineColumns(table, const ChatMessageModel());
      table.index(['conversation_id']);
      table.foreign(
        column: 'conversation_id',
        references: 'id',
        onTable: 'conversations',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'sender_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create('conversation_participants', (table) {
      BeakBlueprint.defineColumns(table, const ConversationParticipantModel());
      table.unique(['conversation_id', 'user_id']);
      table.foreign(
        column: 'conversation_id',
        references: 'id',
        onTable: 'conversations',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create('chat_attachments', (table) {
      BeakBlueprint.defineColumns(table, const ChatAttachmentModel());
      table.foreign(
        column: 'message_id',
        references: 'id',
        onTable: 'chat_messages',
        onDelete: OnDelete.cascade,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'chat_attachments',
      'conversation_participants',
      'chat_messages',
      'conversations',
    ]) {
      await schema.drop(table, ifExists: true);
    }
  }
}
