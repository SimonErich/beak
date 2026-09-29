import 'package:test/test.dart';
import 'package:worm/src/query/mongo_filter_compiler.dart';
import 'package:worm/worm.dart';

PredicateTree _like(Operator operator, {String? escape}) => LeafNode(
  Predicate(
    fieldName: 'name',
    operator: operator,
    value: r'50\%_x',
    escape: escape,
  ),
);

void main() {
  group('Predicate.escape', () {
    test('is null unless a pattern names one', () {
      expect(_like(Operator.like), isA<LeafNode>());
      expect((_like(Operator.like) as LeafNode).predicate.escape, isNull);
      expect(_like(Operator.like).toMap(), isNot(contains('escape')));
    });

    test('is part of the serialized predicate', () {
      expect(
        _like(Operator.like, escape: r'\').toMap(),
        containsPair('escape', r'\'),
      );
    });

    test('must be a single character', () {
      expect(
        () => Predicate(
          fieldName: 'name',
          operator: Operator.like,
          value: 'a',
          escape: 'ab',
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('SqlCompiler', () {
    const compiler = SqlCompiler();

    String sqlFor(Operator operator, {String? escape}) => compiler.compile(
      QueryDescriptor(
        table: 'users',
        where: _like(operator, escape: escape),
      ),
    );

    test('states the escape character after the pattern', () {
      expect(
        sqlFor(Operator.like, escape: r'\'),
        r"SELECT * FROM users WHERE name LIKE '50\%_x' ESCAPE '\'",
      );
      expect(
        sqlFor(Operator.notLike, escape: r'\'),
        r"SELECT * FROM users WHERE name NOT LIKE '50\%_x' ESCAPE '\'",
      );
      expect(
        sqlFor(Operator.ilike, escape: r'\'),
        r"SELECT * FROM users WHERE name ILIKE '50\%_x' ESCAPE '\'",
      );
    });

    test('adds nothing for a pattern without an escape character', () {
      expect(
        sqlFor(Operator.like),
        r"SELECT * FROM users WHERE name LIKE '50\%_x'",
      );
    });
  });

  group('MongoFilterCompiler', () {
    const compiler = MongoFilterCompiler();

    String regexFor(String pattern, {String? escape}) {
      final filter = compiler.renderTree(
        LeafNode(
          Predicate(
            fieldName: 'name',
            operator: Operator.like,
            value: pattern,
            escape: escape,
          ),
        ),
      );
      return switch (filter['name']) {
        {r'$regex': final String source} => source,
        final Object? other => fail('Expected a regex filter, got $other.'),
      };
    }

    test('turns wildcards into a regex and an escaped one into itself', () {
      expect(regexFor('a%b_c'), r'^a.*b.c$');
      expect(regexFor(r'a\%b\_c\\', escape: r'\'), r'^a%b_c\\$');
      expect(regexFor(r'a%\%_', escape: r'\'), r'^a.*%.$');
      expect(regexFor(r'a\', escape: r'\'), r'^a\\$');
    });

    test('reads a backslash as ordinary without an escape character', () {
      expect(regexFor(r'a\%'), r'^a\\.*$');
    });
  });
}
