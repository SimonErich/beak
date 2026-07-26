import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

enum _Status { draft, published }

abstract final class _WidgetColumns {
  static const id = BeakStringColumn(key: 'id', label: 'Id');
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    rules: [BeakRequired(), BeakMaxLength(120)],
  );
  static const summary = BeakTextColumn(key: 'summary', label: 'Summary');
  static const price = BeakDecimalColumn(key: 'price', label: 'Price');
  static const quantity = BeakIntColumn(key: 'quantity', label: 'Quantity');
  static const sizeInBytes = BeakIntColumn(key: 'size_in_bytes', label: 'Size');
  static const active = BeakBoolColumn(key: 'active', label: 'Active');
  static const status = BeakEnumColumn<_Status>(
    key: 'status',
    label: 'Status',
    values: _Status.values,
    defaultValue: _Status.draft,
  );
  static const tint = BeakColorColumn(key: 'tint', label: 'Tint');
  static const cover = BeakImageColumn(
    key: 'cover',
    label: 'Cover',
    storagePath: 'covers',
  );
  static const payload = BeakJsonColumn(key: 'payload', label: 'Payload');
  static const createdAt = BeakDateTimeColumn(key: 'created_at', label: 'C');
  static const ownerId = BeakStringColumn(key: 'owner_id', label: 'Owner');

  static const List<BeakColumn> values = [
    id,
    name,
    summary,
    price,
    quantity,
    sizeInBytes,
    active,
    status,
    tint,
    cover,
    payload,
    createdAt,
    ownerId,
  ];
}

abstract final class _WidgetRelations {
  static const owner = BeakBelongsTo(
    key: 'owner',
    label: 'Owner',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'owner_id',
  );
  static const tags = BeakBelongsToMany(
    key: 'tags',
    label: 'Tags',
    relatedTable: 'tags',
    displayColumnKey: 'name',
    pivotTable: 'widget_tag',
    foreignPivotKey: 'widget_id',
    relatedPivotKey: 'tag_id',
  );
}

final class _WidgetModel extends BeakModel {
  const _WidgetModel({this.softDeleting = true});

  final bool softDeleting;

  @override
  String get table => 'widgets';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => _WidgetColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    _WidgetRelations.owner,
    _WidgetRelations.tags,
  ];

  @override
  bool get softDeletes => softDeleting;
}

/// A soft-deleting model that also declares the marker column, exactly as a
/// generated model does.
final class _SoftDeleteDeclaringModel extends BeakModel {
  const _SoftDeleteDeclaringModel();

  @override
  String get table => 'widgets';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    ..._WidgetColumns.values,
    BeakDateTimeColumn(key: 'deleted_at', label: 'Deleted at'),
  ];

  @override
  bool get softDeletes => true;
}

final class _RestrictedModel extends BeakModel {
  const _RestrictedModel();

  @override
  String get table => 'restricted';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'owner_id', label: 'Owner'),
  ];

  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'owner',
      label: 'Owner',
      relatedTable: 'users',
      displayColumnKey: 'name',
      foreignKey: 'owner_id',
      onDelete: BeakOnDelete.restrict,
    ),
  ];
}

/// Creates the widget↔tag pivot straight from the relationship declaration —
/// exercising [BeakBlueprint.createPivot] through the real migration path.
final class _CreateWidgetTagPivot extends Migration {
  const _CreateWidgetTagPivot();

  @override
  String get name => '20260726_000100_create_widget_tag_table';

  @override
  Future<void> upSchema(Schema schema) => BeakBlueprint.createPivot(
    schema,
    _WidgetRelations.tags,
    ownerTable: const _WidgetModel().table,
  );

  @override
  Future<void> downSchema(Schema schema) =>
      schema.drop(_WidgetRelations.tags.pivotTable, ifExists: true);
}

/// The column named [name] on [table].
ColumnDefinition columnOf(BlueprintTable table, String name) =>
    table.columns.firstWhere((column) => column.name == name);

void main() {
  group('defineColumns', () {
    late BlueprintTable table;

    setUp(() {
      table = BlueprintTable('widgets');
      BeakBlueprint.defineColumns(
        table,
        const _WidgetModel(),
        bigIntColumns: {'size_in_bytes'},
      );
    });

    test('makes the primary key a uuid id', () {
      final id = columnOf(table, 'id');
      expect(id.isPrimaryKey, isTrue);
      expect(id.type, ColumnType.uuid);
    });

    test('maps each column leaf to its schema type', () {
      expect(columnOf(table, 'name').type, ColumnType.string);
      expect(columnOf(table, 'summary').type, ColumnType.text);
      expect(columnOf(table, 'price').type, ColumnType.decimal);
      expect(columnOf(table, 'quantity').type, ColumnType.integer);
      expect(columnOf(table, 'active').type, ColumnType.boolean);
      expect(columnOf(table, 'status').type, ColumnType.string);
      expect(columnOf(table, 'tint').type, ColumnType.string);
      expect(columnOf(table, 'cover').type, ColumnType.string);
      expect(columnOf(table, 'payload').type, ColumnType.json);
      expect(columnOf(table, 'created_at').type, ColumnType.dateTime);
    });

    test('honours bigIntColumns for values above the 32-bit range', () {
      expect(columnOf(table, 'size_in_bytes').type, ColumnType.bigInteger);
      expect(columnOf(table, 'quantity').type, ColumnType.integer);
    });

    test('derives nullability from BeakRequired', () {
      // name carries BeakRequired; summary does not.
      expect(columnOf(table, 'name').nullable, isFalse);
      expect(columnOf(table, 'summary').nullable, isTrue);
    });

    test('defaults booleans to false rather than leaving them nullable', () {
      final active = columnOf(table, 'active');
      expect(active.defaultValue, false);
      expect(active.nullable, isFalse);
    });

    test('bridges an enum default into the schema default', () {
      // Closes the drift surface where a migration restated the model default.
      final status = columnOf(table, 'status');
      expect(status.defaultValue, 'draft');
      expect(status.nullable, isFalse);
    });

    test('lets the migration supply a default the model cannot express', () {
      final withDefault = BlueprintTable('widgets');
      BeakBlueprint.defineColumns(
        withDefault,
        const _WidgetModel(),
        columnDefaults: {'quantity': 0},
      );
      expect(columnOf(withDefault, 'quantity').defaultValue, 0);
      expect(columnOf(withDefault, 'quantity').nullable, isFalse);
    });

    test('makes belongs-to foreign keys nullable uuids', () {
      final owner = columnOf(table, 'owner_id');
      expect(owner.type, ColumnType.uuid);
      expect(owner.nullable, isTrue);
    });

    test('adds a deleted_at column for a soft-deleting model', () {
      expect(
        table.columns.map((column) => column.name),
        contains('deleted_at'),
      );
    });

    test('emits deleted_at once when the model declares it too', () {
      // Every generated model of a soft-deleting resource carries a
      // deleted_at column; naming it again made Postgres reject the table.
      final declaring = BlueprintTable('widgets');
      BeakBlueprint.defineColumns(declaring, const _SoftDeleteDeclaringModel());

      expect(
        declaring.columns.where((column) => column.name == 'deleted_at'),
        hasLength(1),
      );
    });

    test('omits deleted_at for a model that hard-deletes', () {
      final hard = BlueprintTable('widgets');
      BeakBlueprint.defineColumns(
        hard,
        const _WidgetModel(softDeleting: false),
      );
      expect(
        hard.columns.map((column) => column.name),
        isNot(contains('deleted_at')),
      );
    });

    test('uses the string length the column declares', () {
      // BeakMaxLength(120) on name; the default applies elsewhere.
      expect(columnOf(table, 'name').type, ColumnType.string);
      expect(columnOf(table, 'tint').type, ColumnType.string);
    });
  });

  group('defineForeignKeys', () {
    test('adds one constraint per belongs-to relationship', () {
      final table = BlueprintTable('widgets');
      BeakBlueprint.defineForeignKeys(table, const _WidgetModel());
      expect(table.foreignKeys, hasLength(1));
      final fk = table.foreignKeys.single;
      expect(fk.columns, ['owner_id']);
      expect(fk.referencedTable, 'users');
      expect(fk.referencedColumns, ['id']);
    });

    test('honours the relationship onDelete', () {
      final defaulted = BlueprintTable('widgets');
      BeakBlueprint.defineForeignKeys(defaulted, const _WidgetModel());
      expect(defaulted.foreignKeys.single.onDelete, OnDelete.setNull);

      final restricted = BlueprintTable('restricted');
      BeakBlueprint.defineForeignKeys(restricted, const _RestrictedModel());
      expect(restricted.foreignKeys.single.onDelete, OnDelete.restrict);
    });

    test('skips a target table that does not exist yet', () {
      // Migrations run in order; a constraint cannot reference a future table.
      final table = BlueprintTable('widgets');
      BeakBlueprint.defineForeignKeys(
        table,
        const _WidgetModel(),
        existingTables: const {'tags'},
      );
      expect(table.foreignKeys, isEmpty);
    });

    test('adds the constraint once the target table exists', () {
      final table = BlueprintTable('widgets');
      BeakBlueprint.defineForeignKeys(
        table,
        const _WidgetModel(),
        existingTables: const {'users'},
      );
      expect(table.foreignKeys, hasLength(1));
    });
  });

  group('pivots', () {
    test('definePivot builds the keyless join shape', () {
      final table = BlueprintTable('widget_tag');
      BeakBlueprint.definePivot(
        table,
        leftColumn: 'widget_id',
        leftTable: 'widgets',
        rightColumn: 'tag_id',
        rightTable: 'tags',
      );
      expect(table.columns.map((column) => column.name), [
        'widget_id',
        'tag_id',
      ]);
      expect(
        table.columns.every((column) => column.type == ColumnType.uuid),
        isTrue,
      );
      expect(table.indexes.single.columns, ['widget_id', 'tag_id']);
      expect(table.indexes.single.unique, isTrue);
      expect(
        table.foreignKeys.map((fk) => fk.onDelete),
        everyElement(OnDelete.cascade),
      );
    });

    test('createPivot derives both sides from the relationship', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await MigrationRunner(
        adapter: adapter,
        migrations: [const _CreateWidgetTagPivot()],
      ).migrate();

      // The table exists and accepts a row shaped like the pivot.
      await adapter.insert(
        const InsertDescriptor(
          table: 'widget_tag',
          values: {'widget_id': 'w1', 'tag_id': 't1'},
        ),
      );
      expect(
        await adapter.select(const QueryDescriptor(table: 'widget_tag')),
        hasLength(1),
      );
    });
  });

  group('wormOnDelete', () {
    test('mirrors every Beak value onto its worm counterpart', () {
      expect(wormOnDelete(BeakOnDelete.cascade), OnDelete.cascade);
      expect(wormOnDelete(BeakOnDelete.ormCascade), OnDelete.ormCascade);
      expect(wormOnDelete(BeakOnDelete.restrict), OnDelete.restrict);
      expect(wormOnDelete(BeakOnDelete.setNull), OnDelete.setNull);
      expect(wormOnDelete(BeakOnDelete.setDefault), OnDelete.setDefault);
      expect(wormOnDelete(BeakOnDelete.noAction), OnDelete.noAction);
    });

    test('covers every declared value, so neither enum can drift', () {
      for (final value in BeakOnDelete.values) {
        expect(wormOnDelete(value), isA<OnDelete>());
      }
      expect(BeakOnDelete.values, hasLength(OnDelete.values.length));
    });
  });
}
