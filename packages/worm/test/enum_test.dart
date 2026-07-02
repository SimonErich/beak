import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('Operator', () {
    test('has 15 variants', () {
      expect(Operator.values.length, 15);
    });

    test('all variants exist', () {
      expect(
        Operator.values,
        containsAll(<Operator>[
          Operator.eq,
          Operator.neq,
          Operator.gt,
          Operator.gte,
          Operator.lt,
          Operator.lte,
          Operator.like,
          Operator.notLike,
          Operator.ilike,
          Operator.isNull,
          Operator.isNotNull,
          Operator.inList,
          Operator.notInList,
          Operator.between,
          Operator.notBetween,
        ]),
      );
    });
  });

  group('OnDelete', () {
    test('has 6 variants', () {
      expect(OnDelete.values.length, 6);
    });

    test('all variants exist', () {
      expect(
        OnDelete.values,
        containsAll(<OnDelete>[
          OnDelete.cascade,
          OnDelete.ormCascade,
          OnDelete.restrict,
          OnDelete.setNull,
          OnDelete.setDefault,
          OnDelete.noAction,
        ]),
      );
    });
  });

  group('PrimaryKeyType', () {
    test('has 2 variants', () {
      expect(PrimaryKeyType.values.length, 2);
    });

    test('all variants exist', () {
      expect(
        PrimaryKeyType.values,
        containsAll(<PrimaryKeyType>[
          PrimaryKeyType.uuid,
          PrimaryKeyType.integer,
        ]),
      );
    });
  });

  group('Environment', () {
    test('has 5 variants', () {
      expect(Environment.values.length, 5);
    });

    test('all variants exist', () {
      expect(
        Environment.values,
        containsAll(<Environment>[
          Environment.development,
          Environment.staging,
          Environment.production,
          Environment.testing,
          Environment.all,
        ]),
      );
    });
  });

  group('ColumnType', () {
    test('has 27 variants', () {
      expect(ColumnType.values.length, 27);
    });

    test('core variants exist', () {
      expect(
        ColumnType.values,
        containsAll(<ColumnType>[
          ColumnType.string,
          ColumnType.integer,
          ColumnType.bigInteger,
          ColumnType.decimal,
          ColumnType.boolean,
          ColumnType.date,
          ColumnType.dateTime,
          ColumnType.uuid,
          ColumnType.json,
          ColumnType.jsonb,
          ColumnType.text,
          ColumnType.binary,
          ColumnType.doublePrecision,
          ColumnType.enumType,
          ColumnType.tsvector,
        ]),
      );
    });

    test('extended variants exist', () {
      expect(
        ColumnType.values,
        containsAll(<ColumnType>[
          ColumnType.time,
          ColumnType.interval,
          ColumnType.inet,
          ColumnType.macaddr,
          ColumnType.point,
          ColumnType.line,
          ColumnType.box,
          ColumnType.money,
          ColumnType.bit,
          ColumnType.xml,
          ColumnType.array,
        ]),
      );
    });

    test('avoids Dart reserved keywords', () {
      // 'double' and 'enum' are reserved; we use
      // doublePrecision and enumType instead.
      final names = ColumnType.values.map((v) => v.name);
      expect(names, isNot(contains('double')));
      expect(names, isNot(contains('enum')));
    });
  });
}
