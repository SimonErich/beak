import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mysql/worm_mysql.dart';

PredicateTree _leaf({
  required String field,
  required Operator op,
  Object? value,
}) => LeafNode(Predicate(fieldName: field, operator: op, value: value));

void main() {
  const compiler = MysqlCompiler();

  test(
    'current single-row read preserves bound predicates and update locks',
    () {
      final result = compiler.compileCurrentSelect(
        QueryDescriptor(
          table: 'notes',
          where: const Field<String>('id').eq('one'),
          limit: 20,
        ),
      );
      expect(
        result.sql,
        'SELECT * FROM `notes` WHERE `id` = ? LIMIT 1 FOR UPDATE',
      );
      expect(result.parameters, ['one']);
    },
  );

  group('MysqlCompiler — predicates', () {
    test('eq emits = with positional ? placeholder', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'age', op: Operator.eq, value: 18),
        ),
      );
      expect(result.sql, contains('`age` = ?'));
      expect(result.parameters, <Object?>[18]);
    });

    test('neq emits != placeholder', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'age', op: Operator.neq, value: 18),
        ),
      );
      expect(result.sql, contains('`age` != ?'));
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
          contains('`age` ${entry.value} ?'),
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
      expect(result.sql, contains('`name` LIKE ?'));
      expect(result.parameters, <Object?>['A%']);
    });

    test('notLike emits NOT LIKE placeholder', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'name', op: Operator.notLike, value: 'A%'),
        ),
      );
      expect(result.sql, contains('`name` NOT LIKE ?'));
    });

    test('ilike folds both sides to lower case (no MySQL ILIKE)', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'name', op: Operator.ilike, value: 'a%'),
        ),
      );
      expect(result.sql, contains('LOWER(`name`) LIKE LOWER(?)'));
      expect(result.parameters, <Object?>['a%']);
    });

    test('an escape character is stated with the backslash doubled', () {
      const escapeClause = r"ESCAPE '\\'";
      final cases = <(Operator, String)>[
        (Operator.like, '`name` LIKE ? $escapeClause'),
        (Operator.notLike, '`name` NOT LIKE ? $escapeClause'),
        (Operator.ilike, 'LOWER(`name`) LIKE LOWER(?) $escapeClause'),
      ];
      for (final (op, expected) in cases) {
        final result = compiler.compileSelect(
          QueryDescriptor(
            table: 'users',
            where: LeafNode(
              Predicate(
                fieldName: 'name',
                operator: op,
                value: r'a\%',
                escape: r'\',
              ),
            ),
          ),
        );
        expect(result.sql, contains(expected), reason: '$op');
        expect(result.parameters, <Object?>[r'a\%']);
      }
    });

    test('isNull emits IS NULL without consuming parameters', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'email', op: Operator.isNull),
        ),
      );
      expect(result.sql, contains('`email` IS NULL'));
      expect(result.parameters, isEmpty);
    });

    test('isNotNull emits IS NOT NULL without consuming parameters', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'email', op: Operator.isNotNull),
        ),
      );
      expect(result.sql, contains('`email` IS NOT NULL'));
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
      expect(result.sql, contains('`age` IN (?, ?, ?)'));
      expect(result.parameters, <Object?>[25, 30, 40]);
    });

    test('empty inList emits a false constant', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(
            field: 'age',
            op: Operator.inList,
            value: const <Object?>[],
          ),
        ),
      );
      expect(result.sql, contains('1 = 0'));
    });

    test('empty notInList emits a true constant', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: _leaf(
            field: 'age',
            op: Operator.notInList,
            value: const <Object?>[],
          ),
        ),
      );
      expect(result.sql, contains('1 = 1'));
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
      expect(result.sql, contains('`age` BETWEEN ? AND ?'));
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
      expect(result.sql, contains('`age` NOT BETWEEN ? AND ?'));
    });

    test('RawNode passes its ? placeholders and params through', () {
      final result = compiler.compileSelect(
        const QueryDescriptor(
          table: 'users',
          where: RawNode(
            'JSON_EXTRACT(`data`, ?) = ?',
            parameters: <Object?>[r'$.role', 'admin'],
          ),
        ),
      );
      expect(result.sql, contains('JSON_EXTRACT(`data`, ?) = ?'));
      expect(result.parameters, <Object?>[r'$.role', 'admin']);
    });
  });

  group('MysqlCompiler — IN auto-chunking', () {
    test('1000 values stay in a single IN clause', () {
      final values = List<Object?>.generate(1000, (i) => i);
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
      expect('`id` IN'.allMatches(result.sql).length, 1);
      expect(result.parameters, hasLength(1000));
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
      expect('`id` IN'.allMatches(result.sql).length, 2);
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
      expect('`id` IN'.allMatches(result.sql).length, 3);
      expect(' OR '.allMatches(result.sql).length, 2);
    });
  });

  group('MysqlCompiler — compileToString', () {
    test('includes the SQL and a "-- Params:" line', () {
      final rendered = compiler.compileToString(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'id', op: Operator.eq, value: 1),
        ),
      );
      expect(rendered, contains('SELECT * FROM `users`'));
      expect(rendered, contains('`id` = ?'));
      expect(rendered.split('\n'), contains('-- Params: [1]'));
    });
  });

  group('MysqlCompiler — DDL', () {
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
          'FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) '
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
          'CONSTRAINT `product_tag_pair_idx` UNIQUE (`product_id`, `tag_id`)',
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
        contains('CONSTRAINT `orders_user_fk` FOREIGN KEY'),
      );
    });

    test('create table emits backtick-quoted columns + InnoDB/utf8mb4', () {
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
        'CREATE TABLE IF NOT EXISTS `users`'
        ' (`id` CHAR(36) NOT NULL PRIMARY KEY,'
        ' `name` VARCHAR(255) NOT NULL,'
        ' `age` INT)'
        ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4',
      );
      expect(result.single.parameters, isEmpty);
    });

    test('a declared auto-incrementing key becomes AUTO_INCREMENT', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'events',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
              autoIncrement: true,
            ),
            SchemaColumn(name: 'flag', type: ColumnType.boolean),
          ],
        ),
      );
      expect(
        result.single.sql,
        contains('`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY'),
      );
      // boolean maps to TINYINT(1) (round-trips to Dart bool).
      expect(result.single.sql, contains('`flag` TINYINT(1) NOT NULL'));
    });

    test('an integer key that did not ask for it does not get it', () {
      // The descriptor decides. `t.intId()` is an integer primary key whose
      // values the caller supplies; inferring AUTO_INCREMENT from the shape
      // of the column made MySQL disagree with every other dialect about
      // what the same descriptor means.
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'events',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
          ],
        ),
      );

      expect(result.single.sql, isNot(contains('AUTO_INCREMENT')));
      expect(result.single.sql, contains('`id` INT NOT NULL PRIMARY KEY'));
    });

    test('a non-key column never gets it, however it is declared', () {
      // MySQL rejects the DDL outright: an AUTO_INCREMENT column must be a
      // key. Emitting it would turn a mistake into a failed migration.
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'events',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'seq',
              type: ColumnType.integer,
              autoIncrement: true,
            ),
          ],
        ),
      );

      expect(result.single.sql, isNot(contains('AUTO_INCREMENT')));
    });

    test('non-integer primary key is not AUTO_INCREMENT', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 't',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'id', type: ColumnType.uuid, isPrimaryKey: true),
          ],
        ),
      );
      expect(result.single.sql, isNot(contains('AUTO_INCREMENT')));
    });

    test('mysqlTypeOf produces a non-empty mapping for every ColumnType', () {
      for (final type in ColumnType.values) {
        expect(
          MysqlCompiler.mysqlTypeOf(type),
          isNotEmpty,
          reason: 'missing mapping for ColumnType.${type.name}',
        );
      }
    });

    test('dropTable honours IF EXISTS', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.dropTable(table: 'users', ifExists: true),
      );
      expect(result.single.sql, 'DROP TABLE IF EXISTS `users`');
    });

    test('truncateTable emits TRUNCATE TABLE', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.truncateTable(table: 'users'),
      );
      expect(result.single.sql, 'TRUNCATE TABLE `users`');
    });

    test('a non-unique index becomes its own CREATE INDEX statement', () {
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
      expect(
        result.last.sql,
        'CREATE INDEX `users_email_idx` ON `users` (`email`)',
      );
    });

    test('a declared length and precision reach the SQL', () {
      // mysqlTypeOf has to pick a default width; the declared one wins, so a
      // VARCHAR(40) does not arrive as VARCHAR(255).
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

      expect(result.single.sql, contains('`sku` VARCHAR(40)'));
      expect(result.single.sql, contains('`price` DECIMAL(10,2)'));
    });
  });

  group('MysqlCompiler — writes', () {
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

    test('compileInsert emits a parameterised INSERT (no RETURNING)', () {
      final result = compiler.compileInsert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{'id': 1, 'name': 'Alice'},
          returning: <String>['id'],
        ),
      );
      expect(result.sql, 'INSERT INTO `users` (`id`, `name`) VALUES (?, ?)');
      expect(result.sql, isNot(contains('RETURNING')));
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
        'INSERT INTO `users` (`id`, `name`) VALUES (?, ?), (?, ?)',
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
      expect(result.sql, 'UPDATE `users` SET `age` = ? WHERE `id` = ?');
      expect(result.parameters, <Object?>[30, 1]);
    });

    test('compileDelete emits DELETE with WHERE clause', () {
      final result = compiler.compileDelete(
        DeleteDescriptor(
          table: 'users',
          where: _leaf(field: 'id', op: Operator.eq, value: 1),
        ),
      );
      expect(result.sql, 'DELETE FROM `users` WHERE `id` = ?');
      expect(result.parameters, <Object?>[1]);
    });

    test('compileDelete without WHERE clause omits the clause', () {
      final result = compiler.compileDelete(
        const DeleteDescriptor(table: 'users'),
      );
      expect(result.sql, 'DELETE FROM `users`');
    });
  });

  group('MysqlCompiler — SELECT composition', () {
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
        'SELECT * FROM `users` WHERE `age` >= ? AND `email` IS NOT NULL',
      );
    });

    test('NOT predicate wraps inner expression', () {
      final result = compiler.compileSelect(
        QueryDescriptor(
          table: 'users',
          where: NotNode(_leaf(field: 'banned', op: Operator.eq, value: true)),
        ),
      );
      expect(result.sql, contains('NOT (`banned` = ?)'));
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
      expect(result.sql, contains('(`a` = ? OR `b` = ?)'));
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
        'SELECT * FROM `users` ORDER BY `created_at` DESC LIMIT 10 OFFSET 20',
      );
    });

    test('offset without limit uses the max BIGINT as limit', () {
      final result = compiler.compileSelect(
        const QueryDescriptor(table: 'users', offset: 20),
      );
      expect(
        result.sql,
        'SELECT * FROM `users` LIMIT 18446744073709551615 OFFSET 20',
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
      expect(result.sql, 'SELECT DISTINCT `role` FROM `users`');
    });
  });

  group('MysqlCompiler — aggregates', () {
    test('count without a column uses COUNT(*)', () {
      final result = compiler.compileAggregate(
        const AggregateDescriptor.count(table: 'users'),
      );
      expect(result.sql, 'SELECT COUNT(*) AS `count` FROM `users`');
    });

    test('sum of a column emits SUM(`col`)', () {
      final result = compiler.compileAggregate(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.sum,
          column: 'score',
        ),
      );
      expect(result.sql, 'SELECT SUM(`score`) AS `sum` FROM `users`');
    });

    test('grouped aggregate emits GROUP BY', () {
      final result = compiler.compileGroupedAggregate(
        const AggregateDescriptor.count(table: 'users', groupBy: 'score'),
      );
      expect(
        result.sql,
        'SELECT `score` AS `group`, COUNT(*) AS `value` '
        'FROM `users` GROUP BY `score`',
      );
    });
  });

  group('MysqlCompiler — joins / groupBy / having', () {
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
        contains('INNER JOIN `posts` ON `posts`.`user_id` = `users`.`id`'),
      );
      expect(
        result.sql,
        contains('LEFT JOIN `profiles` ON `profiles`.`user_id` = `users`.`id`'),
      );
      expect(result.sql, contains('GROUP BY `users`.`id`'));
      expect(result.sql, contains('HAVING COUNT(*) > ?'));
      expect(result.parameters, <Object?>[5]);
    });
  });

  group('MysqlCompiler — ALTER TABLE', () {
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
      expect(
        sqlFor(const <SchemaAlteration>[
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
          'ALTER TABLE `products` DROP COLUMN `legacy`',
          'ALTER TABLE `products` ADD COLUMN `status` VARCHAR(20) NOT NULL',
          'CREATE INDEX `products_status_idx` ON `products` (`status`)',
        ],
      );
    });

    test('a change restates the whole column, because MODIFY must', () {
      // MODIFY COLUMN has no partial form, which is why the alteration
      // carries a complete end state rather than a delta.
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaChangeColumn(
            SchemaColumn(
              name: 'bio',
              type: ColumnType.string,
              length: 500,
              nullable: true,
            ),
            facets: <SchemaColumnFacet>{SchemaColumnFacet.nullability},
          ),
        ]).single,
        'ALTER TABLE `products` MODIFY COLUMN `bio` VARCHAR(500)',
      );
    });

    test('drops a foreign key with DROP FOREIGN KEY, not DROP CONSTRAINT', () {
      // DROP CONSTRAINT is 8.0.19+ only.
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaDropForeignKey('products_brand_fk'),
        ]).single,
        'ALTER TABLE `products` DROP FOREIGN KEY `products_brand_fk`',
      );
    });

    test('drops an index with the ON clause MySQL requires', () {
      expect(
        sqlFor(const <SchemaAlteration>[
          SchemaDropIndex('products_status_idx'),
        ]).single,
        'DROP INDEX `products_status_idx` ON `products`',
      );
    });

    test('refuses every IF EXISTS flag it cannot express', () {
      // Silently stripping the flag is how a non-unique index came to emit
      // nothing at all; refusing names the gap instead.
      for (final alteration in const <SchemaAlteration>[
        SchemaAddColumn(
          SchemaColumn(name: 'sku', type: ColumnType.string),
          ifNotExists: true,
        ),
        SchemaDropColumn('sku', ifExists: true),
        SchemaDropIndex('products_sku_idx', ifExists: true),
        SchemaAddIndex(
          SchemaIndex(name: 'products_sku_idx', columns: <String>['sku']),
          ifNotExists: true,
        ),
      ]) {
        expect(
          () => sqlFor(<SchemaAlteration>[alteration]),
          throwsA(isA<UnsupportedOperationException>()),
          reason: '${alteration.runtimeType} must be refused, not stripped',
        );
      }
    });

    test('refuses a partial index rather than dropping the predicate', () {
      expect(
        () => sqlFor(const <SchemaAlteration>[
          SchemaAddIndex(
            SchemaIndex(
              name: 'products_live_idx',
              columns: <String>['status'],
              where: "status = 'published'",
            ),
          ),
        ]),
        throwsA(
          isA<UnsupportedOperationException>().having(
            (e) => e.message,
            'message',
            contains('no partial indexes'),
          ),
        ),
      );
    });
  });
}
