import 'dart:convert';
import 'dart:math';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// A request body is hostile input: whatever shape it takes, a decoder either
/// returns a value or throws a [BeakConfigurationException], which the server
/// answers with a 422. A [TypeError], a [RangeError] or a [StateError] would be
/// a 500 for a mistake that is the caller's.
///
/// Each decoder is fed thousands of mutations of a valid document: one node
/// replaced by junk of another type. The seed is fixed, so a failure names the
/// document that caused it and reproduces.
void main() {
  final valid =
      <String, (Object? Function(Map<String, Object?>), Map<String, Object?>)>{
        'BeakQuerySpec': (
          BeakQuerySpec.fromJson,
          {
            'table': 'notes',
            'filter': {
              'type': 'and',
              'filters': [
                {
                  'type': 'field',
                  'column': 'rating',
                  'operator': 'gt',
                  'value': 1,
                },
                {
                  'type': 'or',
                  'filters': [
                    {
                      'type': 'field',
                      'column': 'created_at',
                      'operator': 'lt',
                      'value': {
                        'type': 'dateTime',
                        'value': '2026-01-01T00:00:00Z',
                      },
                    },
                    {
                      'type': 'relation',
                      'relation': 'author',
                      'filter': {
                        'type': 'field',
                        'column': 'name',
                        'operator': 'inList',
                        'value': ['a', 'b'],
                      },
                    },
                  ],
                },
              ],
            },
            'sorts': [
              {'column': 'rating', 'descending': true},
            ],
            'search': {
              'term': 'x',
              'columns': ['title', 'author.name'],
            },
            'relations': [
              {
                'relation': 'author',
                'filter': null,
                'nested': [
                  {'relation': 'books', 'filter': null, 'nested': <Object?>[]},
                ],
              },
            ],
            'pagination': {'page': 2, 'perPage': 10},
            'withTrashed': false,
          },
        ),
        'BeakAggregateSpec': (
          BeakAggregateSpec.fromJson,
          {
            'table': 'notes',
            'function': 'sum',
            'column': 'rating',
            'filter': {
              'type': 'field',
              'column': 'rating',
              'operator': 'between',
              'value': [1, 5],
            },
            'withTrashed': false,
          },
        ),
        'BeakSummarySpec': (
          BeakSummarySpec.fromJson,
          {
            'table': 'notes',
            'groupBy': 'status',
            'measures': [
              {'key': 'n', 'column': null},
              {
                'key': 's',
                'column': 'rating',
                'filter': {
                  'type': 'field',
                  'column': 'published',
                  'operator': 'eq',
                  'value': true,
                },
              },
            ],
            'filter': null,
            'search': {
              'term': 'x',
              'columns': ['title'],
            },
            'limit': 100,
            'withTrashed': false,
          },
        ),
        'BeakRecord': (
          BeakRecord.fromJson,
          {
            'values': {
              'id': 'n1',
              'rating': 3,
              'created_at': {
                'type': 'dateTime',
                'value': '2026-01-01T00:00:00Z',
              },
              'tags': ['a', 'b'],
            },
            'relations': {
              'author': [
                {
                  'values': {'id': 'a1'},
                  'relations': <String, Object?>{},
                },
              ],
            },
          },
        ),
        'BeakValidationRequest': (
          BeakValidationRequest.fromJson,
          {
            'table': 'notes',
            'recordId': 'n1',
            'record': {
              'values': {'title': 'x', 'rating': 3},
              'relations': <String, Object?>{},
            },
          },
        ),
      };

  const iterations = 4000;

  Object? junk(Random random, int depth) {
    switch (random.nextInt(depth > 2 ? 7 : 9)) {
      case 0:
        return null;
      case 1:
        return random.nextInt(2000) - 1000;
      case 2:
        return random.nextDouble() * 1e6;
      case 3:
        return random.nextBool();
      case 4:
        return [
          '',
          'x',
          'and',
          'field',
          'eq',
          'dateTime',
          'notes',
          '%',
          '\u0000',
        ].elementAt(random.nextInt(9));
      case 5:
        return 9007199254740993;
      case 6:
        return -1;
      case 7:
        return [
          for (var i = random.nextInt(3); i > 0; i--) junk(random, depth + 1),
        ];
      default:
        return {
          for (var i = random.nextInt(3); i > 0; i--)
            ['type', 'value', 'column', 'filters', 'x'][random.nextInt(5)]:
                junk(random, depth + 1),
        };
    }
  }

  /// [document] with one node, chosen by [random], replaced by junk (or a key
  /// removed).
  Object? mutate(Object? document, Random random) {
    final paths = <List<Object>>[];
    void walk(Object? node, List<Object> path) {
      paths.add(path);
      if (node is Map<String, Object?>) {
        for (final entry in node.entries) {
          walk(entry.value, [...path, entry.key]);
        }
      } else if (node is List<Object?>) {
        for (var i = 0; i < node.length; i++) {
          walk(node[i], [...path, i]);
        }
      }
    }

    walk(document, const []);
    final path = paths[random.nextInt(paths.length)];
    Object? copy(Object? node, int depth) {
      if (depth == path.length) {
        return random.nextInt(6) == 0 && path.isNotEmpty
            ? #removed
            : junk(random, 0);
      }
      final step = path[depth];
      if (node is Map<String, Object?>) {
        return {
          for (final entry in node.entries)
            if (!(entry.key == step &&
                depth == path.length - 1 &&
                copy(entry.value, depth + 1) == #removed))
              entry.key: entry.key == step
                  ? copy(entry.value, depth + 1)
                  : entry.value,
        };
      }
      if (node is List<Object?>) {
        return [
          for (var i = 0; i < node.length; i++)
            if (i == step) copy(node[i], depth + 1) else node[i],
        ];
      }
      return node;
    }

    final result = copy(document, 0);
    return result == #removed ? document : result;
  }

  for (final MapEntry(key: name, value: (decode, document)) in valid.entries) {
    test(
      '$name decodes every mutation or refuses it with a 422-class error',
      () {
        expect(
          decode(document),
          isNotNull,
          reason: 'the seed document decodes',
        );
        final random = Random(20260930);
        for (var i = 0; i < iterations; i++) {
          final mutated = mutate(document, random);
          if (mutated is! Map<String, Object?>) continue;
          try {
            decode(mutated);
          } on BeakConfigurationException {
            // Refused, which the server answers with a 422.
          } on Object catch (error) {
            fail('${error.runtimeType} for ${jsonEncode(mutated)}: $error');
          }
        }
      },
    );
  }
}
