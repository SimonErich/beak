import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  const approvedOnly = BeakFieldFilter.forKey(
    'approved',
    BeakOperator.eq,
    BeakBoolValue(true),
  );

  const nestedLoad = BeakRelationLoad(
    'comments',
    filter: approvedOnly,
    nested: [BeakRelationLoad('author')],
  );

  test('defaults to no constraint and no nested loads', () {
    const load = BeakRelationLoad('author');
    expect(load.filter, isNull);
    expect(load.nested, isEmpty);
  });

  test('pins the exact JSON map', () {
    expect(const BeakRelationLoad('author').toJson(), {
      'relation': 'author',
      'filter': null,
      'nested': <Object?>[],
    });
    expect(nestedLoad.toJson(), {
      'relation': 'comments',
      'filter': {
        'type': 'field',
        'column': 'approved',
        'operator': 'eq',
        'value': true,
      },
      'nested': [
        {'relation': 'author', 'filter': null, 'nested': <Object?>[]},
      ],
    });
  });

  test('round-trips through JSON losslessly', () {
    expect(BeakRelationLoad.fromJson(nestedLoad.toJson()), nestedLoad);
  });

  group('fromJson', () {
    test('rejects JSON without the relation', () {
      expect(
        () => BeakRelationLoad.fromJson(const {'filter': null, 'nested': []}),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('"relation"'),
          ),
        ),
      );
    });

    test('loads the bare relation when filter and nested are omitted', () {
      expect(
        BeakRelationLoad.fromJson(const {'relation': 'a'}),
        const BeakRelationLoad('a'),
      );
      expect(
        BeakRelationLoad.fromJson(const {'relation': 'a', 'nested': []}),
        const BeakRelationLoad('a'),
      );
      expect(
        BeakRelationLoad.fromJson(const {
          'relation': 'a',
          'nested': [
            {'relation': 'b'},
          ],
        }),
        const BeakRelationLoad('a', nested: [BeakRelationLoad('b')]),
      );
    });

    test('rejects wrongly typed keys', () {
      expect(
        () => BeakRelationLoad.fromJson(const {
          'relation': 1,
          'filter': null,
          'nested': [],
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakRelationLoad.fromJson(const {
          'relation': 'a',
          'filter': 'nope',
          'nested': [],
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakRelationLoad.fromJson(const {
          'relation': 'a',
          'filter': null,
          'nested': 'nope',
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakRelationLoad.fromJson(const {
          'relation': 'a',
          'filter': null,
          'nested': [1],
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('propagates malformed nested filters', () {
      expect(
        () => BeakRelationLoad.fromJson(const {
          'relation': 'a',
          'filter': {'type': 'bogus'},
          'nested': [],
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('equality', () {
    test('equal loads compare equal and hash consistently', () {
      expect(
        BeakRelationLoad(
          runtimeValue('comments'),
          filter: approvedOnly,
          nested: const [BeakRelationLoad('author')],
        ),
        nestedLoad,
      );
      expect(
        BeakRelationLoad(
          runtimeValue('comments'),
          filter: approvedOnly,
          nested: const [BeakRelationLoad('author')],
        ).hashCode,
        nestedLoad.hashCode,
      );
    });

    test('loads differ by relation, constraint, or nested loads', () {
      expect(
        const BeakRelationLoad('author'),
        isNot(const BeakRelationLoad('editor')),
      );
      expect(
        const BeakRelationLoad('author'),
        isNot(const BeakRelationLoad('author', filter: approvedOnly)),
      );
      expect(
        const BeakRelationLoad('author'),
        isNot(
          const BeakRelationLoad('author', nested: [BeakRelationLoad('tags')]),
        ),
      );
    });
  });

  test('toString names the relation and its parts', () {
    expect(
      const BeakRelationLoad('author').toString(),
      'BeakRelationLoad(author, filter: null, nested: [])',
    );
  });
}
