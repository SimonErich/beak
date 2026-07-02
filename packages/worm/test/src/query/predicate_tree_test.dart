import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  const name = StringField('name');
  const age = ComparableField<int>('age');
  const active = Field<bool>('is_active');

  group('LeafNode', () {
    test('toMap includes predicate data', () {
      final leaf = name.eq('Alice');
      expect(leaf.toMap(), {
        'type': 'leaf',
        'field': 'name',
        'operator': 'eq',
        'value': 'Alice',
      });
    });

    test('toMap with table-qualified field', () {
      const field = ComparableField<int>('age', tableName: 'users');
      final leaf = field.gte(18);
      expect(leaf.toMap(), {
        'type': 'leaf',
        'field': 'users.age',
        'operator': 'gte',
        'value': 18,
      });
    });
  });

  group('AndNode', () {
    test('composes two predicates', () {
      final tree = name.eq('Alice').and(age.gte(18));
      expect(tree, isA<AndNode>());
      expect(tree.toMap(), {
        'type': 'and',
        'left': {
          'type': 'leaf',
          'field': 'name',
          'operator': 'eq',
          'value': 'Alice',
        },
        'right': {
          'type': 'leaf',
          'field': 'age',
          'operator': 'gte',
          'value': 18,
        },
      });
    });
  });

  group('OrNode', () {
    test('composes two predicates', () {
      final tree = name.eq('Alice').or(name.eq('Bob'));
      expect(tree, isA<OrNode>());
      expect(tree.toMap()['type'], 'or');
    });
  });

  group('NotNode', () {
    test('negates a predicate', () {
      final tree = active.eq(false).not();
      expect(tree, isA<NotNode>());
      expect(tree.toMap(), {
        'type': 'not',
        'child': {
          'type': 'leaf',
          'field': 'is_active',
          'operator': 'eq',
          'value': false,
        },
      });
    });
  });

  group('GroupNode', () {
    test('wraps a sub-tree in a group', () {
      final inner = name.eq('Alice').or(name.eq('Bob'));
      final grouped = inner.group();
      expect(grouped, isA<GroupNode>());
      expect(grouped.toMap()['type'], 'group');
    });
  });

  group('Complex composition', () {
    test('AND + OR + NOT', () {
      final tree = name.eq('Alice').and(age.gte(18)).or(active.eq(true).not());
      expect(tree, isA<OrNode>());
      final map = tree.toMap();
      expect(map['type'], 'or');
    });

    test('grouped OR inside AND', () {
      final orClause = name.eq('Alice').or(name.eq('Bob')).group();
      final tree = orClause.and(age.gte(18));
      expect(tree, isA<AndNode>());
      final map = tree.toMap();
      final left = map['left']! as Map<String, Object?>;
      expect(left['type'], 'group');
    });

    test('deeply nested composition', () {
      // (name = 'Alice' AND age >= 18)
      //   OR (name = 'Bob' AND active = true)
      final branch1 = name.eq('Alice').and(age.gte(18)).group();
      final branch2 = name.eq('Bob').and(active.eq(true)).group();
      final tree = branch1.or(branch2);
      expect(tree, isA<OrNode>());
    });

    test('chained AND operations', () {
      final tree = name.eq('Alice').and(age.gte(18)).and(active.eq(true));
      // Right-associative: (eq AND gte) AND eq
      expect(tree, isA<AndNode>());
    });

    test('NOT of grouped OR', () {
      final tree = name.eq('Alice').or(name.eq('Bob'));
      final negated = tree.group().not();
      expect(negated, isA<NotNode>());
      final map = negated.toMap();
      final child = map['child']! as Map<String, Object?>;
      expect(child['type'], 'group');
    });
  });
}
