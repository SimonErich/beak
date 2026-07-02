import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// Mirrors the worm translation table documented on [BeakOperator].
///
/// The switch expression is exhaustive over the enum, so adding an operator
/// without extending this mapping (and the doc table it mirrors) is a
/// compile-time error that breaks the build, as the phase contract requires.
String wormTranslationOf(BeakOperator operator) => switch (operator) {
  BeakOperator.eq => 'Operator.eq',
  BeakOperator.neq => 'Operator.neq',
  BeakOperator.gt => 'Operator.gt',
  BeakOperator.gte => 'Operator.gte',
  BeakOperator.lt => 'Operator.lt',
  BeakOperator.lte => 'Operator.lte',
  BeakOperator.like => 'Operator.like',
  BeakOperator.ilike => 'Operator.ilike',
  BeakOperator.contains => 'Operator.ilike with pattern %value%',
  BeakOperator.startsWith => 'Operator.ilike with pattern value%',
  BeakOperator.endsWith => 'Operator.ilike with pattern %value',
  BeakOperator.isNull => 'Operator.isNull',
  BeakOperator.isNotNull => 'Operator.isNotNull',
  BeakOperator.inList => 'Operator.inList',
  BeakOperator.notInList => 'Operator.notInList',
  BeakOperator.between => 'Operator.between',
  BeakOperator.notBetween => 'Operator.notBetween',
};

void main() {
  test('exposes exactly the documented operators, in stable order', () {
    expect(BeakOperator.values.map((operator) => operator.name), const [
      'eq',
      'neq',
      'gt',
      'gte',
      'lt',
      'lte',
      'like',
      'ilike',
      'contains',
      'startsWith',
      'endsWith',
      'isNull',
      'isNotNull',
      'inList',
      'notInList',
      'between',
      'notBetween',
    ]);
  });

  test('every operator resolves to a worm translation', () {
    for (final operator in BeakOperator.values) {
      expect(wormTranslationOf(operator), isNotEmpty, reason: operator.name);
    }
  });

  test('plain comparison operators map onto same-named worm operators', () {
    const sameNamed = [
      BeakOperator.eq,
      BeakOperator.neq,
      BeakOperator.gt,
      BeakOperator.gte,
      BeakOperator.lt,
      BeakOperator.lte,
      BeakOperator.like,
      BeakOperator.ilike,
      BeakOperator.isNull,
      BeakOperator.isNotNull,
      BeakOperator.inList,
      BeakOperator.notInList,
      BeakOperator.between,
      BeakOperator.notBetween,
    ];
    for (final operator in sameNamed) {
      expect(wormTranslationOf(operator), 'Operator.${operator.name}');
    }
  });

  test('substring operators translate to ilike with a wildcard pattern', () {
    expect(
      wormTranslationOf(BeakOperator.contains),
      'Operator.ilike with pattern %value%',
    );
    expect(
      wormTranslationOf(BeakOperator.startsWith),
      'Operator.ilike with pattern value%',
    );
    expect(
      wormTranslationOf(BeakOperator.endsWith),
      'Operator.ilike with pattern %value',
    );
  });
}
