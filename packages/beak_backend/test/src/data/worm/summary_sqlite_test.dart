import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

import '../../../support/test_models.dart';

void main() {
  test(
    'SQLite groups native queries beyond the page with exact numeric totals',
    () async {
      final adapter = SqliteAdapter.memory();
      await adapter.connect();
      addTearDown(adapter.disconnect);
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(
          table: 'products',
          columns: [
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
            SchemaColumn(name: 'name', type: ColumnType.text),
            SchemaColumn(name: 'price', type: ColumnType.decimal),
            SchemaColumn(name: 'active', type: ColumnType.boolean),
            SchemaColumn(name: 'created_at', type: ColumnType.dateTime),
            SchemaColumn(name: 'category_id', type: ColumnType.integer),
            SchemaColumn(
              name: 'deleted_at',
              type: ColumnType.dateTime,
              nullable: true,
            ),
          ],
        ),
      );
      await adapter.insertMany(
        InsertManyDescriptor(
          table: 'products',
          rows: [
            for (var i = 0; i < 1001; i++)
              {
                'id': i,
                'name': 'Item $i',
                'price': 100,
                'created_at': DateTime.utc(2026, 9, 28),
                'active': i.isEven,
                'category_id': i % 3,
              },
          ],
        ),
      );
      final source = WormDataSource(createTestRegistry(), adapter: adapter);
      const count = BeakSummaryMeasure.count('count');
      final sum = BeakSummaryMeasure.sum('sum', field: ProductModel.price);
      final result = await source.summary(
        const ProductModel().summary(
          groupBy: ProductModel.categoryId,
          measures: [count, sum],
        ),
      );
      expect(result.rows.map((row) => row.group.raw), [0, 1, 2]);
      expect(
        result.rows.map((row) => row.valueOf(count)).reduce((a, b) => a! + b!),
        1001,
      );
      expect(
        result.rows.map((row) => row.valueOf(sum)).reduce((a, b) => a! + b!),
        100100,
      );
    },
  );
}
