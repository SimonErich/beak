import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/test_models.dart';

final class _Links extends BeakAllowAllPolicy
    implements BeakFieldPolicy, BeakRowPolicy {
  const _Links({
    this.hideLink = false,
    this.lockLink = false,
    this.lockRows = false,
    this.scopeRows = false,
  });
  final bool hideLink;
  final bool lockLink;
  final bool lockRows;
  final bool scopeRows;

  @override
  bool canReadField(BeakPrincipal? principal, String table, String key) =>
      !(hideLink && table == 'reviews' && key == 'product_id');

  @override
  bool canWriteField(BeakPrincipal? principal, String table, String key) =>
      !(lockLink && table == 'reviews' && key == 'product_id');

  @override
  bool canUpdate(BeakPrincipal? principal, String table, Object id) =>
      !(lockRows && table == 'reviews');

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, String table) =>
      scopeRows && table == 'reviews'
      ? const BeakFieldFilter.forKey('rating', BeakOperator.eq, BeakIntValue(1))
      : null;
}

final class _Money extends BeakModel {
  const _Money();
  static const currency = BeakStringColumn(key: 'name', label: 'Currency');
  @override
  String get table => 'products';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    ProductColumns.id,
    currency,
    BeakIntColumn(
      key: 'price',
      label: 'Amount',
      semantic: BeakSemantic.money(currencyColumn: currency),
    ),
  ];
}

final class _CategoryScope extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _CategoryScope();
  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, String table) =>
      table == 'categories'
      ? const BeakFieldFilter.forKey('id', BeakOperator.eq, BeakIntValue(1))
      : null;
}

final class _WriteOnly extends BeakAllowAllPolicy {
  const _WriteOnly();
  @override
  bool canView(BeakPrincipal? principal, String table) => false;
}

final class _HiddenIdentity extends BeakAllowAllPolicy
    implements BeakFieldPolicy {
  const _HiddenIdentity();
  @override
  bool canReadField(BeakPrincipal? principal, String table, String key) =>
      key != 'id';
  @override
  bool canWriteField(BeakPrincipal? principal, String table, String key) =>
      true;
}

final class _ReadOnlyCategory extends BeakAllowAllPolicy
    implements BeakFieldPolicy {
  const _ReadOnlyCategory();
  @override
  bool canReadField(BeakPrincipal? principal, String table, String key) => true;
  @override
  bool canWriteField(BeakPrincipal? principal, String table, String key) =>
      table != 'products' || key != 'category';
}

void main() {
  late WormDataSource source;
  late BeakModelRegistry registry;
  late InMemoryAdapter adapter;
  setUp(() async {
    adapter = await createTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = createTestRegistry();
    source = WormDataSource(registry, adapter: adapter);
    await source.create(
      'products',
      BeakRecord.fromRow({'id': 1, 'name': 'Beans'}),
    );
    await source.create(
      'reviews',
      BeakRecord.fromRow({'id': 2, 'rating': 5, 'body': 'Private link'}),
    );
  });
  tearDown(Worm.reset);

  Handler handler(BeakPolicy policy) => const Pipeline()
      .addMiddleware(beakErrorMappingMiddleware())
      .addHandler(
        beakApiRouter(registry: registry, dataSource: source, policy: policy),
      );

  Future<Response> request(BeakPolicy policy, String path, Object body) async =>
      handler(policy)(
        Request(
          'POST',
          Uri.parse('http://localhost/api$path'),
          body: jsonEncode(body),
        ),
      );

  test(
    'inverse traversal cannot expose a protected child foreign key',
    () async {
      const policy = _Links(hideLink: true);
      for (final spec in [
        const BeakQuerySpec(
          table: 'products',
          relationLoads: [BeakRelationLoad('reviews')],
        ),
        const BeakQuerySpec(
          table: 'products',
          filter: BeakFieldFilter.forKey(
            'reviews.rating',
            BeakOperator.eq,
            BeakIntValue(5),
          ),
        ),
        const BeakQuerySpec(
          table: 'products',
          search: BeakSearch('Private', ['reviews.body']),
        ),
        const BeakQuerySpec(
          table: 'products',
          sorts: [BeakSort('reviews.rating')],
        ),
      ]) {
        final response = await request(
          policy,
          '/products/query',
          spec.toJson(),
        );
        expect(response.statusCode, 401);
      }
      final fields = BeakFieldAccess(
        registry: registry,
        policy: policy,
        principal: null,
      );
      expect(fields.capabilities('products').canRead('reviews'), isFalse);
      expect(
        fields
            .redact(
              'products',
              BeakRecord(
                values: const {},
                relations: {
                  'reviews': [
                    BeakRecord.fromRow({'id': 2}),
                  ],
                },
              ),
            )
            .relations,
        isEmpty,
      );
    },
  );

  test(
    'HTTP relationship writes enforce child fields, row rights and scope',
    () async {
      for (final (policy, status) in [
        (const _Links(lockLink: true), 401),
        (const _Links(lockRows: true), 401),
        (const _Links(scopeRows: true), 404),
      ]) {
        for (final action in ['attach', 'detach']) {
          await source.update(
            'reviews',
            2,
            BeakRecord.fromRow({'product_id': action == 'detach' ? 1 : null}),
          );
          final response = await request(
            policy,
            '/products/1/relations/reviews/$action',
            {
              'ids': [2],
            },
          );
          expect(response.statusCode, status);
          expect(
            (await source.getOne('reviews', 2))!['product_id']?.raw,
            action == 'detach' ? 1 : null,
          );
        }
      }
    },
  );

  test(
    'graph relationships cannot bypass a protected child foreign key',
    () async {
      final service = BeakGraphCommitService(
        registry: registry,
        source: source,
        policy: const _Links(lockLink: true),
      );
      for (final kind in [
        BeakSaveOperationKind.attach,
        BeakSaveOperationKind.detach,
      ]) {
        await source.update(
          'reviews',
          2,
          BeakRecord.fromRow({
            'product_id': kind == BeakSaveOperationKind.detach ? 1 : null,
          }),
        );
        final result = await service.commit(
          BeakSavePlan(
            saveId: kind.name,
            root: const BeakRecordRef.existing('products', 1),
            operations: [
              BeakSaveOperation(
                id: 'link',
                kind: kind,
                target: const BeakRecordRef.existing('products', 1),
                related: const BeakRecordRef.existing('reviews', 2),
                relationKey: 'reviews',
              ),
            ],
          ),
        );
        expect(result.complete, isFalse);
        expect(result.outcomes.single.status, BeakWriteOutcome.unapplied);
        expect(result.outcomes.single.error?.code, 'authentication');
      }
    },
  );

  test('formatted exports cannot read protected companion fields', () async {
    final moneyRegistry = BeakModelRegistry()..register(const _Money());
    final moneySource = WormDataSource(moneyRegistry, adapter: adapter);
    await moneySource.update(
      'products',
      1,
      BeakRecord.fromRow({'name': 'JPY', 'price': 950}),
    );
    final stream = await CsvExportService(moneyRegistry, moneySource).exportCsv(
      'products',
      const BeakQuerySpec(table: 'products'),
      formatting: const BeakFormatPolicy(currency: 'USD'),
      canRead: (column) => column.key != 'name',
    );
    final csv = await utf8.decoder.bind(stream).join();
    expect(csv, isNot(contains('¥')));
    expect(csv, contains(r'$9.50'));
  });

  test(
    'flat foreign-key writes respect relationship access and related scope',
    () async {
      for (final id in [1, 2]) {
        await source.create(
          'categories',
          BeakRecord.fromRow({'id': id, 'name': 'Category $id'}),
        );
      }
      final fields = BeakFieldAccess(
        registry: registry,
        policy: const _ReadOnlyCategory(),
        principal: null,
      );
      expect(fields.capabilities('products').canWrite('category_id'), isFalse);
      expect(fields.capabilities('categories').canWrite('products'), isFalse);
      final inverse = await request(
        const _ReadOnlyCategory(),
        '/categories/1/relations/products/attach',
        {
          'ids': [1],
        },
      );
      expect(inverse.statusCode, 401);
      for (final (policy, status) in [
        (const _ReadOnlyCategory(), 401),
        (const _CategoryScope(), 404),
      ]) {
        final update = await handler(policy)(
          Request(
            'PATCH',
            Uri.parse('http://localhost/api/products/1'),
            body: jsonEncode({'category_id': 2}),
          ),
        );
        expect(update.statusCode, status);
        final create = await request(policy, '/products', {
          'name': 'Bypass',
          'category_id': 2,
        });
        expect(create.statusCode, status);
        expect(
          (await source.getOne('products', 1))!['category_id']?.raw,
          isNull,
        );
        expect(
          (await source.query(const BeakQuerySpec(table: 'products'))).total,
          1,
        );
      }
    },
  );

  test('write-only resource responses do not reveal stored values', () async {
    const policy = _WriteOnly();
    for (final response in [
      await handler(policy)(
        Request(
          'PATCH',
          Uri.parse('http://localhost/api/products/1'),
          body: jsonEncode({'active': true}),
        ),
      ),
      await request(policy, '/products', {'name': 'Created'}),
    ]) {
      expect(response.statusCode, anyOf(200, 201));
      expect(jsonDecode(await response.readAsString()), {
        'values': <String, Object?>{},
        'relations': <String, Object?>{},
      });
    }
    expect((await source.getOne('products', 1))!['active']?.raw, isTrue);
    expect(
      (await source.query(const BeakQuerySpec(table: 'products'))).total,
      2,
    );
  });

  test(
    'commit identity metadata cannot reveal a protected primary key',
    () async {
      for (final (id, policy) in [
        (2, const _HiddenIdentity()),
        (3, const _WriteOnly()),
      ]) {
        final service = BeakGraphCommitService(
          registry: registry,
          source: source,
          policy: policy,
        );
        final result = await service.commit(
          BeakSavePlan(
            saveId: 'hidden-identity-$id',
            root: const BeakRecordRef.draft('products', 'new'),
            operations: [
              BeakSaveOperation(
                id: 'new',
                kind: BeakSaveOperationKind.create,
                target: const BeakRecordRef.draft('products', 'new'),
                values: BeakRecord.fromRow({
                  'id': id,
                  'name': 'Private identity',
                }),
              ),
            ],
          ),
        );
        expect(result.complete, isTrue);
        expect(result.outcomes.single.record?['id'], isNull);
        expect(result.outcomes.single.resolvedId, isNull);
        expect(result.identities, isEmpty);
        if (policy is _HiddenIdentity) {
          expect(
            (await service.recover('hidden-identity-$id')).toJson(),
            result.toJson(),
          );
        }
        final privileged = await BeakGraphCommitService(
          registry: registry,
          source: source,
        ).recover('hidden-identity-$id');
        expect(privileged.outcomes.single.resolvedId, id);
        expect(privileged.outcomes.single.record?['id']?.raw, id);
      }
    },
  );
}
