import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';

IntrospectedTable _table(
  String name,
  List<IntrospectedColumn> columns, {
  List<IntrospectedForeignKey> foreignKeys = const [],
}) => IntrospectedTable(name: name, columns: columns, foreignKeys: foreignKeys);

const IntrospectedColumn _serialId = IntrospectedColumn(
  name: 'id',
  dataType: 'integer',
  isNullable: false,
  hasDefault: true,
);

const IntrospectedColumn _reference = IntrospectedColumn(
  name: 'reference',
  dataType: 'character varying',
  isNullable: false,
  maxLength: 40,
);

void main() {
  group('a table with an integer primary key', () {
    late Map<String, IntrospectedSchemaFile> files;

    setUp(() {
      final emitted = BeakIntrospectionEmitter.emitAll([
        _table('legacy_orders', [_serialId, _reference]),
        _table(
          'order_lines',
          [
            _serialId,
            const IntrospectedColumn(
              name: 'legacy_order_id',
              dataType: 'integer',
              isNullable: false,
            ),
            const IntrospectedColumn(
              name: 'quantity',
              dataType: 'integer',
              isNullable: false,
            ),
          ],
          foreignKeys: const [
            IntrospectedForeignKey(
              column: 'legacy_order_id',
              referencedTable: 'legacy_orders',
            ),
          ],
        ),
        _table('notes', [
          const IntrospectedColumn(
            name: 'id',
            dataType: 'uuid',
            isNullable: false,
          ),
          _reference,
        ]),
      ]);
      files = {for (final file in emitted) file.table: file};
    });

    test('declares the key as the integer it is', () {
      // The server mints a string id only for a string key, and leaves an
      // integer one to the database, so the declared type is what makes a
      // create work.
      expect(files['legacy_orders']!.contents, contains('late final int? id;'));
    });

    test('stays a resource that can be created and edited', () {
      expect(files['legacy_orders']!.contents, isNot(contains('capabilities')));
      expect(files['legacy_orders']!.notes, isEmpty);
    });

    test('is the key type of a table that points at it', () {
      final root = Directory.systemTemp.createTempSync('beak_serial_');
      addTearDown(() => root.deleteSync(recursive: true));
      for (final file in files.values) {
        File('${root.path}/lib/${file.path}')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(file.contents);
      }

      final (schemas, issues) = BeakSchemaReader(root).read();

      expect(issues.map((issue) => issue.message), isEmpty);
      final BeakSchemaIr lines = schemas.singleWhere(
        (schema) => schema.table == 'order_lines',
      );
      expect(
        lines.columns
            .singleWhere((column) => column.columnKey == 'legacy_order_id')
            .valueType,
        'int',
      );
    });

    test('leaves a table with a uuid key alone', () {
      expect(files['notes']!.contents, isNot(contains('late final int? id')));
      expect(files['notes']!.notes, isEmpty);
    });
  });

  group('a numeric column', () {
    test('is read as a double, and the note says what that costs', () {
      // The exact type is a `BeakDecimal`, which Beak stores as integer units
      // and cannot read out of an existing NUMERIC column, so the honest
      // mapping is the double with a warning, not the exact type.
      final emitted = BeakIntrospectionEmitter.emitAll([
        _table('invoices', [
          const IntrospectedColumn(
            name: 'id',
            dataType: 'uuid',
            isNullable: false,
          ),
          const IntrospectedColumn(
            name: 'total',
            dataType: 'numeric',
            isNullable: false,
            numericPrecision: 12,
            numericScale: 2,
          ),
          const IntrospectedColumn(
            name: 'weight',
            dataType: 'real',
            isNullable: true,
          ),
        ]),
      ]).single;

      expect(emitted.contents, contains('late final double total;'));
      final String note = emitted.notes.single;
      expect(note, contains('invoices.total'));
      expect(note, contains('numeric(12,2)'));
      expect(note, contains('double'));
      expect(note, contains('round'));
    });

    test('with no declared width is still noted', () {
      final emitted = BeakIntrospectionEmitter.emitAll([
        _table('gauges', [
          const IntrospectedColumn(
            name: 'id',
            dataType: 'uuid',
            isNullable: false,
          ),
          const IntrospectedColumn(
            name: 'reading',
            dataType: 'numeric',
            isNullable: true,
          ),
        ]),
      ]).single;

      expect(emitted.notes.single, contains('gauges.reading is numeric'));
    });
  });
}
