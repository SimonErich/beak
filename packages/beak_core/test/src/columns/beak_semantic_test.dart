import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'structured JSON supports declared raw documents and unknown nested values',
    () {
      const document = BeakJsonColumn(key: 'document', label: 'Document');
      const instant = BeakDateTimeColumn(key: 'instant', label: 'Instant');
      const schema = BeakObjectSchema(
        columns: [document, instant],
        allowUnknown: true,
      );
      final tree = BeakJson.decode('[{"x":1},true]');
      final object = schema.write(document, const BeakJsonObject({}), tree);
      expect(object.entries['document'], tree);
      expect(schema.readValue<BeakJson>(document, object), tree);
      final withUnknown = BeakJsonObject({
        ...object.entries,
        'instant': const BeakJsonString('2026-01-01T01:02:00Z'),
        'unknown': const BeakJsonArray([
          BeakJsonObject({'x': BeakJsonNumber(1)}),
        ]),
        'unknownObject': const BeakJsonObject({'nested': BeakJsonBool(true)}),
        'scalar': const BeakJsonNumber(1),
      });
      final record = schema.toRecord(withUnknown);
      expect(
        record['instant'],
        BeakDateTimeValue(DateTime.utc(2026, 1, 1, 1, 2)),
      );
      expect(record['unknown'], const BeakStringValue('[{"x":1}]'));
      expect(record['unknownObject'], const BeakStringValue('{"nested":true}'));
      expect(record['scalar'], const BeakIntValue(1));
      expect(schema.readValue<int>(document, object), isNull);
      expect(
        () => schema.write(
          const BeakStringColumn(key: 'other', label: 'Other'),
          object,
          'bad',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'semantic codecs report wrong shapes and malformed metadata deterministically',
    () {
      const date = BeakSemantic.calendarDate();
      const time = BeakSemantic.time();
      const object = BeakSemantic.object(BeakObjectSchema(columns: []));
      for (final codec in [date, time, object]) {
        expect(codec.tryDecode(const BeakIntValue(1)), isNull);
        expect(() => codec.encode(1), throwsFormatException);
      }
      expect(
        const BeakSemantic.exactDecimal(
          scale: 3,
        ).decode(const BeakIntValue(125)),
        const BeakDecimal(125, scale: 3),
      );
      expect(
        () => const BeakSemantic(
          kind: BeakSemanticKind.primitiveList,
        ).encode(<String>[]),
        throwsFormatException,
      );
      const integer = BeakIntColumn(key: 'number', label: 'Number');
      const schema = BeakObjectSchema(columns: [integer]);
      expect(
        schema.readValue<int>(
          integer,
          const BeakJsonObject({'number': BeakJsonNumber(2)}),
        ),
        2,
      );
      expect(schema.read(integer, const BeakJsonObject({})), isNull);
    },
  );

  test('plain JSON fields provide typed trees and canonical wire values', () {
    const column = BeakJsonColumn(key: 'document', label: 'Document');
    const field = BeakScalarField<BeakJson>(
      model: _SemanticModel(),
      column: column,
    );
    final document = BeakJson.decode('{"nested":[1,true,null]}');
    final record = field.writeTo(const BeakRecord(values: {}), document);
    expect(field.require(record), document);
    expect(
      field.encode(document),
      const BeakStringValue('{"nested":[1,true,null]}'),
    );
    expect(column.readDocument(record['document']), document);
    expect(column.readDocument(const BeakStringValue('not json')), isNull);
    expect(field.readFrom(const BeakRecord(values: {})), isNull);
  });

  test(
    'structured object timestamps preserve their tagged wire representation',
    () {
      const column = BeakDateTimeColumn(key: 'at', label: 'At');
      const schema = BeakObjectSchema(columns: [column]);
      final timestamp = DateTime.utc(2026, 1, 2, 3, 4);
      final object = schema.write(column, const BeakJsonObject({}), timestamp);
      expect(schema.read(column, object), timestamp);
      expect(schema.toRecord(object)['at'], BeakDateTimeValue(timestamp));
    },
  );

  test(
    'model registration rejects invalid defaults before forms or persistence run',
    () {
      const invalid = BeakIntColumn(
        key: 'amount',
        label: 'Amount',
        defaultValue: -1,
        rules: [BeakMin(0)],
      );
      expect(
        () => BeakModelRegistry().register(const _DefaultModel(invalid)),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('defaults.amount'),
          ),
        ),
      );
      const valid = BeakJsonColumn(
        key: 'amount',
        label: 'Amount',
        defaultValue: <String>[],
        semantic: BeakSemantic.list(BeakPrimitiveType.string),
        rules: [BeakRequired(allowEmpty: true)],
      );
      expect(
        () => BeakModelRegistry().register(const _DefaultModel(valid)),
        returnsNormally,
      );
    },
  );

  test(
    'typed exact sum decodes storage units and refuses lossy aggregates',
    () async {
      const column = BeakIntColumn(
        key: 'amount',
        label: 'Amount',
        semantic: BeakSemantic.money(scale: 3, currency: 'EUR'),
      );
      const field = BeakScalarField<BeakDecimal>(
        model: _SemanticModel(),
        column: column,
      );
      final source = _AggregateSource(12345);
      expect(await field.sum(source), BeakDecimal.parse('12.345', scale: 3));
      expect(source.spec!.columnKey, 'amount');
      expect(source.spec!.function, BeakAggregateFunction.sum);
      for (final invalid in [1.5, double.infinity, BeakDecimal.maxUnits + 1]) {
        expect(
          () => field.sum(_AggregateSource(invalid)),
          throwsA(isA<BeakConfigurationException>()),
        );
      }
    },
  );

  test(
    'date and time boundaries reject malformed syntax and preserve ordering',
    () {
      for (final input in [
        '0000-01-01',
        '1900-02-29',
        '2026-04-31',
        '2026-13-01',
        '2026-01-00',
        '26-1-1',
        'wrong',
      ]) {
        expect(BeakDate.tryParse(input), isNull, reason: input);
        expect(() => BeakDate.parse(input), throwsFormatException);
      }
      final leap = BeakDate.fromDateTime(DateTime.utc(2000, 2, 29, 23));
      expect(leap.toDateTime(), DateTime(2000, 2, 29));
      expect(leap.compareTo(const BeakDate(2000, 3, 1)), isNegative);
      expect(leap.hashCode, const BeakDate(2000, 2, 29).hashCode);
      for (final input in [
        '00:60',
        '00:00:60',
        '1:02',
        '00:00Z',
        '12:00:00.1234567',
        'bad',
      ]) {
        expect(BeakTime.tryParse(input), isNull, reason: input);
        expect(() => BeakTime.parse(input), throwsFormatException);
      }
      final time = BeakTime.parse('00:00:00.1');
      expect(time.microsecondsSinceMidnight, 100000);
      expect(time.compareTo(BeakTime.parse('00:01')), isNegative);
      expect(time.hashCode, const BeakTime(0, 0, microsecond: 100000).hashCode);
    },
  );

  test(
    'exact decimal arithmetic checks precision, range, signs and normalized equality',
    () {
      final whole = BeakDecimal.parse('+0012', scale: 0);
      expect(whole.toString(), '12');
      expect((whole * -2).toString(), '-24');
      expect((whole - BeakDecimal.parse('0.25')).toString(), '11.75');
      expect(BeakDecimal.parse('1.2000'), BeakDecimal.parse('1.20'));
      expect(
        BeakDecimal.parse('1.2', scale: 1).hashCode,
        BeakDecimal.parse('1.20').hashCode,
      );
      expect(
        BeakDecimal.parse('-2').compareTo(BeakDecimal.parse('-1')),
        isNegative,
      );
      expect(BeakDecimal.parse('1.00').rescale(0).toString(), '1');
      expect(() => BeakDecimal.parse('0.01').rescale(1), throwsFormatException);
      expect(
        () =>
            const BeakDecimal(BeakDecimal.maxUnits, scale: 0) +
            const BeakDecimal(1, scale: 0),
        throwsFormatException,
      );
      expect(
        () => const BeakDecimal(BeakDecimal.maxUnits, scale: 0) * 2,
        throwsFormatException,
      );
      expect(() => whole.rescale(13), throwsRangeError);
      for (final input in ['NaN', '1e3', '.', '1.2.3', '']) {
        expect(BeakDecimal.tryParse(input), isNull);
      }
      expect(BeakDecimal.tryParse('1', scale: -1), isNull);
    },
  );

  test(
    'all primitive list codecs preserve their declared generic element types',
    () {
      const integers = BeakSemantic.list(BeakPrimitiveType.integer);
      const decimals = BeakSemantic.list(BeakPrimitiveType.decimal);
      const booleans = BeakSemantic.list(BeakPrimitiveType.boolean);
      expect(integers.decode(integers.encode([1, -2])), isA<List<int>>());
      expect(decimals.decode(decimals.encode([1, 2.5])), <double>[1, 2.5]);
      expect(
        booleans.decode(booleans.encode([true, false])),
        isA<List<bool>>(),
      );
      for (final (codec, value) in <(BeakSemantic, Object)>[
        (integers, <Object>[1.5]),
        (decimals, <Object>[double.infinity]),
        (booleans, <Object>[1]),
        (integers, 'not json'),
        (integers, <Object?>[null]),
        (integers, 1),
      ]) {
        expect(() => codec.encode(value), throwsFormatException);
      }
      final list = integers.decode(integers.encode([1]));
      if (list is List<int>) expect(() => list.add(2), throwsUnsupportedError);
      expect(integers.encode(null), const BeakNullValue());
      expect(integers.decode(const BeakNullValue()), isNull);
    },
  );

  test(
    'semantic wire coercion rejects lossy numbers and tolerates bad stored data',
    () {
      const money = BeakSemantic.money();
      expect(money.encode(const BeakIntValue(125)), const BeakIntValue(125));
      expect(
        money.decode(const BeakStringValue('125')),
        const BeakDecimal(125),
      );
      expect(() => money.encode(1.25), throwsFormatException);
      expect(
        () => money.encode(BeakDecimal.maxUnits + 1),
        throwsFormatException,
      );
      expect(
        const BeakSemantic.time().encode('01:02'),
        const BeakStringValue('01:02:00'),
      );
      expect(
        const BeakSemantic.duration().decode(const BeakIntValue(-1000000)),
        const Duration(seconds: -1),
      );
      expect(
        const BeakSemantic().encode(_Choice.first),
        const BeakStringValue('first'),
      );
      const currency = BeakStringColumn(key: 'currency', label: 'Currency');
      const amount = BeakSemantic.money(currencyColumn: currency);
      expect(
        amount.currencyFor(BeakRecord.fromRow({'currency': 'EUR'})),
        'EUR',
      );
      expect(amount.currencyFor(const BeakRecord(values: {})), isNull);
      expect(
        const BeakSemantic.money(
          currency: 'USD',
        ).currencyFor(const BeakRecord(values: {})),
        'USD',
      );
      const column = BeakIntColumn(
        key: 'amount',
        label: 'Amount',
        semantic: money,
      );
      expect(
        beakValueForColumn(column, 'invalid'),
        const BeakStringValue('invalid'),
      );
    },
  );

  test(
    'semantic fields expose null, required failures and all ordered predicates',
    () {
      const column = BeakStringColumn(
        key: 'day',
        label: 'Day',
        semantic: BeakSemantic.calendarDate(),
      );
      const field = BeakScalarField<BeakDate>(
        model: _SemanticModel(),
        column: column,
      );
      const empty = BeakRecord(values: {});
      const day = BeakDate(2026, 1, 1);
      expect(field.readFrom(BeakRecord.fromRow({'day': 'bad'})), isNull);
      expect(
        () => field.require(empty),
        throwsA(isA<BeakRecordShapeException>()),
      );
      for (final (filter, operator) in [
        (field.gt(day), BeakOperator.gt),
        (field.gte(day), BeakOperator.gte),
        (field.lt(day), BeakOperator.lt),
        (field.lte(day), BeakOperator.lte),
      ]) {
        expect(
          filter,
          BeakFieldFilter.forKey(
            'day',
            operator,
            const BeakStringValue('2026-01-01'),
          ),
        );
      }
      expect(
        field.notEq(null),
        const BeakFieldFilter.forKey(
          'day',
          BeakOperator.isNotNull,
          BeakNullValue(),
        ),
      );
      const related = BeakScalarField<BeakDate>(
        model: _SemanticModel(),
        column: column,
        path: [
          BeakBelongsTo(
            key: 'owner',
            label: 'Owner',
            relatedTable: 'values',
            foreignKey: 'owner_id',
            displayColumnKey: 'day',
          ),
        ],
      );
      expect(
        () => related.writeTo(empty, day),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test('defaults and format copies retain declared column metadata', () {
    const column = BeakDateTimeColumn(
      key: 'date',
      label: 'Date',
      indexed: true,
      unique: true,
      defaultValue: '2026-01-01T00:00:00Z',
    );
    final changed = column.withFormat(BeakDateFormat.dateOnly);
    expect(changed.indexed, isTrue);
    expect(changed.unique, isTrue);
    expect(changed.defaultValue, column.defaultValue);
    const enumeration = BeakEnumColumn<_Choice>(
      key: 'choice',
      label: 'Choice',
      values: _Choice.values,
      defaultValue: _Choice.first,
    );
    expect(enumeration.defaultValue, _Choice.first);
    expect(
      () => BeakModelRegistry().register(const _PasswordModel()),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  test('calendar dates validate leap days without timezone conversion', () {
    expect(BeakDate.parse('2024-02-29'), const BeakDate(2024, 2, 29));
    expect(BeakDate.tryParse('2023-02-29'), isNull);
    expect(BeakDate.tryParse('2024-02-29T00:00:00Z'), isNull);
    expect(const BeakDate(2024, 2, 29).toString(), '2024-02-29');
  });

  test('time of day preserves microseconds and rejects overflow', () {
    final time = BeakTime.parse('23:59:58.123456');
    expect(time, const BeakTime(23, 59, second: 58, microsecond: 123456));
    expect(time.toString(), '23:59:58.123456');
    expect(BeakTime.tryParse('24:00'), isNull);
  });

  test('exact decimals never pass through binary floating point', () {
    final value = BeakDecimal.parse('1234567890123.45');
    expect(value.units, 123456789012345);
    expect(value.toString(), '1234567890123.45');
    expect(
      BeakDecimal.parse('0.10') + BeakDecimal.parse('0.20'),
      BeakDecimal.parse('0.30'),
    );
    expect(BeakDecimal.tryParse('1.001'), isNull);
    expect(BeakDecimal.parse('-0.01').rescale(3).toString(), '-0.010');
    expect(
      () => BeakDecimal.parse('900719925474099.99'),
      throwsFormatException,
    );
  });

  test('semantic codecs preserve storage primitives and typed values', () {
    const date = BeakSemantic.calendarDate();
    const money = BeakSemantic.money(scale: 3, currency: 'EUR');
    expect(
      date.encode(const BeakDate(2026, 1, 2)),
      const BeakStringValue('2026-01-02'),
    );
    expect(
      date.decode(const BeakStringValue('2026-01-02')),
      const BeakDate(2026, 1, 2),
    );
    expect(
      money.encode(BeakDecimal.parse('0.125', scale: 3)),
      const BeakIntValue(125),
    );
    expect(
      money.decode(const BeakIntValue(125)),
      BeakDecimal.parse('0.125', scale: 3),
    );
    expect(
      const BeakSemantic.duration().encode(const Duration(seconds: 2)),
      const BeakIntValue(2000000),
    );
    expect(date.tryDecode(const BeakStringValue('nonsense')), isNull);
  });

  test('typed primitive lists round trip and reject mixed element types', () {
    const tags = BeakSemantic.list(BeakPrimitiveType.string);
    expect(tags.decode(tags.encode(['a', 'b'])), isA<List<String>>());
    expect(tags.decode(tags.encode(['a', 'b'])), ['a', 'b']);
    expect(
      () => tags.decode(const BeakStringValue('["a",1]')),
      throwsFormatException,
    );
  });

  test(
    'semantic field references round trip typed values and scaled predicates',
    () {
      const model = _SemanticModel();
      const column = BeakIntColumn(
        key: 'amount',
        label: 'Amount',
        semantic: BeakSemantic.money(scale: 3, currency: 'EUR'),
      );
      const field = BeakScalarField<BeakDecimal>(model: model, column: column);
      final amount = BeakDecimal.parse('12.345', scale: 3);
      final record = field.writeTo(const BeakRecord(values: {}), amount);
      expect(field.require(record), amount);
      expect(
        field.eq(amount),
        const BeakFieldFilter.forKey(
          'amount',
          BeakOperator.eq,
          BeakIntValue(12345),
        ),
      );
      expect(
        field.gte(amount),
        const BeakFieldFilter.forKey(
          'amount',
          BeakOperator.gte,
          BeakIntValue(12345),
        ),
      );
      expect(beakValueForColumn(column, amount), const BeakIntValue(12345));
      expect(beakValueForColumn(column, '12345'), const BeakIntValue(12345));
    },
  );

  test(
    'structured objects retain nested JSON shapes without stringification',
    () {
      const tags = BeakJsonColumn(
        key: 'tags',
        label: 'Tags',
        semantic: BeakSemantic.list(BeakPrimitiveType.string),
      );
      const count = BeakIntColumn(key: 'count', label: 'Count');
      const nestedSchema = BeakObjectSchema(columns: [count]);
      const nested = BeakJsonColumn(
        key: 'nested',
        label: 'Nested',
        semantic: BeakSemantic.object(nestedSchema),
      );
      const schema = BeakObjectSchema(columns: [tags, nested]);
      final object = schema.write(tags, const BeakJsonObject({}), ['a', 'b']);
      final complete = schema.write(
        nested,
        object,
        const BeakJsonObject({'count': BeakJsonNumber(2)}),
      );
      expect(complete.entries['tags'], isA<BeakJsonArray>());
      expect(complete.entries['nested'], isA<BeakJsonObject>());
      expect(schema.readValue<List<String>>(tags, complete), ['a', 'b']);
      expect(
        schema.toRecord(complete)['nested'],
        const BeakStringValue('{"count":2}'),
      );
    },
  );

  test('structured JSON properties use reusable typed columns', () {
    const name = BeakStringColumn(key: 'name', label: 'Name');
    const shape = BeakObjectSchema(columns: [name]);
    const semantic = BeakSemantic.object(shape);
    const value = BeakJsonObject({'name': BeakJsonString('Ada')});
    expect(semantic.decode(semantic.encode(value)), value);
    expect(shape.read(name, value), 'Ada');
    expect(shape.read(name, shape.write(name, value, 'Grace')), 'Grace');
  });
}

final class _SemanticModel extends BeakModel {
  const _SemanticModel();
  @override
  String get table => 'values';
  @override
  String get displayColumnKey => 'amount';
  @override
  List<BeakColumn> get columns => const [];
}

enum _Choice { first }

final class _PasswordModel extends BeakModel {
  const _PasswordModel();
  @override
  String get table => 'secret';
  @override
  String get displayColumnKey => 'secret';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(
      key: 'secret',
      label: 'Secret',
      semantic: BeakSemantic.password(),
    ),
  ];
}

final class _AggregateSource implements BeakDataSource {
  _AggregateSource(this.result);
  final num result;
  BeakAggregateSpec? spec;
  @override
  Future<num> aggregate(BeakAggregateSpec spec) async {
    this.spec = spec;
    return result;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DefaultModel extends BeakModel {
  const _DefaultModel(this.column);
  final BeakColumn column;
  @override
  String get table => 'defaults';
  @override
  String get displayColumnKey => 'amount';
  @override
  List<BeakColumn> get columns => [column];
}
