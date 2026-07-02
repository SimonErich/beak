import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

PredicateTree _leaf({
  required String field,
  required Operator op,
  Object? value,
}) => LeafNode(Predicate(fieldName: field, operator: op, value: value));

void main() {
  const compiler = SqliteCompiler();

  group('SqliteCompiler.compileSelect', () {
    test('binds values as ? positional placeholders', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'age', op: Operator.gte, value: 18),
        ),
      );
      expect(result.sql, 'SELECT * FROM "users" WHERE "age" >= ?');
      expect(result.parameters, <Object?>[18]);
    });

    test('renders joins, GROUP BY, and HAVING', () {
      const descriptor = QueryDescriptor(
        table: 'users',
        joins: <JoinClause>[
          JoinClause(
            kind: JoinKind.inner,
            table: 'posts',
            leftColumn: 'posts.user_id',
            rightColumn: 'users.id',
          ),
        ],
        groupBy: <String>['users.id'],
        having: <HavingClause>[
          HavingClause(expression: 'COUNT(*)', operator: Operator.gt, value: 5),
        ],
      );
      final result = compiler.compileSelect(descriptor);
      expect(
        result.sql,
        contains('INNER JOIN "posts" ON "posts"."user_id" = "users"."id"'),
      );
      expect(result.sql, contains('GROUP BY "users"."id"'));
      expect(result.sql, contains('HAVING COUNT(*) > ?'));
      expect(result.parameters, <Object?>[5]);
    });
  });

  group('SqliteCompiler.compileInsert', () {
    test('emits a parameterised INSERT', () {
      final result = compiler.compileInsert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{'id': 1, 'name': 'Alice'},
        ),
      );
      expect(result.sql, 'INSERT INTO "users" ("id", "name") VALUES (?, ?)');
      expect(result.parameters, <Object?>[1, 'Alice']);
    });
  });

  group('SqliteCompiler.compileGroupedAggregate', () {
    test('emits GROUP BY rollup with aliased value', () {
      final result = compiler.compileGroupedAggregate(
        const AggregateDescriptor.count(table: 'posts', groupBy: 'user_id'),
      );
      expect(
        result.sql,
        'SELECT "user_id" AS "group", COUNT(*) AS "value" FROM "posts" '
        'GROUP BY "user_id"',
      );
    });
  });

  group('SqliteCompiler.compileDdl', () {
    test('maps column types and primary key', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'users',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
            SchemaColumn(name: 'name', type: ColumnType.string),
            SchemaColumn(name: 'bio', type: ColumnType.text, nullable: true),
          ],
        ),
      );
      expect(
        result.sql,
        'CREATE TABLE "users" ("id" INTEGER PRIMARY KEY, "name" TEXT NOT NULL, '
        '"bio" TEXT)',
      );
    });
  });
}
