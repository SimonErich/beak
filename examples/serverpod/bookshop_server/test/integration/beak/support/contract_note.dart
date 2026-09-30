/// A throwaway soft-deleting model and table for Beak's data-source contract.
///
/// `runBeakDataSourceContract` probes with text ids (`'no-such-id'`), which
/// Serverpod's serial `author` and `book` ids cannot take, so the contract
/// runs on its own table, created and dropped through the test DDL shim.
library;

import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

/// Columns of [ContractNoteModel].
abstract final class ContractNoteColumns {
  /// Text primary key.
  static const BeakStringColumn id = BeakStringColumn(key: 'id', label: 'Id');

  /// Sortable, searchable title.
  static const BeakStringColumn title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Numeric column for sum and average.
  static const BeakIntColumn rating = BeakIntColumn(
    key: 'rating',
    label: 'Rating',
    rules: [BeakMin(1), BeakMax(5)],
  );

  /// A flag.
  static const BeakBoolColumn published = BeakBoolColumn(
    key: 'published',
    label: 'Published',
  );

  /// A timestamp.
  static const BeakDateTimeColumn postedAt = BeakDateTimeColumn(
    key: 'posted_at',
    label: 'Posted at',
  );
}

/// A soft-deleting Beak model over the throwaway `contract_note` table.
final class ContractNoteModel extends BeakModel {
  /// Creates the model.
  const ContractNoteModel();

  @override
  String get table => 'contract_note';

  @override
  String get displayColumnKey => 'title';

  @override
  bool get softDeletes => true;

  @override
  List<BeakColumn> get columns => const [
    ContractNoteColumns.id,
    ContractNoteColumns.title,
    ContractNoteColumns.rating,
    ContractNoteColumns.published,
    ContractNoteColumns.postedAt,
  ];
}

/// `contract_note` as worm DDL. `deleted_at` is `WormDataSource`'s
/// soft-delete column.
const List<SchemaDescriptor> contractNoteSchema = [
  SchemaDescriptor.dropTable(table: 'contract_note', ifExists: true),
  SchemaDescriptor.createTable(
    table: 'contract_note',
    columns: [
      SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
      SchemaColumn(name: 'title', type: ColumnType.text),
      SchemaColumn(name: 'rating', type: ColumnType.integer),
      SchemaColumn(name: 'published', type: ColumnType.boolean),
      SchemaColumn(name: 'posted_at', type: ColumnType.dateTime),
      SchemaColumn(
        name: 'deleted_at',
        type: ColumnType.dateTime,
        nullable: true,
      ),
    ],
  ),
];
