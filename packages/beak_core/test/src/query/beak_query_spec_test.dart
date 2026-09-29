import 'dart:convert';
import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

final class _Posts extends BeakModel {
  const _Posts();
  @override
  String get table => 'posts';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [];
}

void main() {
  const status = BeakStringColumn(key: 'status', label: 'Status');
  const lastActive = BeakDateTimeColumn(
    key: 'last_active',
    label: 'Last active',
  );
  const createdAt = BeakDateTimeColumn(key: 'created_at', label: 'Created at');
  const name = BeakStringColumn(key: 'name', label: 'Name');
  const email = BeakStringColumn(key: 'email', label: 'Email');
  const createdAtField = BeakScalarField<DateTime>(
    model: _Posts(),
    column: createdAt,
  );
  const nameField = BeakScalarField<String>(model: _Posts(), column: name);
  const emailField = BeakScalarField<String>(model: _Posts(), column: email);

  const author = BeakBelongsTo(
    key: 'author',
    label: 'Author',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'author_id',
  );

  final cutoff = DateTime.utc(2026, 6);

  /// The concept example: with([author]), where(status eq active),
  /// where(lastActive lt cutoff), orderBy(createdAt desc), search, paginate.
  BeakQuerySpec richSpec() => const BeakQuerySpec(table: 'posts')
      .withRelation(author)
      .withFilter(
        BeakFieldFilter(
          column: status,
          operator: BeakOperator.eq,
          value: BeakValue.of('active'),
        ),
      )
      .withFilter(
        BeakFieldFilter(
          column: lastActive,
          operator: BeakOperator.lt,
          value: BeakValue.of(cutoff),
        ),
      )
      .orderBy(createdAtField, descending: true)
      .searching('ada', const [nameField, emailField])
      .paginate(page: 2, perPage: 50);

  group('BeakSearch', () {
    test('pins the exact JSON map', () {
      expect(const BeakSearch('ada', ['name', 'email']).toJson(), {
        'term': 'ada',
        'columns': ['name', 'email'],
      });
    });

    test('round-trips through JSON losslessly', () {
      const search = BeakSearch('ada', ['name', 'email']);
      expect(BeakSearch.fromJson(search.toJson()), search);
    });

    test('fromJson rejects missing or wrongly typed keys', () {
      expect(
        () => BeakSearch.fromJson(const {'columns': <Object?>[]}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakSearch.fromJson(const {'term': 'a'}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakSearch.fromJson(const {'term': 'a', 'columns': 'name'}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakSearch.fromJson(const {
          'term': 'a',
          'columns': [1],
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('equal searches compare equal and hash consistently', () {
      expect(
        BeakSearch(runtimeValue('a'), const ['b']),
        const BeakSearch('a', ['b']),
      );
      expect(
        BeakSearch(runtimeValue('a'), const ['b']).hashCode,
        const BeakSearch('a', ['b']).hashCode,
      );
      expect(const BeakSearch('a', ['b']), isNot(const BeakSearch('z', ['b'])));
      expect(const BeakSearch('a', ['b']), isNot(const BeakSearch('a', ['z'])));
    });

    test('toString names term and columns', () {
      expect(
        const BeakSearch('ada', ['name']).toString(),
        'BeakSearch(ada in [name])',
      );
    });
  });

  group('defaults', () {
    test('an empty spec pins the exact JSON map', () {
      expect(const BeakQuerySpec(table: 'products').toJson(), {
        'table': 'products',
        'filter': null,
        'sorts': <Object?>[],
        'search': null,
        'relations': <Object?>[],
        'pagination': {'page': 1, 'perPage': 25},
        'withTrashed': false,
      });
    });

    test('an empty spec round-trips losslessly', () {
      const spec = BeakQuerySpec(table: 'products');
      expect(BeakQuerySpec.fromJson(spec.toJson()), spec);
    });
  });

  group('copy-builders', () {
    const base = BeakQuerySpec(table: 'posts');
    final active = BeakFieldFilter(
      column: status,
      operator: BeakOperator.eq,
      value: BeakValue.of('active'),
    );
    final recent = BeakFieldFilter(
      column: lastActive,
      operator: BeakOperator.gte,
      value: BeakValue.of(cutoff),
    );
    const named = BeakFieldFilter.forKey(
      'name',
      BeakOperator.contains,
      BeakStringValue('ada'),
    );

    test('withFilter sets the first filter as-is', () {
      expect(base.withFilter(active).filter, active);
    });

    test('withFilter AND-merges a second filter', () {
      expect(
        base.withFilter(active).withFilter(recent).filter,
        BeakAndFilter([active, recent]),
      );
    });

    test('withFilter appends to an existing conjunction without nesting', () {
      expect(
        base.withFilter(active).withFilter(recent).withFilter(named).filter,
        BeakAndFilter([active, recent, named]),
      );
    });

    test('orderBy appends typed sorts in order', () {
      final sorted = base
          .orderBy(createdAtField, descending: true)
          .orderBy(nameField);
      expect(sorted.sorts, const [
        BeakSort('created_at', descending: true),
        BeakSort('name'),
      ]);
    });

    test('withRelation appends loads, optionally constrained', () {
      final loaded = base
          .withRelation(author)
          .withRelation(author, constraint: named);
      expect(loaded.relationLoads, const [
        BeakRelationLoad('author'),
        BeakRelationLoad('author', filter: named),
      ]);
    });

    test('searching reads storage keys from typed fields', () {
      expect(
        base.searching('ada', const [nameField, emailField]).search,
        const BeakSearch('ada', ['name', 'email']),
      );
    });

    test('searching keeps a relationship path in the searched key', () {
      const authorName = BeakScalarField<String>(
        model: _Posts(),
        column: name,
        path: [author],
      );
      expect(
        base.searching('ada', const [nameField, authorName]).search,
        const BeakSearch('ada', ['name', 'author.name']),
      );
    });

    test('orderBy refuses a field reached through a relationship', () {
      const authorName = BeakScalarField<String>(
        model: _Posts(),
        column: name,
        path: [author],
      );
      expect(
        () => base.orderBy(authorName),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('paginate keeps the other window half when omitted', () {
      final paged = base.paginate(page: 3);
      expect(paged.pagination, const BeakPagination(page: 3));
      expect(
        paged.paginate(perPage: 100).pagination,
        const BeakPagination(page: 3, perPage: 100),
      );
      expect(
        base.paginate(page: 2, perPage: 50).pagination,
        const BeakPagination(page: 2, perPage: 50),
      );
    });

    test('builders never mutate the receiving spec', () {
      final built = base
          .withFilter(active)
          .orderBy(createdAtField)
          .withRelation(author)
          .searching('ada', const [nameField])
          .paginate(page: 9);
      expect(built, isNot(base));
      expect(base, const BeakQuerySpec(table: 'posts'));
    });
  });

  group('golden', () {
    final goldenFile = File('test/golden/rich_query_spec.json');

    test('the rich spec matches the committed golden JSON file', () {
      final golden = goldenFile.readAsStringSync();
      expect(jsonDecode(golden), richSpec().toJson());
      const encoder = JsonEncoder.withIndent('  ');
      expect('${encoder.convert(richSpec().toJson())}\n', golden);
    });

    test('the committed golden decodes back to the rich spec', () {
      final spec = switch (jsonDecode(goldenFile.readAsStringSync())) {
        final Map<String, Object?> map => BeakQuerySpec.fromJson(map),
        final Object? other => fail('golden must be a JSON object, got $other'),
      };
      expect(spec, richSpec());
    });

    test('fromJson(toJson(spec)) == spec for the rich example', () {
      expect(BeakQuerySpec.fromJson(richSpec().toJson()), richSpec());
    });
  });

  group('soft deletes', () {
    test('withTrashed round-trips', () {
      const spec = BeakQuerySpec(table: 'posts', withTrashed: true);
      expect(spec.toJson()['withTrashed'], isTrue);
      expect(BeakQuerySpec.fromJson(spec.toJson()), spec);
    });
  });

  group('idempotent JSON', () {
    test('encode → decode → encode is stable across representative specs', () {
      final specs = <BeakQuerySpec>[
        const BeakQuerySpec(table: 'products'),
        const BeakQuerySpec(table: 'posts', withTrashed: true),
        const BeakQuerySpec(table: 'users').searching('ada', [nameField]),
        richSpec(),
      ];
      for (final spec in specs) {
        final encoded = jsonEncode(spec.toJson());
        final decoded = switch (jsonDecode(encoded)) {
          final Map<String, Object?> map => BeakQuerySpec.fromJson(map),
          final Object? other => fail('expected a JSON object, got $other'),
        };
        expect(decoded, spec);
        expect(jsonEncode(decoded.toJson()), encoded);
      }
    });
  });

  group('fromJson validation', () {
    Map<String, Object?> valid() =>
        const BeakQuerySpec(table: 'posts').toJson();

    test('rejects a missing, empty, or non-string table', () {
      expect(
        () => BeakQuerySpec.fromJson(valid()..remove('table')),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakQuerySpec.fromJson(valid()..['table'] = ''),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakQuerySpec.fromJson(valid()..['table'] = 7),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects wrongly typed sections', () {
      expect(
        () => BeakQuerySpec.fromJson(valid()..['filter'] = 7),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakQuerySpec.fromJson(valid()..['sorts'] = 'nope'),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakQuerySpec.fromJson(valid()..['sorts'] = [1]),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakQuerySpec.fromJson(valid()..['search'] = 'ada'),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakQuerySpec.fromJson(valid()..['relations'] = 'nope'),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakQuerySpec.fromJson(valid()..['pagination'] = 7),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakQuerySpec.fromJson(valid()..['withTrashed'] = 'yes'),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('only the table is required; every section has a default', () {
      // A request written by hand — curl, an agent, another language — sends
      // just what it means to change. `toJson` still writes every key.
      final spec = BeakQuerySpec.fromJson(<String, Object?>{'table': 'posts'});

      expect(spec.table, 'posts');
      expect(spec.filter, isNull);
      expect(spec.sorts, isEmpty);
      expect(spec.search, isNull);
      expect(spec.relationLoads, isEmpty);
      expect(spec.pagination, const BeakPagination());
      expect(spec.withTrashed, isFalse);
    });

    test('an omitted section decodes exactly as an explicit null', () {
      for (final key in const [
        'filter',
        'sorts',
        'search',
        'relations',
        'pagination',
        'withTrashed',
      ]) {
        expect(
          BeakQuerySpec.fromJson(valid()..remove(key)),
          BeakQuerySpec.fromJson(valid()..[key] = null),
          reason: '"$key"',
        );
      }
    });

    test('a defaulted decode round-trips back to the full encoded form', () {
      // Accepting less on the way in must not change what goes out.
      expect(
        BeakQuerySpec.fromJson(<String, Object?>{'table': 'posts'}).toJson(),
        const BeakQuerySpec(table: 'posts').toJson(),
      );
    });
  });

  group('equality', () {
    test('independently built rich specs compare equal and hash alike', () {
      expect(richSpec(), richSpec());
      expect(richSpec().hashCode, richSpec().hashCode);
    });

    test('specs differ per field', () {
      const base = BeakQuerySpec(table: 'posts');
      expect(base, isNot(const BeakQuerySpec(table: 'users')));
      expect(
        base,
        isNot(base.withFilter(runtimeValue(const BeakOrFilter([])))),
      );
      expect(base, isNot(base.orderBy(createdAtField)));
      expect(base, isNot(base.searching('ada', const [nameField])));
      expect(base, isNot(base.withRelation(author)));
      expect(base, isNot(base.paginate(page: 2)));
      expect(
        base,
        isNot(const BeakQuerySpec(table: 'posts', withTrashed: true)),
      );
    });

    test('toString names the table', () {
      expect(const BeakQuerySpec(table: 'posts').toString(), contains('posts'));
    });
  });
}
