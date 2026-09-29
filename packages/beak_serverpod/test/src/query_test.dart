import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
import 'package:test/test.dart';

enum _Sort { title, status }

void main() {
  const title = BeakStringColumn(
    key: 'entry.title',
    label: 'Title',
    sortable: true,
    searchable: true,
  );
  const status = BeakStringColumn(
    key: 'entry.status',
    label: 'Status',
    filterable: true,
    sortable: true,
  );
  const model = ServerpodModel(
    resource: 'entries',
    columns: [title, status],
    primaryKey: BeakStringColumn(key: 'entry.id', label: 'ID'),
    displayColumn: title,
  );
  const titleField = BeakScalarField<Object>(model: model, column: title);
  const statusField = BeakScalarField<Object>(model: model, column: status);
  const filter = BeakFieldFilter(
    column: status,
    operator: BeakOperator.eq,
    value: BeakStringValue('active'),
  );
  ServerpodQueryReader reader(BeakQuerySpec spec) => ServerpodQueryReader(
    spec: spec,
    model: model,
    fields: const {
      'title': ['entry.title'],
      'status': ['entry.status', 'entry.child.status', 'other.status'],
    },
    filters: const {'status'},
    supportsSearch: true,
    supportsArchived: true,
  );
  test('maps query vocabulary without changing endpoint defaults', () {
    final value = reader(
      const BeakQuerySpec(
        table: 'entries',
        filter: BeakAndFilter([filter]),
      ).paginate(page: 2, perPage: 7),
    );
    expect(value.page(0), 1);
    expect(value.page(1), 2);
    expect(value.perPage, 7);
    expect(value.sort(_Sort.values, _Sort.title), _Sort.title);
    expect(value.descending(true), isTrue);
    expect(value.equal('status', ServerpodCodecs.string.nullable), 'active');
    expect(
      reader(
        const BeakQuerySpec(table: 'entries'),
      ).equal('status', ServerpodCodecs.string.nullable),
      isNull,
    );
    final sorted = reader(
      const BeakQuerySpec(
        table: 'entries',
      ).orderBy(statusField).searching('term', [titleField]),
    );
    expect(sorted.sort(_Sort.values, _Sort.title), _Sort.status);
    expect(sorted.descending(true), isFalse);
    expect(sorted.search, 'term');
    final hidden = ServerpodQueryReader(
      spec: const BeakQuerySpec(table: 'entries').orderBy(statusField),
      model: model,
      fields: const {
        'title': ['one.title', 'two.title'],
        'status': ['entry.status'],
      },
    );
    expect(hidden.sort(_Sort.values, _Sort.title), _Sort.status);

    expect(
      sorted.sort(
        _Sort.values,
        _Sort.title,
        overrides: {status.key: _Sort.title},
      ),
      _Sort.title,
    );
  });
  test('rejects unsupported predicates, sorting, relations and paging', () {
    for (final spec in [
      const BeakQuerySpec(table: 'other'),
      const BeakQuerySpec(
        table: 'entries',
        filter: BeakFieldFilter(column: title, operator: BeakOperator.eq),
      ),
      const BeakQuerySpec(
        table: 'entries',
        filter: BeakFieldFilter(column: status, operator: BeakOperator.gt),
      ),
      const BeakQuerySpec(table: 'entries', filter: BeakOrFilter([filter])),
      const BeakQuerySpec(
        table: 'entries',
        filter: BeakAndFilter([filter, filter]),
      ),
      const BeakQuerySpec(
        table: 'entries',
        relationLoads: [BeakRelationLoad('items')],
      ),
      const BeakQuerySpec(
        table: 'entries',
      ).orderBy(titleField).orderBy(statusField),
      const BeakQuerySpec(table: 'entries').searching('term', [statusField]),
    ]) {
      expect(() => reader(spec), throwsA(isA<BeakConfigurationException>()));
    }
    expect(
      () => reader(const BeakQuerySpec(table: 'entries')).page(2),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => reader(
        const BeakQuerySpec(table: 'entries', sorts: [BeakSort('missing')]),
      ).sort(_Sort.values, _Sort.title),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => reader(
        const BeakQuerySpec(table: 'entries').orderBy(titleField),
      ).sort([_Sort.status], _Sort.status),
      throwsA(isA<BeakConfigurationException>()),
    );
    for (final spec in [
      const BeakQuerySpec(table: 'entries', withTrashed: true),
      const BeakQuerySpec(table: 'entries', search: BeakSearch('term', [])),
    ]) {
      expect(
        () => ServerpodQueryReader(spec: spec, model: model, fields: const {}),
        throwsA(isA<BeakConfigurationException>()),
      );
    }
  });
  test('does not guess between ambiguous branches', () {
    final value = ServerpodQueryReader(
      spec: const BeakQuerySpec(table: 'entries'),
      model: model,
      fields: const {
        'title': ['profile.title'],
        'status': ['one.status', 'two.status'],
      },
    );
    expect(value.resolveField('title'), 'profile.title');
    expect(
      () => value.resolveField('status'),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => value.resolveField('absent'),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
  test(
    'count retains authorized query scope and rejects other aggregates',
    () async {
      final count = await serverpodCount(
        const BeakAggregateSpec.count(
          table: 'entries',
          filter: filter,
          withTrashed: true,
        ),
        (spec) async {
          expect(spec.table, 'entries');
          expect(spec.filter, filter);
          expect(spec.withTrashed, isTrue);
          expect(spec.pagination.perPage, 1);
          return const BeakPage(items: <int>[], total: 42, page: 1, perPage: 1);
        },
      );
      expect(count, 42);
      await expectLater(
        serverpodCount<Object>(
          const BeakAggregateSpec.sum(table: 'entries', column: title),
          (_) async => throw StateError('must not fetch'),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );
  test(
    'command projection uses exact then identity-branch then unique fields',
    () {
      const input = BeakRecord(
        values: {
          'title': BeakStringValue('exact'),
          'entry.status': BeakStringValue('active'),
          'other.status': BeakStringValue('wrong'),
          'profile.email': BeakNullValue(),
        },
      );
      final result = serverpodProjectInput(
        input,
        inputKeys: ['title', 'status', 'user.email'],
        primaryKey: 'entry.id',
      );
      expect(result['title']?.raw, 'exact');
      expect(result['status']?.raw, 'active');
      expect(result['user.email'], isA<BeakNullValue>());
      expect(
        () => serverpodProjectInput(
          input,
          inputKeys: ['missing'],
          primaryKey: 'id',
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => serverpodProjectInput(
          input,
          inputKeys: ['status'],
          primaryKey: 'id',
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );
}
