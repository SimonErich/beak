import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

PredicateTree _leaf({
  required String field,
  required Operator op,
  Object? value,
}) => LeafNode(Predicate(fieldName: field, operator: op, value: value));

void main() {
  const compiler = PostgresCompiler();

  group('PostgresCompiler — predicates', () {
    test('eq emits = with positional placeholder', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'age', op: Operator.eq, value: 18),
        ),
      );
      expect(result.sql, contains('"age" = \$1'));
      expect(result.parameters, <Object?>[18]);
    });

    test('neq emits != placeholder', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'age', op: Operator.neq, value: 18),
        ),
      );
      expect(result.sql, contains('"age" != \$1'));
    });

    test('gt/gte/lt/lte each emit the matching operator', () {
      final ops = <Operator, String>{
        Operator.gt: '>',
        Operator.gte: '>=',
        Operator.lt: '<',
        Operator.lte: '<=',
      };
      for (final entry in ops.entries) {
        final result = compiler.compileSelect(
          QueryDescriptor(
            table: 'users',
            where: _leaf(field: 'age', op: entry.key, value: 18),
          ),
        );
        expect(
          result.sql,
          contains('"age" ${entry.value} \$1'),
          reason: entry.key.name,
        );
      }
    });

    test('like emits LIKE placeholder', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'name', op: Operator.like, value: 'A%'),
        ),
      );
      expect(result.sql, contains('"name" LIKE \$1'));
      expect(result.parameters, <Object?>['A%']);
    });

    test('notLike emits NOT LIKE placeholder', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'name', op: Operator.notLike, value: 'A%'),
        ),
      );
      expect(result.sql, contains('"name" NOT LIKE \$1'));
    });

    test('ilike emits ILIKE placeholder', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'name', op: Operator.ilike, value: 'a%'),
        ),
      );
      expect(result.sql, contains('"name" ILIKE \$1'));
    });

    test('isNull emits IS NULL without consuming parameters', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'email', op: Operator.isNull),
        ),
      );
      expect(result.sql, contains('"email" IS NULL'));
      expect(result.parameters, isEmpty);
    });

    test('isNotNull emits IS NOT NULL without consuming parameters', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'email', op: Operator.isNotNull),
        ),
      );
      expect(result.sql, contains('"email" IS NOT NULL'));
      expect(result.parameters, isEmpty);
    });

    test('inList emits IN (...) with per-value placeholders', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(
            field: 'age',
            op: Operator.inList,
            value: const <Object?>[25, 30, 40],
          ),
        ),
      );
      expect(result.sql, contains('"age" IN (\$1, \$2, \$3)'));
      expect(result.parameters, <Object?>[25, 30, 40]);
    });

    test('notInList emits NOT IN (...)', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(
            field: 'age',
            op: Operator.notInList,
            value: const <Object?>[25, 30],
          ),
        ),
      );
      expect(result.sql, contains('"age" NOT IN (\$1, \$2)'));
    });

    test('between emits BETWEEN low AND high', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(
            field: 'age',
            op: Operator.between,
            value: const <Object?>[18, 65],
          ),
        ),
      );
      expect(result.sql, contains('"age" BETWEEN \$1 AND \$2'));
      expect(result.parameters, <Object?>[18, 65]);
    });

    test('notBetween emits NOT BETWEEN low AND high', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(
            field: 'age',
            op: Operator.notBetween,
            value: const <Object?>[18, 65],
          ),
        ),
      );
      expect(result.sql, contains('"age" NOT BETWEEN \$1 AND \$2'));
    });
  });

  group('PostgresCompiler — IN auto-chunking', () {
    test('999 values stay in a single IN clause', () {
      final values = List<Object?>.generate(999, (i) => i);
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'ids',
          where: LeafNode(
            Predicate(
              fieldName: 'id',
              operator: Operator.inList,
              value: values,
            ),
          ),
        ),
      );
      expect(' OR '.allMatches(result.sql).length, 0);
      expect('"id" IN'.allMatches(result.sql).length, 1);
      expect(result.parameters, hasLength(999));
    });

    test('1001 values split into two IN clauses joined by OR', () {
      final values = List<Object?>.generate(1001, (i) => i);
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'ids',
          where: LeafNode(
            Predicate(
              fieldName: 'id',
              operator: Operator.inList,
              value: values,
            ),
          ),
        ),
      );
      expect('"id" IN'.allMatches(result.sql).length, 2);
      expect(' OR '.allMatches(result.sql).length, 1);
      expect(result.parameters, hasLength(1001));
    });

    test('2500 values split into three IN clauses', () {
      final values = List<Object?>.generate(2500, (i) => i);
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'ids',
          where: LeafNode(
            Predicate(
              fieldName: 'id',
              operator: Operator.inList,
              value: values,
            ),
          ),
        ),
      );
      expect('"id" IN'.allMatches(result.sql).length, 3);
      expect(' OR '.allMatches(result.sql).length, 2);
    });
  });

  group('PostgresCompiler — compileToString', () {
    test('includes the SQL and a "-- Params:" line', () {
      final rendered = compiler.compileToString(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'id', op: Operator.eq, value: 1),
        ),
      );
      expect(rendered, contains('SELECT * FROM "users"'));
      expect(rendered, contains('"id" = \$1'));
      expect(rendered.split('\n'), contains('-- Params: [1]'));
    });
  });

  group('PostgresCompiler — DDL', () {
    test('create table with typed columns emits CREATE TABLE', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'users',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'id', type: ColumnType.uuid, isPrimaryKey: true),
            SchemaColumn(name: 'name', type: ColumnType.string),
            SchemaColumn(name: 'age', type: ColumnType.integer, nullable: true),
          ],
          ifNotExists: true,
        ),
      );
      expect(
        result.sql,
        'CREATE TABLE IF NOT EXISTS "users"'
        ' ("id" UUID NOT NULL PRIMARY KEY,'
        ' "name" VARCHAR NOT NULL,'
        ' "age" INTEGER)',
      );
      expect(result.parameters, isEmpty);
    });

    test('pgTypeOf produces a non-empty mapping for every ColumnType', () {
      for (final type in ColumnType.values) {
        expect(
          PostgresCompiler.pgTypeOf(type),
          isNotEmpty,
          reason: 'missing mapping for ColumnType.${type.name}',
        );
      }
    });

    test('dropTable honours IF EXISTS', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.dropTable(table: 'users', ifExists: true),
      );
      expect(result.sql, 'DROP TABLE IF EXISTS "users"');
    });

    test('truncateTable emits TRUNCATE TABLE', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.truncateTable(table: 'users'),
      );
      expect(result.sql, 'TRUNCATE TABLE "users"');
    });

    test('SchemaIndexDescriptor emits CREATE INDEX', () {
      final result = compiler.compileDdl(
        const SchemaIndexDescriptor(collection: 'users', field: 'email'),
      );
      expect(result.sql, 'CREATE INDEX ON "users" ("email")');
    });

    test('SchemaIndexDescriptor unique=true emits CREATE UNIQUE INDEX', () {
      final result = compiler.compileDdl(
        const SchemaIndexDescriptor(
          collection: 'users',
          field: 'email',
          unique: true,
        ),
      );
      expect(result.sql, 'CREATE UNIQUE INDEX ON "users" ("email")');
    });
  });

  group('PostgresCompiler — writes', () {
    test('compileInsertMany with empty rows throws QueryException', () {
      expect(
        () => compiler.compileInsertMany(
          const InsertManyDescriptor(
            table: 'users',
            rows: <Map<String, Object?>>[],
          ),
        ),
        throwsA(isA<QueryException>()),
      );
    });

    test('compileInsert emits parameterised INSERT ... RETURNING', () {
      final result = compiler.compileInsert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{'id': 1, 'name': 'Alice'},
          returning: <String>['id'],
        ),
      );
      expect(
        result.sql,
        'INSERT INTO "users" ("id", "name") VALUES (\$1, \$2) '
        'RETURNING "id"',
      );
      expect(result.parameters, <Object?>[1, 'Alice']);
    });

    test('compileInsertMany emits a multi-row VALUES list', () {
      final result = compiler.compileInsertMany(
        const InsertManyDescriptor(
          table: 'users',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'name': 'Alice'},
            <String, Object?>{'id': 2, 'name': 'Bob'},
          ],
        ),
      );
      expect(
        result.sql,
        'INSERT INTO "users" ("id", "name") VALUES '
        '(\$1, \$2), (\$3, \$4) RETURNING *',
      );
      expect(result.parameters, <Object?>[1, 'Alice', 2, 'Bob']);
    });

    test('compileUpdate emits SET assignments then WHERE', () {
      final result = compiler.compileUpdate(
        UpdateDescriptor(
          table: 'users',
          values: const <String, Object?>{'age': 30},
          where: _leaf(field: 'id', op: Operator.eq, value: 1),
        ),
      );
      expect(result.sql, 'UPDATE "users" SET "age" = \$1 WHERE "id" = \$2');
      expect(result.parameters, <Object?>[30, 1]);
    });

    test('compileDelete emits DELETE with WHERE clause', () {
      final result = compiler.compileDelete(
        DeleteDescriptor(
          table: 'users',
          where: _leaf(field: 'id', op: Operator.eq, value: 1),
        ),
      );
      expect(result.sql, 'DELETE FROM "users" WHERE "id" = \$1');
      expect(result.parameters, <Object?>[1]);
    });

    test('compileDelete without WHERE clause omits the clause', () {
      final result = compiler.compileDelete(
        const DeleteDescriptor(table: 'users'),
      );
      expect(result.sql, 'DELETE FROM "users"');
    });
  });

  group('PostgresCompiler — SELECT composition', () {
    test('AND predicate tree joins with AND', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: AndNode(
            _leaf(field: 'age', op: Operator.gte, value: 18),
            _leaf(field: 'email', op: Operator.isNotNull),
          ),
        ),
      );
      expect(
        result.sql,
        'SELECT * FROM "users" '
        'WHERE "age" >= \$1 AND "email" IS NOT NULL',
      );
    });

    test('OR predicate tree joins with OR', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: OrNode(
            _leaf(field: 'role', op: Operator.eq, value: 'admin'),
            _leaf(field: 'role', op: Operator.eq, value: 'owner'),
          ),
        ),
      );
      expect(result.sql, contains('"role" = \$1 OR "role" = \$2'));
    });

    test('NOT predicate wraps inner expression', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: NotNode(_leaf(field: 'banned', op: Operator.eq, value: true)),
        ),
      );
      expect(result.sql, contains('NOT ("banned" = \$1)'));
    });

    test('GROUP node wraps inner expression in parentheses', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: GroupNode(
            OrNode(
              _leaf(field: 'a', op: Operator.eq, value: 1),
              _leaf(field: 'b', op: Operator.eq, value: 2),
            ),
          ),
        ),
      );
      expect(result.sql, contains('("a" = \$1 OR "b" = \$2)'));
    });

    test('orderBy, limit and offset append in order', () {
      final result = compiler.compileSelect(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[
            SortClause('created_at', direction: SortDirection.desc),
          ],
          limit: 10,
          offset: 20,
        ),
      );
      expect(
        result.sql,
        'SELECT * FROM "users" ORDER BY "created_at" DESC '
        'LIMIT 10 OFFSET 20',
      );
    });

    test('distinct + column projection is honoured', () {
      final result = compiler.compileSelect(
        const QueryDescriptor(
          table: 'users',
          columns: <String>['role'],
          distinct: true,
        ),
      );
      expect(result.sql, 'SELECT DISTINCT "role" FROM "users"');
    });
  });

  group('PostgresCompiler — aggregates', () {
    test('count without a column uses COUNT(*)', () {
      final result = compiler.compileAggregate(
        const AggregateDescriptor.count(table: 'users'),
      );
      expect(result.sql, 'SELECT COUNT(*) AS "count" FROM "users"');
    });

    test('sum of a column emits SUM("col")', () {
      final result = compiler.compileAggregate(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.sum,
          column: 'score',
        ),
      );
      expect(result.sql, 'SELECT SUM("score") AS "sum" FROM "users"');
    });

    test('aggregate with WHERE applies predicate tree', () {
      final result = compiler.compileAggregate(
        AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.avg,
          column: 'score',
          where: _leaf(field: 'role', op: Operator.eq, value: 'admin'),
        ),
      );
      expect(
        result.sql,
        'SELECT AVG("score") AS "avg" FROM "users" WHERE "role" = \$1',
      );
      expect(result.parameters, <Object?>['admin']);
    });
  });

  group('PostgresCompiler — joins / groupBy / having', () {
    test('renders INNER/LEFT joins, GROUP BY, and parameterised HAVING', () {
      final result = compiler.compileSelect(
        const QueryDescriptor(
          table: 'users',
          joins: <JoinClause>[
            JoinClause(
              kind: JoinKind.inner,
              table: 'posts',
              leftColumn: 'posts.user_id',
              rightColumn: 'users.id',
            ),
            JoinClause(
              kind: JoinKind.left,
              table: 'profiles',
              leftColumn: 'profiles.user_id',
              rightColumn: 'users.id',
            ),
          ],
          groupBy: <String>['users.id'],
          having: <HavingClause>[
            HavingClause(
              expression: 'COUNT(*)',
              operator: Operator.gt,
              value: 5,
            ),
          ],
        ),
      );
      expect(
        result.sql,
        contains('INNER JOIN "posts" ON "posts"."user_id" = "users"."id"'),
      );
      expect(
        result.sql,
        contains('LEFT JOIN "profiles" ON "profiles"."user_id" = "users"."id"'),
      );
      expect(result.sql, contains('GROUP BY "users"."id"'));
      expect(result.sql, contains('HAVING COUNT(*) > \$1'));
      expect(result.parameters, <Object?>[5]);
    });
  });
}
