import 'package:beak_core/beak_core.dart';

import '../shared/enums.dart';
import '../shared/shared_columns.dart';

/// Typed columns of the cards resource — kanban cards.
abstract final class CardColumns {
  /// The owning column.
  static const columnId = BeakStringColumn(
    key: 'column_id',
    label: 'Column',
    visibleOn: {BeakContext.form},
  );

  /// Card title.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(200)],
  );

  /// Card description.
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Due date.
  static const dueDate = BeakDateTimeColumn(
    key: 'due_date',
    label: 'Due',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// Priority, shown as a colored badge.
  static const priority = BeakEnumColumn<Priority>(
    key: 'priority',
    label: 'Priority',
    values: Priority.values,
    defaultValue: Priority.medium,
    filterable: true,
    badgeColors: {
      Priority.low: BeakColor.muted,
      Priority.medium: BeakColor.info,
      Priority.high: BeakColor.warning,
      Priority.urgent: BeakColor.error,
    },
  );

  /// Optional cover image.
  static const coverImage = BeakImageColumn(
    key: 'cover_image',
    label: 'Cover',
    storagePath: 'kanban/covers',
    maxSizeInBytes: 5 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Vertical ordering within a column.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// Denormalized attachment count.
  static const attachmentsCount = BeakIntColumn(
    key: 'attachments_count',
    label: 'Attachments',
    min: 0,
    visibleOn: {BeakContext.detail},
  );

  /// Denormalized comment count.
  static const commentsCount = BeakIntColumn(
    key: 'comments_count',
    label: 'Comments',
    min: 0,
    visibleOn: {BeakContext.detail},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    columnId,
    title,
    description,
    dueDate,
    priority,
    coverImage,
    sortIndex,
    attachmentsCount,
    commentsCount,
  ];
}

/// Typed relationships of the cards resource.
abstract final class CardRelations {
  /// The owning column.
  static const column = BeakBelongsTo(
    key: 'column',
    label: 'Column',
    relatedTable: 'board_columns',
    displayColumnKey: 'name',
    foreignKey: 'column_id',
    searchColumnKeys: ['name'],
  );

  /// The card's labels, via the `card_card_label` pivot.
  static const labels = BeakBelongsToMany(
    key: 'labels',
    label: 'Labels',
    relatedTable: 'card_labels',
    displayColumnKey: 'name',
    pivotTable: 'card_card_label',
    foreignPivotKey: 'card_id',
    relatedPivotKey: 'card_label_id',
    searchColumnKeys: ['name'],
  );

  /// The assigned members, via the `card_user` pivot.
  static const members = BeakBelongsToMany(
    key: 'members',
    label: 'Members',
    relatedTable: 'users',
    displayColumnKey: 'name',
    pivotTable: 'card_user',
    foreignPivotKey: 'card_id',
    relatedPivotKey: 'user_id',
    searchColumnKeys: ['name'],
  );
}

/// The cards resource — a kanban card.
final class CardModel extends BeakModel {
  /// Creates the cards model.
  const CardModel();

  @override
  String get table => 'cards';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => CardColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    CardRelations.column,
    CardRelations.labels,
    CardRelations.members,
  ];
}
