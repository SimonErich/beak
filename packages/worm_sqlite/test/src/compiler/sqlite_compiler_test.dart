import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

PredicateTree _leaf({
  required String field,
  required Operator op,
  Object? value,
}) => LeafNode(Predicate(fieldName: field, operator: op, value: value));

const _brandReference = 'REFERENCES "brands" ("id") ON DELETE SET NULL';

const _namedBrandReference =
    'ALTER TABLE "products" ADD COLUMN "brand_id" TEXT CONSTRAINT '
    '"products_brand_fk" REFERENCES "brands" ("id") ON DELETE RESTRICT';

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

  group('SqliteCompiler LIKE escaping', () {
    PredicateTree like(Operator op, {String? escape}) => LeafNode(
      Predicate(fieldName: 'name', operator: op, value: r'a\%', escape: escape),
    );

    test('declares the escape character in the ESCAPE clause', () {
      for (final (op, keyword) in const [
        (Operator.like, 'LIKE'),
        (Operator.ilike, 'LIKE'),
        (Operator.notLike, 'NOT LIKE'),
      ]) {
        final result = compiler.compileSelect(
          QueryDescriptor(
            table: 'users',
            where: like(op, escape: r'\'),
          ),
        );
        expect(
          result.sql,
          'SELECT * FROM "users" WHERE "name" $keyword ? ESCAPE \'\\\'',
          reason: '$op',
        );
        expect(result.parameters, <Object?>[r'a\%']);
      }
    });

    test('leaves the SQL alone when the predicate names no escape', () {
      final result = compiler.compileSelect(
        QueryDescriptor(table: 'users', where: like(Operator.like)),
      );
      expect(result.sql, 'SELECT * FROM "users" WHERE "name" LIKE ?');
    });

    test('quotes an escape character that needs it', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: like(Operator.like, escape: "'"),
        ),
      );
      expect(result.sql, endsWith("ESCAPE ''''"));
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
        result.single.sql,
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
        result.first.sql,
        contains(
          'CONSTRAINT "product_tag_pair_idx" UNIQUE ("product_id", "tag_id")',
        ),
      );
      // Not inlined as a constraint — it is its own statement instead.
      expect(result.first.sql, isNot(contains('product_tag_tag_idx')));
      expect(result.last.sql, startsWith('CREATE INDEX'));
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
          .single
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
      expect(
        result.single.sql,
        contains('CONSTRAINT "orders_user_fk" FOREIGN KEY'),
      );
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
        result.single.sql,
        'CREATE TABLE "users" ("id" INTEGER PRIMARY KEY, "name" TEXT NOT NULL, '
        '"bio" TEXT)',
      );
    });
  });

  group('SqliteCompiler — ALTER TABLE', () {
    List<String> sqlFor(List<SchemaAlteration> alterations) => <String>[
      for (final compiled in compiler.compileDdl(
        SchemaDescriptor.alterTable(
          table: 'products',
          alterations: alterations,
        ),
      ))
        compiled.sql,
    ];

    void expectRefused(List<SchemaAlteration> alterations, Matcher message) {
      expect(
        () => sqlFor(alterations),
        throwsA(
          isA<UnsupportedOperationException>()
              .having((e) => e.adapter, 'adapter', 'SqliteAdapter')
              .having((e) => e.message, 'message', message),
        ),
      );
    }

    test('adds a column and indexes it', () {
      // SQLite does both natively, which is what makes the default SQLite
      // project evolvable at all.
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaAddColumn(
            SchemaColumn(
              name: 'status',
              type: ColumnType.string,
              nullable: true,
            ),
          ),
          SchemaAddIndex(
            SchemaIndex(
              name: 'products_status_idx',
              columns: <String>['status'],
            ),
          ),
        ]),
        <String>[
          'ALTER TABLE "products" ADD COLUMN "status" TEXT',
          'CREATE INDEX "products_status_idx" ON "products" ("status")',
        ],
      );
    });

    test('refuses a NOT NULL column with no default, and says why', () {
      // The existing rows would have no value for it. SQLite rejects this
      // with a parse error; naming the cause first is more use.
      expectRefused(const <SchemaAlteration>[
        SchemaAddColumn(SchemaColumn(name: 'sku', type: ColumnType.string)),
      ], contains('NOT NULL column without a default'));
    });

    test('refuses a unique or primary-key column on an existing table', () {
      expectRefused(const <SchemaAlteration>[
        SchemaAddColumn(
          SchemaColumn(
            name: 'sku',
            type: ColumnType.string,
            nullable: true,
            unique: true,
          ),
        ),
      ], contains('CREATE UNIQUE INDEX'));
    });

    test('refuses a column change and names the escape hatch', () {
      // Rebuilding the table behind the caller would silently drop triggers,
      // views and generated columns that introspectSchema cannot see.
      expectRefused(const <SchemaAlteration>[
        SchemaChangeColumn(SchemaColumn(name: 'sku', type: ColumnType.text)),
      ], allOf(contains('rawExecute'), contains('Postgres')));
    });

    test('refuses a foreign key on an existing table', () {
      expectRefused(const <SchemaAlteration>[
        SchemaAddForeignKey(
          SchemaForeignKey(
            columns: <String>['brand_id'],
            referencedTable: 'brands',
            referencedColumns: <String>['id'],
          ),
        ),
      ], contains('only be declared in CREATE TABLE'));
    });

    test('adds a column with its foreign key as one inline reference', () {
      // SQLite cannot attach a constraint to a column that already exists,
      // but ADD COLUMN accepts a REFERENCES clause for the column it adds:
      // the additive way to relate an existing table, with no rebuild.
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaAddColumn(
            SchemaColumn(
              name: 'brand_id',
              type: ColumnType.uuid,
              nullable: true,
            ),
          ),
          SchemaAddForeignKey(
            SchemaForeignKey(
              columns: <String>['brand_id'],
              referencedTable: 'brands',
              referencedColumns: <String>['id'],
              onDelete: OnDelete.setNull,
            ),
          ),
          SchemaAddIndex(
            SchemaIndex(
              name: 'products_brand_id_idx',
              columns: <String>['brand_id'],
            ),
          ),
        ]),
        <String>[
          'ALTER TABLE "products" ADD COLUMN "brand_id" TEXT $_brandReference',
          'CREATE INDEX "products_brand_id_idx" ON "products" ("brand_id")',
        ],
      );
    });

    test('keeps the name of a foreign key it inlines', () {
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaAddForeignKey(
            SchemaForeignKey(
              name: 'products_brand_fk',
              columns: <String>['brand_id'],
              referencedTable: 'brands',
              referencedColumns: <String>['id'],
              onDelete: OnDelete.restrict,
            ),
          ),
          SchemaAddColumn(
            SchemaColumn(
              name: 'brand_id',
              type: ColumnType.uuid,
              nullable: true,
            ),
          ),
        ]),
        <String>[_namedBrandReference],
      );
    });

    test('refuses a reference on an added column with a non-null default', () {
      // With foreign keys enforced, SQLite rejects the ADD COLUMN outright:
      // every existing row would point at the default.
      expectRefused(const <SchemaAlteration>[
        SchemaAddColumn(
          SchemaColumn(
            name: 'brand_id',
            type: ColumnType.uuid,
            nullable: true,
            defaultValue: 'house',
          ),
        ),
        SchemaAddForeignKey(
          SchemaForeignKey(
            columns: <String>['brand_id'],
            referencedTable: 'brands',
            referencedColumns: <String>['id'],
          ),
        ),
      ], contains('default of NULL'));
    });

    test('refuses a composite foreign key even over added columns', () {
      // An inline REFERENCES names one column; a composite key is a table
      // constraint, which only CREATE TABLE can declare.
      expectRefused(const <SchemaAlteration>[
        SchemaAddColumn(
          SchemaColumn(name: 'brand_id', type: ColumnType.uuid, nullable: true),
        ),
        SchemaAddColumn(
          SchemaColumn(name: 'region', type: ColumnType.string, nullable: true),
        ),
        SchemaAddForeignKey(
          SchemaForeignKey(
            columns: <String>['brand_id', 'region'],
            referencedTable: 'brands',
            referencedColumns: <String>['id', 'region'],
          ),
        ),
      ], contains('only be declared in CREATE TABLE'));
    });

    test('refuses a reference whose parent columns do not match', () {
      expectRefused(const <SchemaAlteration>[
        SchemaAddColumn(
          SchemaColumn(name: 'brand_id', type: ColumnType.uuid, nullable: true),
        ),
        SchemaAddForeignKey(
          SchemaForeignKey(
            columns: <String>['brand_id'],
            referencedTable: 'brands',
            referencedColumns: <String>['id', 'region'],
          ),
        ),
      ], contains('only be declared in CREATE TABLE'));
    });

    test('refuses dropping a foreign key', () {
      expectRefused(const <SchemaAlteration>[
        SchemaDropForeignKey('products_brand_fk'),
      ], contains('only be declared in CREATE TABLE'));
    });

    test('refuses an IF NOT EXISTS it cannot express', () {
      expectRefused(const <SchemaAlteration>[
        SchemaAddColumn(
          SchemaColumn(name: 'sku', type: ColumnType.string, nullable: true),
          ifNotExists: true,
        ),
      ], contains('no ADD COLUMN IF NOT EXISTS'));
    });

    test('refuses a non-btree index rather than silently building one', () {
      expectRefused(const <SchemaAlteration>[
        SchemaAddIndex(
          SchemaIndex(
            name: 'products_search_idx',
            columns: <String>['search'],
            kind: IndexKind.gin,
          ),
        ),
      ], contains('only b-tree indexes'));
    });

    test('drops a column and an index', () {
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaDropIndex('products_legacy_idx'),
          SchemaDropColumn('legacy'),
        ]),
        <String>[
          'DROP INDEX "products_legacy_idx"',
          'ALTER TABLE "products" DROP COLUMN "legacy"',
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
              where: "status = 'published'",
            ),
            ifNotExists: true,
          ),
        ]).single,
        'CREATE INDEX IF NOT EXISTS "products_live_idx" ON "products" '
        "(\"status\") WHERE status = 'published'",
      );
    });
  });

  group('SqliteCompiler defaults', () {
    test('a create renders each default as a SQLite literal', () {
      final result = const SqliteCompiler().compileDdl(
        const SchemaDescriptor.createTable(
          table: 'products',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'id', type: ColumnType.uuid, isPrimaryKey: true),
            SchemaColumn(
              name: 'status',
              type: ColumnType.string,
              defaultValue: "draft's",
            ),
            SchemaColumn(
              name: 'active',
              type: ColumnType.boolean,
              defaultValue: false,
            ),
            SchemaColumn(
              name: 'stock',
              type: ColumnType.integer,
              defaultValue: 0,
            ),
          ],
        ),
      );

      final sql = result.single.sql;
      // Quoted and escaped for text, and 1/0 for a boolean — SQLite has no
      // boolean storage class and the runner binds `true` as 1, so a `TRUE`
      // keyword default would disagree with an explicit write.
      expect(sql, contains(""""status" TEXT NOT NULL DEFAULT 'draft''s'"""));
      expect(sql, contains('"active" INTEGER NOT NULL DEFAULT 0'));
      expect(sql, contains('"stock" INTEGER NOT NULL DEFAULT 0'));
    });
  });

  group('SqliteCompiler.sqliteTypeOf', () {
    test('maps every ColumnType to one of the four storage classes', () {
      // SQLite has four of them, and a column declared as anything else
      // still resolves to one by its own affinity rules — so an unmapped
      // type would silently become TEXT rather than fail. Assert the
      // mapping is deliberate for all 27.
      const affinities = {'INTEGER', 'REAL', 'TEXT', 'BLOB', 'NUMERIC'};
      for (final type in ColumnType.values) {
        expect(
          affinities,
          contains(SqliteCompiler.sqliteTypeOf(type)),
          reason: 'ColumnType.${type.name} maps to an unknown storage class',
        );
      }
    });
  });
}
