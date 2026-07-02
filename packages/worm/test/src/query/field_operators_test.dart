import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('FieldOperators (universal)', () {
    const age = ComparableField<int>('age');
    const active = Field<bool>('is_active');

    test('eq produces leaf with Operator.eq', () {
      final tree = active.eq(true);
      final leaf = tree as LeafNode;
      expect(leaf.predicate.operator, Operator.eq);
      expect(leaf.predicate.value, true);
      expect(leaf.predicate.fieldName, 'is_active');
    });

    test('neq produces Operator.neq', () {
      final leaf = age.neq(0) as LeafNode;
      expect(leaf.predicate.operator, Operator.neq);
      expect(leaf.predicate.value, 0);
    });

    test('isNull produces Operator.isNull', () {
      final leaf = age.isNull() as LeafNode;
      expect(leaf.predicate.operator, Operator.isNull);
      expect(leaf.predicate.value, isNull);
    });

    test('isNotNull produces Operator.isNotNull', () {
      final leaf = age.isNotNull() as LeafNode;
      expect(leaf.predicate.operator, Operator.isNotNull);
    });

    test('inList produces Operator.inList', () {
      final leaf = age.inList([1, 2, 3]) as LeafNode;
      expect(leaf.predicate.operator, Operator.inList);
      expect(leaf.predicate.value, [1, 2, 3]);
    });

    test('notInList produces Operator.notInList', () {
      final leaf = age.notInList([4, 5]) as LeafNode;
      expect(leaf.predicate.operator, Operator.notInList);
    });
  });

  group('ComparableFieldOperators', () {
    const age = ComparableField<int>('age');

    test('gt produces Operator.gt', () {
      final leaf = age.gt(18) as LeafNode;
      expect(leaf.predicate.operator, Operator.gt);
      expect(leaf.predicate.value, 18);
    });

    test('gte produces Operator.gte', () {
      final leaf = age.gte(21) as LeafNode;
      expect(leaf.predicate.operator, Operator.gte);
      expect(leaf.predicate.value, 21);
    });

    test('lt produces Operator.lt', () {
      final leaf = age.lt(65) as LeafNode;
      expect(leaf.predicate.operator, Operator.lt);
    });

    test('lte produces Operator.lte', () {
      final leaf = age.lte(100) as LeafNode;
      expect(leaf.predicate.operator, Operator.lte);
    });

    test('between produces Operator.between', () {
      final leaf = age.between(18, 65) as LeafNode;
      expect(leaf.predicate.operator, Operator.between);
      expect(leaf.predicate.value, (18, 65));
    });

    test('notBetween produces Operator.notBetween', () {
      final leaf = age.notBetween(0, 17) as LeafNode;
      expect(leaf.predicate.operator, Operator.notBetween);
    });
  });

  group('StringFieldOperators', () {
    const name = StringField('name');

    test('like produces Operator.like', () {
      final leaf = name.like('%john%') as LeafNode;
      expect(leaf.predicate.operator, Operator.like);
      expect(leaf.predicate.value, '%john%');
    });

    test('notLike produces Operator.notLike', () {
      final leaf = name.notLike('%test%') as LeafNode;
      expect(leaf.predicate.operator, Operator.notLike);
    });

    test('ilike produces Operator.ilike', () {
      final leaf = name.ilike('%JOHN%') as LeafNode;
      expect(leaf.predicate.operator, Operator.ilike);
    });

    test('contains wraps value with %', () {
      final leaf = name.contains('john') as LeafNode;
      expect(leaf.predicate.operator, Operator.like);
      expect(leaf.predicate.value, '%john%');
    });

    test('startsWith appends %', () {
      final leaf = name.startsWith('Dr.') as LeafNode;
      expect(leaf.predicate.operator, Operator.like);
      expect(leaf.predicate.value, 'Dr.%');
    });

    test('endsWith prepends %', () {
      final leaf = name.endsWith('Jr.') as LeafNode;
      expect(leaf.predicate.operator, Operator.like);
      expect(leaf.predicate.value, '%Jr.');
    });
  });

  group('Type constraint enforcement', () {
    test('StringField has string operators', () {
      const n = StringField('name');
      expect(n.like('%a%'), isA<PredicateTree>());
      expect(n.contains('a'), isA<PredicateTree>());
      expect(n.startsWith('a'), isA<PredicateTree>());
      expect(n.endsWith('a'), isA<PredicateTree>());
    });

    test('ComparableField has comparison ops', () {
      const a = ComparableField<int>('age');
      expect(a.gt(1), isA<PredicateTree>());
      expect(a.gte(1), isA<PredicateTree>());
      expect(a.lt(1), isA<PredicateTree>());
      expect(a.lte(1), isA<PredicateTree>());
      expect(a.between(1, 10), isA<PredicateTree>());
    });

    test('universal operators on all fields', () {
      const f = Field<bool>('flag');
      expect(f.eq(true), isA<PredicateTree>());
      expect(f.neq(false), isA<PredicateTree>());
      expect(f.isNull(), isA<PredicateTree>());
      expect(f.isNotNull(), isA<PredicateTree>());
      expect(f.inList([true, false]), isA<PredicateTree>());
    });
  });
}
