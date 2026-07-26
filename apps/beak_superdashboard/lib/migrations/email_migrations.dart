import 'package:beak_backend/beak_backend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:worm/worm.dart';

/// Creates the Email domain: folders, labels, messages, and attachments.
final class CreateEmailTables extends Migration {
  /// Creates the migration.
  const CreateEmailTables();

  @override
  String get name => '20260707_000400_create_email_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create(
      'mail_folders',
      (table) => BeakBlueprint.defineColumns(table, const MailFolderModel()),
    );
    await schema.create(
      'mail_labels',
      (table) => BeakBlueprint.defineColumns(table, const MailLabelModel()),
    );
    await schema.create('emails', (table) {
      BeakBlueprint.defineColumns(table, const EmailModel());
      table.index(['folder_id']);
      table.index(['is_read']);
      table.foreign(
        column: 'folder_id',
        references: 'id',
        onTable: 'mail_folders',
        onDelete: OnDelete.setNull,
      );
      table.foreign(
        column: 'sender_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create('email_attachments', (table) {
      BeakBlueprint.defineColumns(table, const EmailAttachmentModel());
      table.foreign(
        column: 'email_id',
        references: 'id',
        onTable: 'emails',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create(
      'email_mail_label',
      (table) => BeakBlueprint.definePivot(
        table,
        leftColumn: 'email_id',
        leftTable: 'emails',
        rightColumn: 'mail_label_id',
        rightTable: 'mail_labels',
      ),
    );
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'email_mail_label',
      'email_attachments',
      'emails',
      'mail_labels',
      'mail_folders',
    ]) {
      await schema.drop(table, ifExists: true);
    }
  }
}
