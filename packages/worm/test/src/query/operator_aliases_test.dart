/// `Operator` long-form spec aliases.
library;

import 'package:test/test.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/operator.dart';
import 'package:worm/src/query/predicate_tree.dart';

void main() {
  group('Operator long-form aliases', () {
    test('equals is the identical instance as eq', () {
      expect(identical(Operator.equals, Operator.eq), isTrue);
    });

    test('notEquals === neq, comparison aliases === short forms', () {
      expect(identical(Operator.notEquals, Operator.neq), isTrue);
      expect(identical(Operator.greaterThan, Operator.gt), isTrue);
      expect(identical(Operator.greaterThanOrEqualTo, Operator.gte), isTrue);
      expect(identical(Operator.lessThan, Operator.lt), isTrue);
      expect(identical(Operator.lessThanOrEqualTo, Operator.lte), isTrue);
    });

    test('alias is usable in switch as the canonical value', () {
      const op = Operator.equals;
      final matched = switch (op) {
        Operator.eq => 'equals',
        _ => 'other',
      };
      expect(matched, 'equals');
    });
  });

  group('FieldOperators.whereIn / whereNotIn aliases', () {
    test('whereIn produces the same predicate map as inList', () {
      const field = Field<int>('id');
      final a = field.whereIn(<int>[1, 2, 3]);
      final b = field.inList(<int>[1, 2, 3]);
      expect(a.toMap(), b.toMap());
      expect(a, isA<LeafNode>());
    });

    test('whereNotIn matches notInList', () {
      const field = Field<int>('id');
      final a = field.whereNotIn(<int>[7, 8]);
      final b = field.notInList(<int>[7, 8]);
      expect(a.toMap(), b.toMap());
    });
  });
}
