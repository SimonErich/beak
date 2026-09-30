import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/data/worm/query_translator.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/api_models.dart';

/// A filter whose operand does not fit the column it compares is the caller's
/// mistake: every database would either refuse it (Postgres answers a type
/// error, which used to surface as a 500) or quietly compare text with numbers
/// (SQLite), so the translator names the mismatch and the server answers 422.
final class _LedgerModel extends BeakModel {
  const _LedgerModel();

  @override
  String get table => 'ledger';

  @override
  String get displayColumnKey => 'memo';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'memo', label: 'Memo'),
    BeakIntColumn(
      key: 'amount',
      label: 'Amount',
      semantic: BeakSemantic.money(currency: 'EUR'),
    ),
    BeakStringColumn(
      key: 'booked_on',
      label: 'Booked on',
      semantic: BeakSemantic.calendarDate(),
    ),
    BeakDecimalColumn(key: 'rate', label: 'Rate'),
    BeakJsonColumn(key: 'extra', label: 'Extra'),
  ];
}

void main() {
  late Handler handler;

  setUp(() async {
    Worm.seedRandom(42);
    final registry = createApiRegistry();
    final adapter = await createApiTestDatabase();
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
          ),
        );
  });

  tearDown(Worm.reset);

  Map<String, Object?> field(String column, String operator, Object? value) => {
    'type': 'field',
    'column': column,
    'operator': operator,
    'value': value,
  };

  Future<Response> query(Map<String, Object?> filter) async => handler(
    Request(
      'POST',
      Uri.parse('http://localhost/api/notes/query'),
      body: jsonEncode({
        'table': 'notes',
        'filter': filter,
        'sorts': const <Object?>[],
        'relations': const <Object?>[],
      }),
    ),
  );

  Future<void> expectRefused(
    Map<String, Object?> filter, {
    required String mentions,
  }) async {
    final response = await query(filter);
    final body = jsonDecode(await response.readAsString());
    expect(response.statusCode, 422, reason: '$body');
    expect(body, containsPair('code', 'validation'));
    expect(body, containsPair('message', contains(mentions)));
  }

  group('a single value is required by a comparison', () {
    for (final operator in ['eq', 'neq', 'gt', 'gte', 'lt', 'lte']) {
      test('$operator refuses a list', () {
        return expectRefused(
          field('rating', operator, [1, 2]),
          mentions: 'single value',
        );
      });
    }

    test('a list element that is itself a list is refused', () {
      return expectRefused(
        field('rating', 'inList', [
          [1],
        ]),
        mentions: 'single value',
      );
    });
  });

  group('an operand must fit the column type', () {
    test('a string for an integer column', () {
      return expectRefused(
        field('rating', 'gt', 'abc'),
        mentions: 'integer operand',
      );
    });

    test('a string equality on an integer column', () {
      return expectRefused(
        field('rating', 'eq', 'abc'),
        mentions: 'integer operand',
      );
    });

    test('a fraction for an integer column', () {
      return expectRefused(
        field('rating', 'gt', 2.5),
        mentions: 'integer operand',
      );
    });

    test('an integer for a boolean column', () {
      return expectRefused(
        field('published', 'eq', 5),
        mentions: 'boolean operand',
      );
    });

    test('an integer for a timestamp column', () {
      return expectRefused(
        field('created_at', 'gt', 5),
        mentions: 'timestamp operand',
      );
    });

    test('a bare string for a timestamp column', () {
      return expectRefused(
        field('created_at', 'gt', 'yesterday'),
        mentions: 'timestamp operand',
      );
    });

    test('an integer for a text column', () {
      return expectRefused(field('title', 'eq', 5), mentions: 'text operand');
    });

    test('a mixed inList names the offending element', () {
      return expectRefused(
        field('rating', 'inList', [1, 'x']),
        mentions: 'integer operand',
      );
    });

    test('mixed between bounds', () {
      return expectRefused(
        field('rating', 'between', ['a', 'b']),
        mentions: 'integer operand',
      );
    });

    test('text containing NUL, which no database stores', () {
      return expectRefused(field('title', 'eq', 'a\u0000b'), mentions: 'NUL');
    });

    test('a NUL inside a substring pattern', () {
      return expectRefused(
        field('title', 'contains', 'a\u0000b'),
        mentions: 'NUL',
      );
    });
  });

  group('pattern operators only apply to text columns', () {
    for (final operator in [
      'like',
      'ilike',
      'contains',
      'startsWith',
      'endsWith',
    ]) {
      test('$operator on an integer column', () {
        return expectRefused(
          field('rating', operator, '3'),
          mentions: 'text fields',
        );
      });
    }

    test('contains on a timestamp column', () {
      return expectRefused(
        field('created_at', 'contains', '2026'),
        mentions: 'text fields',
      );
    });

    test('ilike on a boolean column', () {
      return expectRefused(
        field('published', 'ilike', '%'),
        mentions: 'text fields',
      );
    });
  });

  group('operands that fit stay accepted', () {
    final accepted = <String, Map<String, Object?>>{
      'int equality': field('rating', 'eq', 3),
      'int range': field('rating', 'between', [1, 5]),
      'int list': field('rating', 'inList', [1, 2, 3]),
      'null inside a list': field('rating', 'inList', [1, null]),
      'null equality': field('rating', 'eq', null),
      'null bound': field('rating', 'between', [null, 3]),
      'bool equality': field('published', 'eq', true),
      'text equality': field('title', 'eq', 'a'),
      'text pattern': field('title', 'contains', 'a'),
      'enum name': field('status', 'eq', 'draft'),
      'timestamp': field('created_at', 'gt', {
        'type': 'dateTime',
        'value': '2020-01-01T00:00:00Z',
      }),
      'is null with an operand of no meaning': field('rating', 'isNull', null),
      'empty list': field('rating', 'inList', <Object?>[]),
    };
    for (final MapEntry(:key, :value) in accepted.entries) {
      test(key, () async {
        final response = await query(value);
        expect(response.statusCode, 200, reason: await response.readAsString());
      });
    }
  });

  group('the translator checks storage types, not display types', () {
    const registryModel = _LedgerModel();
    final registry = BeakModelRegistry()..register(registryModel);

    BeakFieldFilter filter(String key, BeakOperator op, BeakValue value) =>
        BeakFieldFilter.forKey(key, op, value);

    test('a money column takes the integer units its semantic encodes', () {
      final predicate = WormQueryTranslator(registry).predicateFor(
        filter('amount', BeakOperator.gte, const BeakIntValue(1234)),
        registryModel,
      );
      expect(predicate, isNotNull);
    });

    test('a money column refuses text', () {
      expect(
        () => WormQueryTranslator(registry).predicateFor(
          filter('amount', BeakOperator.gte, const BeakStringValue('12.34')),
          registryModel,
        ),
        throwsA(
          isA<BeakValidationException>().having(
            (error) => error.message,
            'message',
            contains('integer operand'),
          ),
        ),
      );
    });

    test('a calendar-date column takes its ISO text', () {
      final predicate = WormQueryTranslator(registry).predicateFor(
        filter(
          'booked_on',
          BeakOperator.eq,
          const BeakStringValue('2026-01-31'),
        ),
        registryModel,
      );
      expect(predicate, isNotNull);
    });

    test('a calendar-date column refuses a timestamp', () {
      expect(
        () => WormQueryTranslator(registry).predicateFor(
          filter(
            'booked_on',
            BeakOperator.eq,
            BeakDateTimeValue(DateTime.utc(2026)),
          ),
          registryModel,
        ),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('a decimal column takes integers and fractions', () {
      final translator = WormQueryTranslator(registry);
      for (final value in [const BeakIntValue(2), const BeakDoubleValue(2.5)]) {
        expect(
          translator.predicateFor(
            filter('rate', BeakOperator.gt, value),
            registryModel,
          ),
          isNotNull,
        );
      }
    });

    test('a JSON column takes any single value', () {
      final translator = WormQueryTranslator(registry);
      expect(
        translator.predicateFor(
          filter('extra', BeakOperator.eq, const BeakIntValue(1)),
          registryModel,
        ),
        isNotNull,
      );
    });

    test('a dotted path checks the related model\'s column', () {
      final notes = createApiRegistry();
      expect(
        () => WormQueryTranslator(notes).predicateFor(
          filter('author.name', BeakOperator.eq, const BeakIntValue(3)),
          const NoteModel(),
        ),
        throwsA(isA<BeakValidationException>()),
      );
    });
  });
}
