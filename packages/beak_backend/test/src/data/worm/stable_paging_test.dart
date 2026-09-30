import 'package:beak_backend/src/data/worm/query_translator.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/test_models.dart';

/// Rows that tie on the sort key have no order of their own, and a database
/// may return them differently for page 1 and page 2 of the same query, so a
/// row shows on two pages or on none. The primary key breaks the tie.
void main() {
  late InMemoryAdapter adapter;
  late WormQueryTranslator translator;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createTestDatabase();
    translator = WormQueryTranslator(createTestRegistry());
  });

  tearDown(Worm.reset);

  String orderByOf(BeakQuerySpec spec) {
    final sql = translator.builderFor(spec, adapter).toSql();
    final start = sql.indexOf(' ORDER BY ');
    if (start < 0) return '';
    final end = sql.indexOf(' LIMIT');
    return sql.substring(start + ' ORDER BY '.length, end < 0 ? null : end);
  }

  test('a sort on a column that can tie ends with the primary key', () {
    expect(
      orderByOf(
        const BeakQuerySpec(table: 'products').orderBy(ProductModel.name),
      ),
      'name ASC, id ASC',
    );
  });

  test('a descending sort keeps its direction and still ends with the key', () {
    expect(
      orderByOf(
        const BeakQuerySpec(
          table: 'products',
        ).orderBy(ProductModel.price, descending: true),
      ),
      'price DESC, id ASC',
    );
  });

  test('several sorts keep their order and the key comes last', () {
    expect(
      orderByOf(
        const BeakQuerySpec(
          table: 'products',
        ).orderBy(ProductModel.name).orderBy(ProductModel.price),
      ),
      'name ASC, price ASC, id ASC',
    );
  });

  test('a sort that already names the primary key is left as it is', () {
    expect(
      orderByOf(
        const BeakQuerySpec(
          table: 'products',
        ).orderBy(ProductModel.id, descending: true),
      ),
      'id DESC',
    );
  });

  test('a query with no sort is left in the order the database keeps', () {
    expect(orderByOf(const BeakQuerySpec(table: 'products')), '');
  });
}
