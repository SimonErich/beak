import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import 'beak_record_factory.dart';

/// Builds the source under test, freshly, for each contract test.
typedef BeakDataSourceBuilder = Future<BeakDataSource> Function();

/// Seeds [records] into [model]'s table on the source under test.
///
/// A contract cannot assume how a source is populated — the in-memory one has
/// `seed`, a worm-backed one needs SQL, a Serverpod one needs a session — so
/// the caller supplies it.
typedef BeakDataSourceSeeder =
    Future<void> Function(
      BeakDataSource source,
      BeakModel model,
      List<BeakRecord> records,
    );

/// Runs the shared [BeakDataSource] contract against [create].
///
/// "Implement nine methods" is not a specification. The interface has sharp
/// edges that only bite in production — `getOne` returning null rather than
/// throwing, `update` throwing when the row is gone, `aggregate` returning 0
/// rather than null over an empty set, soft deletes hiding from `query` but
/// not from `withTrashed` — and until now nothing checked any of them. Every
/// source runs this suite, so a third-party adapter can prove it belongs.
///
/// ```dart
/// void main() {
///   runBeakDataSourceContract(
///     'InMemoryBeakDataSource',
///     registry: buildRegistry(),
///     model: const ProductModel(),
///     create: () async => InMemoryBeakDataSource(registry: buildRegistry()),
///     seed: (source, model, records) async =>
///         (source as InMemoryBeakDataSource).seed(model, records),
///   );
/// }
/// ```
void runBeakDataSourceContract(
  String description, {
  required BeakModelRegistry registry,
  required BeakModel model,
  required BeakDataSourceBuilder create,
  required BeakDataSourceSeeder seed,
  BeakColumn? sortableTextColumn,
  BeakColumn? numericColumn,
}) {
  final BeakColumn textColumn =
      sortableTextColumn ??
      model.columns.firstWhere(
        (column) =>
            column is BeakStringColumn && column.key != model.primaryKey.key,
        orElse: () => throw ArgumentError(
          'No string column on ${model.table}; pass sortableTextColumn.',
        ),
      );
  final BeakColumn? number =
      numericColumn ??
      model.columns.cast<BeakColumn?>().firstWhere(
        (column) => column is BeakIntColumn || column is BeakDecimalColumn,
        orElse: () => null,
      );

  group('$description satisfies the BeakDataSource contract', () {
    late BeakDataSource source;
    late List<BeakRecord> seeded;

    /// Seeds [count] records and returns them.
    Future<List<BeakRecord>> given(int count) async {
      final factory = BeakRecordFactory();
      final records = factory.buildMany(model, count);
      await seed(source, model, records);
      return records;
    }

    setUp(() async {
      source = await create();
      seeded = await given(5);
    });

    Object idOf(BeakRecord record) => model.primaryKeyOf(record)!;

    group('query', () {
      test('returns every row with an accurate total', () async {
        final page = await source.query(model.query());
        expect(page.items, hasLength(seeded.length));
        expect(page.total, seeded.length);
      });

      test('pages without changing the total', () async {
        final page = await source.query(
          model.query(pagination: const BeakPagination(perPage: 2)),
        );
        expect(page.items, hasLength(2));
        expect(page.total, seeded.length);
        expect(page.perPage, 2);
        expect(page.page, 1);
      });

      test('a page past the end is empty, not an error', () async {
        final page = await source.query(
          model.query(pagination: const BeakPagination(page: 99, perPage: 2)),
        );
        expect(page.items, isEmpty);
        expect(page.total, seeded.length);
      });

      test('sorts ascending and descending', () async {
        final ascending = await source.query(
          model.query(sorts: [BeakSort(textColumn.key)]),
        );
        final descending = await source.query(
          model.query(sorts: [BeakSort(textColumn.key, descending: true)]),
        );
        final ascendingKeys = [
          for (final record in ascending.items)
            '${record[textColumn.key]?.raw}',
        ];
        final descendingKeys = [
          for (final record in descending.items)
            '${record[textColumn.key]?.raw}',
        ];
        expect(ascendingKeys, orderedEquals(List.of(ascendingKeys)..sort()));
        expect(descendingKeys, ascendingKeys.reversed.toList());
      });

      test('filters by equality', () async {
        final BeakRecord target = seeded.first;
        final page = await source.query(
          model.query(
            filter: BeakFieldFilter(
              column: model.primaryKey,
              operator: BeakOperator.eq,
              value: BeakValue.of(idOf(target)),
            ),
          ),
        );
        expect(page.items, hasLength(1));
        expect(page.total, 1, reason: 'total counts matches, not all rows');
        expect(model.primaryKeyOf(page.items.single), idOf(target));
      });

      test('filters with and/or composition', () async {
        final page = await source.query(
          model.query(
            filter: BeakOrFilter([
              BeakFieldFilter(
                column: model.primaryKey,
                operator: BeakOperator.eq,
                value: BeakValue.of(idOf(seeded[0])),
              ),
              BeakFieldFilter(
                column: model.primaryKey,
                operator: BeakOperator.eq,
                value: BeakValue.of(idOf(seeded[1])),
              ),
            ]),
          ),
        );
        expect(page.total, 2);
      });

      test('filters by inList and its negation', () async {
        final ids = [idOf(seeded[0]), idOf(seeded[1])];
        final included = await source.query(
          model.query(
            filter: BeakFieldFilter(
              column: model.primaryKey,
              operator: BeakOperator.inList,
              value: BeakValue.of(ids),
            ),
          ),
        );
        final excluded = await source.query(
          model.query(
            filter: BeakFieldFilter(
              column: model.primaryKey,
              operator: BeakOperator.notInList,
              value: BeakValue.of(ids),
            ),
          ),
        );
        expect(included.total, 2);
        expect(excluded.total, seeded.length - 2);
      });

      test('searches the columns it is given', () async {
        final String term = '${seeded.first[textColumn.key]?.raw}';
        final page = await source.query(
          model.query(search: BeakSearch(term, [textColumn.key])),
        );
        expect(page.items, isNotEmpty);
        expect(
          page.items.every(
            (record) => '${record[textColumn.key]?.raw}'.contains(term),
          ),
          isTrue,
        );
      });

      test('an empty search term matches everything', () async {
        final page = await source.query(
          model.query(search: BeakSearch('', [textColumn.key])),
        );
        expect(page.total, seeded.length);
      });
    });

    group('getOne', () {
      test('returns the record', () async {
        final BeakRecord? found = await source.getOne(
          model.table,
          idOf(seeded.first),
        );
        expect(found, isNotNull);
        expect(model.primaryKeyOf(found!), idOf(seeded.first));
      });

      test('returns null for a missing id rather than throwing', () async {
        // The distinction matters: a 404 is a normal outcome of a lookup, and
        // a source that throws forces every caller into a try/catch.
        expect(await source.getOne(model.table, 'no-such-id'), isNull);
      });
    });

    group('create', () {
      test('persists and echoes the stored record', () async {
        // A fresh id: a second factory restarts its sequence, so its first
        // generated key is the first seeded row's. Only a store that
        // enforces primary keys (any real database) notices.
        final BeakRecord draft = BeakRecordFactory(seed: 99).build(
          model,
          overrides: {model.primaryKey.key: const BeakStringValue('fresh-id')},
        );
        final BeakRecord created = await source.create(model.table, draft);

        expect(model.primaryKeyOf(created), isNotNull);
        final BeakRecord? reloaded = await source.getOne(
          model.table,
          model.primaryKeyOf(created)!,
        );
        expect(reloaded, isNotNull);
      });

      test('returns the id it was given', () async {
        // Minting an id is deliberately *not* part of this contract:
        // BeakResourceService owns `generateId`, and a data source that
        // invents keys behind the service's back would produce two sources of
        // truth. A source is only required to round-trip what it stored.
        final BeakRecord draft = BeakRecordFactory(seed: 7).build(
          model,
          overrides: {model.primaryKey.key: const BeakStringValue('given-id')},
        );
        final BeakRecord created = await source.create(model.table, draft);
        expect('${model.primaryKeyOf(created)}', 'given-id');
      });
    });

    group('update', () {
      test('applies a partial patch and leaves the rest alone', () async {
        final Object id = idOf(seeded.first);
        final BeakRecord patched = await source.update(
          model.table,
          id,
          BeakRecord(values: {textColumn.key: BeakValue.of('patched')}),
        );
        expect(patched[textColumn.key]?.raw, 'patched');
        expect(model.primaryKeyOf(patched), id, reason: 'id is not patchable');
      });

      test('throws BeakNotFoundException for a missing id', () async {
        expect(
          () => source.update(
            model.table,
            'no-such-id',
            BeakRecord(values: {textColumn.key: BeakValue.of('x')}),
          ),
          throwsA(isA<BeakNotFoundException>()),
        );
      });
    });

    group('delete', () {
      test('removes the record from subsequent reads', () async {
        final Object id = idOf(seeded.first);
        await source.delete(model.table, id);
        expect(await source.getOne(model.table, id), isNull);
        expect((await source.query(model.query())).total, seeded.length - 1);
      });

      test('throws BeakNotFoundException for a missing id', () async {
        expect(
          () => source.delete(model.table, 'no-such-id'),
          throwsA(isA<BeakNotFoundException>()),
        );
      });

      if (model.softDeletes) {
        test('a soft delete stays visible under withTrashed', () async {
          final Object id = idOf(seeded.first);
          await source.delete(model.table, id);

          final page = await source.query(model.query(withTrashed: true));
          expect(page.total, seeded.length);
          expect(
            page.items.map(model.primaryKeyOf),
            contains(id),
            reason: 'withTrashed must reveal soft-deleted rows',
          );
        });

        test('a forced delete is permanent', () async {
          final Object id = idOf(seeded.first);
          await source.delete(model.table, id, force: true);
          final page = await source.query(model.query(withTrashed: true));
          expect(page.items.map(model.primaryKeyOf), isNot(contains(id)));
        });

        test(
          'restore brings a soft-deleted record back into the query',
          () async {
            final Object id = idOf(seeded.first);
            await source.delete(model.table, id);
            expect(await source.getOne(model.table, id), isNull);

            final restored = await source.restore(model.table, id);

            expect(model.primaryKeyOf(restored), id);
            expect(await source.getOne(model.table, id), isNotNull);
            final page = await source.query(model.query());
            expect(page.items.map(model.primaryKeyOf), contains(id));
          },
        );

        test(
          'restoring a live record is not found, not a silent success',
          () async {
            expect(
              () => source.restore(model.table, idOf(seeded.first)),
              throwsA(isA<BeakNotFoundException>()),
            );
          },
        );

        test('restoring an unknown id is not found', () async {
          expect(
            () => source.restore(model.table, 'no-such-id'),
            throwsA(isA<BeakNotFoundException>()),
          );
        });
      } else {
        test(
          'restore is rejected on a model that does not soft-delete',
          () async {
            // Reporting success would claim a row came back that was never
            // recoverable in the first place.
            expect(
              () => source.restore(model.table, idOf(seeded.first)),
              throwsA(isA<BeakValidationException>()),
            );
          },
        );
      }
    });

    group('batchGet', () {
      test('returns the records for the ids it recognises', () async {
        final records = await source.batchGet(model.table, [
          idOf(seeded[0]),
          idOf(seeded[1]),
        ]);
        expect(records, hasLength(2));
      });

      test('skips unknown ids instead of failing the batch', () async {
        final records = await source.batchGet(model.table, [
          idOf(seeded[0]),
          'no-such-id',
        ]);
        expect(records, hasLength(1));
      });

      test('an empty id list returns nothing', () async {
        expect(await source.batchGet(model.table, const []), isEmpty);
      });
    });

    group('aggregate', () {
      test('counts the matching rows', () async {
        expect(await source.aggregate(model.count()), seeded.length);
      });

      test('honours the filter', () async {
        final count = await source.aggregate(
          model.count(
            filter: BeakFieldFilter(
              column: model.primaryKey,
              operator: BeakOperator.eq,
              value: BeakValue.of(idOf(seeded.first)),
            ),
          ),
        );
        expect(count, 1);
      });

      test('returns 0 over an empty set, never null', () async {
        final count = await source.aggregate(
          model.count(
            filter: BeakFieldFilter(
              column: model.primaryKey,
              operator: BeakOperator.eq,
              value: const BeakStringValue('no-such-id'),
            ),
          ),
        );
        expect(count, 0);
      });

      if (number != null) {
        test('sums and averages a numeric column', () async {
          // The contract discovers its column from `model.columns`, so it has
          // no generated field to hand: it wraps the column it found.
          final field = BeakScalarField<num>(model: model, column: number);
          final num sum = await source.aggregate(model.sum(field));
          final num avg = await source.aggregate(model.avg(field));
          expect(sum, isA<num>());
          expect(
            avg,
            closeTo(sum / seeded.length, 0.001),
            reason: 'avg must be sum over count',
          );
        });
      }
    });

    group('exceptions are typed', () {
      test('an unregistered table raises a configuration error', () async {
        expect(
          () => source.query(const BeakQuerySpec(table: 'no_such_table')),
          throwsA(isA<BeakException>()),
        );
      });
    });
  });
}
