import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the mail-labels resource.
abstract final class MailLabelColumns {
  /// Label name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Label color.
  static const color = BeakColorColumn(key: 'color', label: 'Color');

  /// All columns, in display order.
  static const List<BeakColumn> values = [SharedColumns.id, name, color];
}

/// Typed relationships of the mail-labels resource.
abstract final class MailLabelRelations {
  /// Emails carrying this label, via the `email_mail_label` pivot.
  static const emails = BeakBelongsToMany(
    key: 'emails',
    label: 'Emails',
    relatedTable: 'emails',
    displayColumnKey: 'subject',
    pivotTable: 'email_mail_label',
    foreignPivotKey: 'mail_label_id',
    relatedPivotKey: 'email_id',
  );
}

/// The mail-labels resource — colored email tags.
final class MailLabelModel extends BeakModel {
  /// Creates the mail-labels model.
  const MailLabelModel();

  @override
  String get table => 'mail_labels';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => MailLabelColumns.values;

  @override
  List<BeakRelationship> get relationships => const [MailLabelRelations.emails];
}
