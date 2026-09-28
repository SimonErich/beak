import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

final class _Model extends BeakModel {
  const _Model();
  @override
  String get table => 'rows';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];
}

BeakScalarField<T> field<T extends Object>(String key, BeakColumn column) =>
    BeakScalarField<T>(model: const _Model(), column: column);
const text = BeakScalarField<String>(
  model: _Model(),
  column: BeakStringColumn(key: 'text', label: 'Text'),
);
const other = BeakScalarField<String>(
  model: _Model(),
  column: BeakStringColumn(key: 'other', label: 'Other'),
);
const rows = BeakToManyField(
  model: _Model(),
  target: _Model(),
  relation: BeakHasMany(
    key: 'rows',
    label: 'Rows',
    relatedTable: 'rows',
    displayColumnKey: 'text',
    foreignKey: 'parent_id',
  ),
);
BeakRecord collection(List<BeakRecord> children) =>
    BeakRecord(values: const {}, relations: {'rows': children});

void main() {
  test(
    'conditions compose typed presence/equality and route errors to fields',
    () {
      final present = BeakWhen.present(text);
      final equality = BeakWhen.equals(other, 'yes');
      final all = BeakWhen.all([present, equality]);
      final any = BeakWhen.any([present, equality]);
      final record = BeakRecord.fromRow({'text': 'value', 'other': 'no'});
      expect(all.matches(record), isFalse);
      expect(all.not.matches(record), isTrue);
      expect(any.matches(record), isTrue);
      expect(any.fields, [text, other]);
      expect(
        BeakRequiredIf(
          other,
          when: present,
        ).validate(BeakRecord.fromRow({'text': 'value'})),
        {
          'other': ['This field is required.'],
        },
      );
      expect(const BeakSameAs(text, other).validate(record), {
        'text': ['Must match Other.'],
      });
      expect(
        const BeakSameAs(text, other).validate(BeakRecord.fromRow({})),
        isEmpty,
      );
    },
  );

  void ordered<T extends Object>(
    String name,
    BeakColumn aColumn,
    BeakColumn bColumn,
    T early,
    T late,
  ) {
    test('$name comparisons use semantic values on both boundaries', () {
      final a = field<T>('a', aColumn);
      final b = field<T>('b', bColumn);
      BeakRecord pair(T? x, T? y) => BeakRecord(
        values: {
          'a': aColumn.semantic.encode(x),
          'b': bColumn.semantic.encode(y),
        },
      );
      expect(BeakBeforeField(a, b).validate(pair(early, late)), isEmpty);
      expect(BeakBeforeField(a, b).validate(pair(late, early)), isNotEmpty);
      expect(BeakBeforeField(a, b).validate(pair(early, early)), isNotEmpty);
      expect(
        BeakBeforeField(a, b, inclusive: true).validate(pair(early, early)),
        isEmpty,
      );
      expect(BeakAfterField(a, b).validate(pair(late, early)), isEmpty);
      expect(BeakAfterField(a, b).validate(pair(early, late)), isNotEmpty);
      expect(
        BeakAfterField(a, b, inclusive: true).validate(pair(early, early)),
        isEmpty,
      );
      expect(BeakAfterField(a, b).validate(pair(null, early)), isEmpty);
    });
  }

  ordered(
    'calendar dates',
    const BeakStringColumn(
      key: 'a',
      label: 'A',
      semantic: BeakSemantic.calendarDate(),
    ),
    const BeakStringColumn(
      key: 'b',
      label: 'B',
      semantic: BeakSemantic.calendarDate(),
    ),
    const BeakDate(2026, 1, 1),
    const BeakDate(2026, 2, 1),
  );
  ordered(
    'times',
    const BeakStringColumn(key: 'a', label: 'A', semantic: BeakSemantic.time()),
    const BeakStringColumn(key: 'b', label: 'B', semantic: BeakSemantic.time()),
    const BeakTime(8, 0),
    const BeakTime(9, 0),
  );
  ordered(
    'durations',
    const BeakIntColumn(
      key: 'a',
      label: 'A',
      semantic: BeakSemantic.duration(),
    ),
    const BeakIntColumn(
      key: 'b',
      label: 'B',
      semantic: BeakSemantic.duration(),
    ),
    const Duration(minutes: 1),
    const Duration(minutes: 2),
  );
  ordered(
    'exact money',
    const BeakIntColumn(key: 'a', label: 'A', semantic: BeakSemantic.money()),
    const BeakIntColumn(key: 'b', label: 'B', semantic: BeakSemantic.money()),
    const BeakDecimal(100),
    const BeakDecimal(101),
  );
  ordered(
    'numbers',
    const BeakIntColumn(key: 'a', label: 'A'),
    const BeakIntColumn(key: 'b', label: 'B'),
    1,
    2,
  );
  test(
    'rule dependencies declare nested reads for server graph validation',
    () {
      const relation = BeakBelongsTo(
        key: 'owner',
        label: 'Owner',
        relatedTable: 'rows',
        displayColumnKey: 'text',
        foreignKey: 'owner_id',
      );
      const owner = BeakToOneField(
        model: _Model(),
        target: _Model(),
        relation: relation,
      );
      const nested = BeakScalarField<String>(
        model: _Model(),
        column: BeakStringColumn(key: 'text', label: 'Text'),
        path: [relation],
      );
      final required = BeakRequiredIf(owner, when: BeakWhen.present(text));
      expect(required.fields, [owner, text]);
      expect(required.relationLoads.single.relationKey, 'owner');
      expect(const BeakSameAs(text, other).fields, [text, other]);
      expect(const BeakBeforeField(text, other).fields, [text, other]);
      expect(const BeakAfterField(text, other).fields, [text, other]);
      const distinct = BeakDistinct(rows, nested);
      expect(distinct.fields, [rows]);
      expect(distinct.relationLoads.single.nested.single.relationKey, 'owner');
      const sum = BeakSum(rows, text);
      expect(sum.fields, [rows]);
      expect(sum.relationLoads.single.relationKey, 'rows');
      const unique = BeakUnique(text, scope: [other]);
      expect(unique.fields, [text, other]);
      expect(unique.validate(BeakRecord.fromRow({})), isEmpty);
      const exists = BeakExists(
        text,
        other,
        matching: [BeakFieldMatch(target: other, source: text)],
      );
      expect(exists.fields, [text, text]);
      expect(
        () => const BeakBeforeField(
          text,
          other,
        ).validate(BeakRecord.fromRow({'text': 'a', 'other': 'b'})),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => sum.validate(
          collection([
            BeakRecord.fromRow({'text': 'a'}),
          ]),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'exact aggregate sums reject one cent excess and overflow without rounding',
    () {
      const money = BeakScalarField<BeakDecimal>(
        model: _Model(),
        column: BeakIntColumn(
          key: 'money',
          label: 'Money',
          semantic: BeakSemantic.money(),
        ),
      );
      const rule = BeakSum(
        rows,
        money,
        min: BeakDecimal(1),
        max: BeakDecimal(30),
      );
      BeakRecord amounts(List<int> units) => collection([
        for (final value in units) BeakRecord.fromRow({'money': value}),
      ]);
      expect(rule.validate(amounts([10, 20])), isEmpty);
      expect(rule.validate(amounts([10, 21])), {
        'rows': ['The total must be at most 0.30.'],
      });
      expect(rule.validate(amounts([])), {
        'rows': ['The total must be at least 0.01.'],
      });
      expect(rule.validate(amounts([BeakDecimal.maxUnits, 1])), {
        'rows': ['The aggregate amount is too large.'],
      });
      expect(
        const BeakDistinct(rows, text).validate(
          collection([BeakRecord.fromRow({}), BeakRecord.fromRow({})]),
        ),
        isEmpty,
      );
      expect(
        const BeakDistinct(rows, text, ignoreNull: false).validate(
          collection([BeakRecord.fromRow({}), BeakRecord.fromRow({})]),
        ),
        isNotEmpty,
      );
      expect(
        const BeakCount(rows, max: 1).validate(amounts([1, 2])),
        isNotEmpty,
      );
      expect(
        const BeakCount(text).validate(BeakRecord.fromRow({'text': 'x'})),
        isNotEmpty,
      );
      expect(const BeakCount(rows).relationLoads.single.relationKey, 'rows');
    },
  );
  test(
    'numeric rules compare exact semantic units to decimal bounds without doubles',
    () {
      expect(
        const BeakMin(0.101).validate(const BeakDecimal(10)),
        'Must be at least 0.101.',
      );
      expect(
        const BeakMax(0.099).validate(const BeakDecimal(10)),
        'Must be at most 0.099.',
      );
      expect(
        const BeakMin(1e-9).validate(const BeakDecimal(1, scale: 9)),
        isNull,
      );
      expect(
        const BeakMax(1e20).validate(const BeakDecimal(BeakDecimal.maxUnits)),
        isNull,
      );
      expect(const BeakMin(-1).validate(const BeakDecimal(-101)), isNotNull);
      const column = BeakIntColumn(
        key: 'money',
        label: 'Money',
        min: 1,
        semantic: BeakSemantic.money(),
      );
      expect(
        const BeakValidation().columnErrors(column, const BeakDecimal(99)),
        ['Must be at least 1.'],
      );
    },
  );
}
