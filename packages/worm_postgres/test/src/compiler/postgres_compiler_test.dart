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
    test('create table renders foreign keys as table constraints', () {
      // Previously dropped: the descriptor carried no foreign keys and the
      // builder rendered columns only, so every table.foreign(...) in every
      // migration silently vanished against a real database.
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
        result.single.sql,
        'CREATE TABLE "products"'
        ' ("id" UUID NOT NULL PRIMARY KEY,'
        ' "category_id" UUID,'
        ' FOREIGN KEY ("category_id") REFERENCES "categories" ("id")'
        ' ON DELETE SET NULL)',
      );
    });

    test('create table renders a unique index as a constraint', () {
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
          ],
        ),
      );
      expect(
        result.single.sql,
        contains(
          'CONSTRAINT "product_tag_pair_idx" UNIQUE ("product_id", "tag_id")',
        ),
      );
    });

    test('a non-unique index is not inlined as a constraint', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'products',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'status', type: ColumnType.string),
          ],
          indexes: <SchemaIndex>[
            SchemaIndex(
              name: 'products_status_idx',
              columns: <String>['status'],
            ),
          ],
        ),
      );
      // Not inlined as a constraint — it is its own statement instead. It
      // used to be neither, and no error said so.
      expect(result.first.sql, isNot(contains('products_status_idx')));
      expect(result.last.sql, startsWith('CREATE INDEX'));
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
      expect(
        result.single.sql,
        contains('CONSTRAINT "orders_user_fk" FOREIGN KEY'),
      );
    });

    test('composite foreign keys align both column lists', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'lines',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'order_id', type: ColumnType.uuid),
            SchemaColumn(name: 'tenant_id', type: ColumnType.uuid),
          ],
          foreignKeys: <SchemaForeignKey>[
            SchemaForeignKey(
              columns: <String>['order_id', 'tenant_id'],
              referencedTable: 'orders',
              referencedColumns: <String>['id', 'tenant_id'],
            ),
          ],
        ),
      );
      expect(
        result.single.sql,
        contains(
          'FOREIGN KEY ("order_id", "tenant_id") REFERENCES '
          '"orders" ("id", "tenant_id")',
        ),
      );
    });

    test('every OnDelete action renders, ormCascade as NO ACTION', () {
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
          .single
          .sql;

      expect(sqlFor(OnDelete.cascade), contains('ON DELETE CASCADE'));
      expect(sqlFor(OnDelete.restrict), contains('ON DELETE RESTRICT'));
      expect(sqlFor(OnDelete.setNull), contains('ON DELETE SET NULL'));
      expect(sqlFor(OnDelete.setDefault), contains('ON DELETE SET DEFAULT'));
      expect(sqlFor(OnDelete.noAction), contains('ON DELETE NO ACTION'));
      // The ORM walks the children itself so hooks and scopes run; a
      // database cascade would delete them behind its back.
      expect(sqlFor(OnDelete.ormCascade), contains('ON DELETE NO ACTION'));
    });

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
        result.single.sql,
        'CREATE TABLE IF NOT EXISTS "users"'
        ' ("id" UUID NOT NULL PRIMARY KEY,'
        ' "name" VARCHAR NOT NULL,'
        ' "age" INTEGER)',
      );
      expect(result.single.parameters, isEmpty);
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
      expect(result.single.sql, 'DROP TABLE IF EXISTS "users"');
    });

    test('truncateTable emits TRUNCATE TABLE', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.truncateTable(table: 'users'),
      );
      expect(result.single.sql, 'TRUNCATE TABLE "users"');
    });

    test('a non-unique index becomes its own CREATE INDEX statement', () {
      // It used to become nothing at all: the builder emitted only the unique
      // ones, so every foreign key and every sortable column in every schema
      // was unindexed and nothing said so.
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'users',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'email', type: ColumnType.string),
          ],
          indexes: <SchemaIndex>[
            SchemaIndex(name: 'users_email_idx', columns: <String>['email']),
          ],
        ),
      );

      expect(result, hasLength(2));
      expect(result.first.sql, startsWith('CREATE TABLE "users"'));
      expect(
        result.last.sql,
        'CREATE INDEX "users_email_idx" ON "users" ("email")',
      );
    });

    test('a unique index stays an inline constraint, not a statement', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'users',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'email', type: ColumnType.string),
          ],
          indexes: <SchemaIndex>[
            SchemaIndex(
              name: 'users_email_key',
              columns: <String>['email'],
              unique: true,
            ),
          ],
        ),
      );

      expect(result, hasLength(1));
      expect(
        result.single.sql,
        contains('CONSTRAINT "users_email_key" UNIQUE'),
      );
    });

    test('a declared length and precision reach the SQL', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'products',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'sku', type: ColumnType.string, length: 40),
            SchemaColumn(
              name: 'price',
              type: ColumnType.decimal,
              precision: 10,
              scale: 2,
            ),
          ],
        ),
      );

      expect(result.single.sql, contains('"sku" VARCHAR(40)'));
      expect(result.single.sql, contains('"price" NUMERIC(10, 2)'));
    });

    test('an auto-increment column becomes a serial', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'events',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.bigInteger,
              autoIncrement: true,
              isPrimaryKey: true,
            ),
          ],
        ),
      );

      expect(result.single.sql, contains('"id" BIGSERIAL'));
    });
  });

  group('PostgresCompiler — ALTER TABLE', () {
    List<String> sqlFor(List<SchemaAlteration> alterations) => <String>[
      for (final compiled in compiler.compileDdl(
        SchemaDescriptor.alterTable(
          table: 'products',
          alterations: alterations,
        ),
      ))
        compiled.sql,
    ];

    test('one statement per step, in the order given', () {
      // Order is semantic: the index must be dropped before the column it
      // covers, and the column added before the index that covers it.
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaDropIndex('products_legacy_idx'),
          SchemaDropColumn('legacy'),
          SchemaAddColumn(
            SchemaColumn(name: 'status', type: ColumnType.string, length: 20),
          ),
          SchemaAddIndex(
            SchemaIndex(
              name: 'products_status_idx',
              columns: <String>['status'],
            ),
          ),
        ]),
        <String>[
          'DROP INDEX "products_legacy_idx"',
          'ALTER TABLE "products" DROP COLUMN "legacy"',
          'ALTER TABLE "products" ADD COLUMN "status" VARCHAR(20) NOT NULL',
          'CREATE INDEX "products_status_idx" ON "products" ("status")',
        ],
      );
    });

    test('a change alters only the facets it names', () {
      // Relaxing NOT NULL must not restate — and so must not silently
      // rewrite — the column's type or default.
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaChangeColumn(
            SchemaColumn(name: 'bio', type: ColumnType.text, nullable: true),
            facets: <SchemaColumnFacet>{SchemaColumnFacet.nullability},
          ),
        ]),
        <String>['ALTER TABLE "products" ALTER COLUMN "bio" DROP NOT NULL'],
      );
    });

    test('a full change restates type, nullability and default', () {
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaChangeColumn(
            SchemaColumn(
              name: 'sku',
              type: ColumnType.string,
              length: 64,
              defaultValue: 'n/a',
            ),
          ),
        ]).single,
        'ALTER TABLE "products" ALTER COLUMN "sku" TYPE VARCHAR(64), '
        'ALTER COLUMN "sku" SET NOT NULL, '
        'ALTER COLUMN "sku" SET DEFAULT \'n/a\'',
      );
    });

    test('a USING clause is carried into the type change', () {
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaChangeColumn(
            SchemaColumn(name: 'qty', type: ColumnType.integer),
            facets: <SchemaColumnFacet>{SchemaColumnFacet.type},
            using: 'qty::integer',
          ),
        ]).single,
        'ALTER TABLE "products" ALTER COLUMN "qty" TYPE INTEGER '
        'USING qty::integer',
      );
    });

    test('foreign keys are added and dropped by name', () {
      const addForeignKey =
          'ALTER TABLE "products" ADD CONSTRAINT "products_brand_fk" '
          'FOREIGN KEY ("brand_id") REFERENCES "brands" ("id") '
          'ON DELETE SET NULL';
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaDropForeignKey('products_brand_fk'),
          SchemaAddForeignKey(
            SchemaForeignKey(
              columns: <String>['brand_id'],
              referencedTable: 'brands',
              referencedColumns: <String>['id'],
              onDelete: OnDelete.setNull,
              name: 'products_brand_fk',
            ),
          ),
        ]),
        <String>[
          'ALTER TABLE "products" DROP CONSTRAINT "products_brand_fk"',
          addForeignKey,
        ],
      );
    });

    test('a partial index carries its predicate', () {
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaAddIndex(
            SchemaIndex(
              name: 'products_live_idx',
              columns: <String>['status'],
              where: 'status = \'published\'',
            ),
            ifNotExists: true,
          ),
        ]).single,
        'CREATE INDEX IF NOT EXISTS "products_live_idx" ON "products" '
        '("status") WHERE status = \'published\'',
      );
    });

    test('a gin index renders its access method', () {
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaAddIndex(
            SchemaIndex(
              name: 'products_search_idx',
              columns: <String>['search'],
              kind: IndexKind.gin,
            ),
          ),
        ]).single,
        'CREATE INDEX "products_search_idx" ON "products" USING gin '
        '("search")',
      );
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
