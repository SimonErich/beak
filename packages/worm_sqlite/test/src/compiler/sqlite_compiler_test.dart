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
    test('renders foreign keys as table constraints', () {
      // Previously dropped: the descriptor carried no foreign keys, so every
      // table.foreign(...) in every migration silently vanished.
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'products',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'id', type: ColumnType.uuid, isPrimaryKey: true),
            SchemaColumn(
              name: 'category_id',
              type: ColumnType.uuid,
              nullable: true,
            ),
          ],
          foreignKeys: <SchemaForeignKey>[
            SchemaForeignKey(
              columns: <String>['category_id'],
              referencedTable: 'categories',
              referencedColumns: <String>['id'],
              onDelete: OnDelete.setNull,
            ),
          ],
        ),
      );
      expect(
        result.sql,
        contains(
          'FOREIGN KEY ("category_id") REFERENCES "categories" ("id") '
          'ON DELETE SET NULL',
        ),
      );
    });

    test('renders a unique index as a constraint, plain indexes not', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'product_tag',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'product_id', type: ColumnType.uuid),
            SchemaColumn(name: 'tag_id', type: ColumnType.uuid),
          ],
          indexes: <SchemaIndex>[
            SchemaIndex(
              name: 'product_tag_pair_idx',
              columns: <String>['product_id', 'tag_id'],
              unique: true,
            ),
            SchemaIndex(
              name: 'product_tag_tag_idx',
              columns: <String>['tag_id'],
            ),
          ],
        ),
      );
      expect(
        result.sql,
        contains(
          'CONSTRAINT "product_tag_pair_idx" UNIQUE ("product_id", "tag_id")',
        ),
      );
      expect(result.sql, isNot(contains('product_tag_tag_idx')));
    });

    test('maps every ON DELETE action, ormCascade to NO ACTION', () {
      String sqlFor(OnDelete action) => compiler
          .compileDdl(
            SchemaDescriptor.createTable(
              table: 'children',
              columns: const <SchemaColumn>[
                SchemaColumn(name: 'parent_id', type: ColumnType.uuid),
              ],
              foreignKeys: <SchemaForeignKey>[
                SchemaForeignKey(
                  columns: const <String>['parent_id'],
                  referencedTable: 'parents',
                  referencedColumns: const <String>['id'],
                  onDelete: action,
                ),
              ],
            ),
          )
          .sql;

      expect(sqlFor(OnDelete.cascade), contains('ON DELETE CASCADE'));
      expect(sqlFor(OnDelete.restrict), contains('ON DELETE RESTRICT'));
      expect(sqlFor(OnDelete.setNull), contains('ON DELETE SET NULL'));
      expect(sqlFor(OnDelete.setDefault), contains('ON DELETE SET DEFAULT'));
      expect(sqlFor(OnDelete.noAction), contains('ON DELETE NO ACTION'));
      // The ORM walks the children itself so hooks and scopes run.
      expect(sqlFor(OnDelete.ormCascade), contains('ON DELETE NO ACTION'));
    });

    test('a named foreign key keeps its constraint name', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'orders',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'user_id', type: ColumnType.uuid),
          ],
          foreignKeys: <SchemaForeignKey>[
            SchemaForeignKey(
              columns: <String>['user_id'],
              referencedTable: 'users',
              referencedColumns: <String>['id'],
              name: 'orders_user_fk',
            ),
          ],
        ),
      );
      expect(result.sql, contains('CONSTRAINT "orders_user_fk" FOREIGN KEY'));
    });

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
