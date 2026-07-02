import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mongodb/worm_mongodb.dart';

PredicateTree _leaf({
  required String field,
  required Operator op,
  Object? value,
}) => LeafNode(Predicate(fieldName: field, operator: op, value: value));

void main() {
  const compiler = MongoFilterCompiler();

  group('MongoFilterCompiler.compileFilter — operators', () {
    test('gt produces {"age": {"\$gt": 18}}', () {
      final filter = compiler.compileFilter(
        _leaf(field: 'age', op: Operator.gt, value: 18),
      );
      expect(filter, <String, Object?>{
        'age': <String, Object?>{r'$gt': 18},
      });
    });

    test('eq emits the field/value pair directly', () {
      final filter = compiler.compileFilter(
        _leaf(field: 'name', op: Operator.eq, value: 'Alice'),
      );
      expect(filter, const <String, Object?>{'name': 'Alice'});
    });

    test('neq produces {field: {\$ne: value}}', () {
      final filter = compiler.compileFilter(
        _leaf(field: 'age', op: Operator.neq, value: 18),
      );
      expect(filter, <String, Object?>{
        'age': <String, Object?>{r'$ne': 18},
      });
    });

    test('gte, lt, lte all use their Mongo operators', () {
      expect(
        compiler.compileFilter(_leaf(field: 'a', op: Operator.gte, value: 1)),
        <String, Object?>{
          'a': <String, Object?>{r'$gte': 1},
        },
      );
      expect(
        compiler.compileFilter(_leaf(field: 'a', op: Operator.lt, value: 1)),
        <String, Object?>{
          'a': <String, Object?>{r'$lt': 1},
        },
      );
      expect(
        compiler.compileFilter(_leaf(field: 'a', op: Operator.lte, value: 1)),
        <String, Object?>{
          'a': <String, Object?>{r'$lte': 1},
        },
      );
    });

    test('isNull / isNotNull use \$eq null / \$ne null', () {
      expect(
        compiler.compileFilter(_leaf(field: 'email', op: Operator.isNull)),
        <String, Object?>{
          'email': <String, Object?>{r'$eq': null},
        },
      );
      expect(
        compiler.compileFilter(_leaf(field: 'email', op: Operator.isNotNull)),
        <String, Object?>{
          'email': <String, Object?>{r'$ne': null},
        },
      );
    });

    test('inList / notInList use \$in / \$nin', () {
      expect(
        compiler.compileFilter(
          _leaf(
            field: 'age',
            op: Operator.inList,
            value: const <Object?>[25, 30, 40],
          ),
        ),
        <String, Object?>{
          'age': <String, Object?>{
            r'$in': <Object?>[25, 30, 40],
          },
        },
      );
      expect(
        compiler.compileFilter(
          _leaf(
            field: 'age',
            op: Operator.notInList,
            value: const <Object?>[25, 30],
          ),
        ),
        <String, Object?>{
          'age': <String, Object?>{
            r'$nin': <Object?>[25, 30],
          },
        },
      );
    });

    test('between uses combined \$gte/\$lte on the same field', () {
      final filter = compiler.compileFilter(
        _leaf(
          field: 'age',
          op: Operator.between,
          value: const <Object?>[18, 65],
        ),
      );
      expect(filter, <String, Object?>{
        'age': <String, Object?>{r'$gte': 18, r'$lte': 65},
      });
    });

    test('notBetween uses \$or with \$lt / \$gt', () {
      final filter = compiler.compileFilter(
        _leaf(
          field: 'age',
          op: Operator.notBetween,
          value: const <Object?>[18, 65],
        ),
      );
      expect(filter, <String, Object?>{
        r'$or': <Map<String, Object?>>[
          <String, Object?>{
            'age': <String, Object?>{r'$lt': 18},
          },
          <String, Object?>{
            'age': <String, Object?>{r'$gt': 65},
          },
        ],
      });
    });
  });

  group('MongoFilterCompiler.compileFilter — tree composition', () {
    test('AND tree produces {"\$and": [filterA, filterB]}', () {
      final filter = compiler.compileFilter(
        AndNode(
          _leaf(field: 'a', op: Operator.eq, value: 1),
          _leaf(field: 'b', op: Operator.eq, value: 2),
        ),
      );
      expect(filter, <String, Object?>{
        r'$and': <Map<String, Object?>>[
          <String, Object?>{'a': 1},
          <String, Object?>{'b': 2},
        ],
      });
    });

    test('OR tree produces {"\$or": [...]}', () {
      final filter = compiler.compileFilter(
        OrNode(
          _leaf(field: 'a', op: Operator.eq, value: 1),
          _leaf(field: 'b', op: Operator.eq, value: 2),
        ),
      );
      expect(filter, <String, Object?>{
        r'$or': <Map<String, Object?>>[
          <String, Object?>{'a': 1},
          <String, Object?>{'b': 2},
        ],
      });
    });

    test('NOT tree wraps in \$nor', () {
      final filter = compiler.compileFilter(
        NotNode(_leaf(field: 'a', op: Operator.eq, value: 1)),
      );
      expect(filter, <String, Object?>{
        r'$nor': <Map<String, Object?>>[
          <String, Object?>{'a': 1},
        ],
      });
    });

    test('null tree produces the match-all document', () {
      expect(compiler.compileFilter(null), const <String, Object?>{});
    });
  });

  group('MongoFilterCompiler.compileFilter — LIKE / ILIKE', () {
    test("LIKE '%alice%' → {\$regex: '.*alice.*'}", () {
      final filter = compiler.compileFilter(
        _leaf(field: 'name', op: Operator.like, value: '%alice%'),
      );
      expect(filter, <String, Object?>{
        'name': <String, Object?>{r'$regex': '.*alice.*'},
      });
    });

    test("ILIKE '%alice%' → \$regex with \$options: 'i'", () {
      final filter = compiler.compileFilter(
        _leaf(field: 'name', op: Operator.ilike, value: '%alice%'),
      );
      expect(filter, <String, Object?>{
        'name': <String, Object?>{r'$regex': '.*alice.*', r'$options': 'i'},
      });
    });

    test('LIKE underscore wildcard maps to regex dot', () {
      final filter = compiler.compileFilter(
        _leaf(field: 'name', op: Operator.like, value: 'a_b'),
      );
      expect(filter, <String, Object?>{
        'name': <String, Object?>{r'$regex': 'a.b'},
      });
    });

    test('NOT LIKE wraps the regex in \$not', () {
      final filter = compiler.compileFilter(
        _leaf(field: 'name', op: Operator.notLike, value: '%alice%'),
      );
      expect(filter, <String, Object?>{
        'name': <String, Object?>{
          r'$not': <String, Object?>{r'$regex': '.*alice.*'},
        },
      });
    });
  });

  group('MongoFilterCompiler — field name mapping', () {
    test("field named 'id' maps to '_id' in filter", () {
      final filter = compiler.compileFilter(
        _leaf(field: 'id', op: Operator.eq, value: 42),
      );
      expect(filter, const <String, Object?>{'_id': 42});
    });

    test("field named 'id' also maps in comparison operators", () {
      final filter = compiler.compileFilter(
        _leaf(field: 'id', op: Operator.gt, value: 1),
      );
      expect(filter, <String, Object?>{
        '_id': <String, Object?>{r'$gt': 1},
      });
    });
  });

  group('MongoFilterCompiler.compileQuery', () {
    test("columns ['name', 'email'] produce projection "
        '{name: 1, email: 1, _id: 0}', () {
      final result = compiler.compileQuery(
        const QueryDescriptor(
          table: 'users',
          columns: <String>['name', 'email'],
        ),
      );
      expect(result.projection, const <String, int>{
        'name': 1,
        'email': 1,
        '_id': 0,
      });
    });

    test("projection keeps _id when 'id' is included in columns", () {
      final result = compiler.compileQuery(
        const QueryDescriptor(table: 'users', columns: <String>['id', 'name']),
      );
      expect(result.projection, const <String, int>{'_id': 1, 'name': 1});
    });

    test('empty columns → null projection (select all fields)', () {
      final result = compiler.compileQuery(
        const QueryDescriptor(table: 'users'),
      );
      expect(result.projection, isNull);
    });

    test('orderBy compiles to field→±1 sort map with id→_id mapping', () {
      final result = compiler.compileQuery(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[
            SortClause('name'),
            SortClause('id', direction: SortDirection.desc),
          ],
        ),
      );
      expect(result.sort, const <String, int>{'name': 1, '_id': -1});
    });

    test('limit and offset pass through unchanged', () {
      final result = compiler.compileQuery(
        const QueryDescriptor(table: 'users', limit: 10, offset: 20),
      );
      expect(result.limit, 10);
      expect(result.skip, 20);
    });

    test('collection mirrors the descriptor table', () {
      final result = compiler.compileQuery(
        const QueryDescriptor(table: 'users'),
      );
      expect(result.collection, 'users');
    });
  });

  group('MongoFilterCompiler.compileToString', () {
    test('returns a non-empty db.<coll>.find(...) string', () {
      final rendered = compiler.compileToString(
        const QueryDescriptor(table: 'users'),
      );
      expect(rendered, isNotEmpty);
      expect(rendered, contains('db.users.find'));
    });

    test('includes filter + projection + sort + skip + limit', () {
      final rendered = compiler.compileToString(
        QueryDescriptor(
          table: 'users',
          columns: const <String>['name'],
          where: _leaf(field: 'age', op: Operator.gt, value: 18),
          orderBy: const <SortClause>[SortClause('name')],
          limit: 5,
          offset: 2,
        ),
      );
      expect(rendered, contains('db.users.find'));
      expect(rendered, contains(r'$gt'));
      expect(rendered, contains('.sort('));
      expect(rendered, contains('.skip(2)'));
      expect(rendered, contains('.limit(5)'));
    });

    test('returns a non-empty string for non-query descriptors too', () {
      final rendered = compiler.compileToString(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'name': 'A'},
        ),
      );
      expect(rendered, isNotEmpty);
    });
  });

  group('NoSQL operator-injection guard', () {
    test('rejects an operator map in a scalar eq predicate', () {
      expect(
        () => compiler.compileFilter(
          _leaf(
            field: 'role',
            op: Operator.eq,
            value: <String, Object?>{r'$ne': null},
          ),
        ),
        throwsA(isA<QueryException>()),
      );
    });

    test('rejects an operator map inside an in-list', () {
      expect(
        () => compiler.compileFilter(
          _leaf(
            field: 'role',
            op: Operator.inList,
            value: <Object?>[
              'admin',
              <String, Object?>{r'$gt': ''},
            ],
          ),
        ),
        throwsA(isA<QueryException>()),
      );
    });

    test('allows a plain map value with no operator keys', () {
      final filter = compiler.compileFilter(
        _leaf(
          field: 'meta',
          op: Operator.eq,
          value: <String, Object?>{'nested': 1},
        ),
      );
      expect(filter['meta'], <String, Object?>{'nested': 1});
    });
  });
}
