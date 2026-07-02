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
        result.sql,
        'CREATE TABLE IF NOT EXISTS `users`'
        ' (`id` CHAR(36) NOT NULL PRIMARY KEY,'
        ' `name` VARCHAR(255) NOT NULL,'
        ' `age` INT)'
        ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4',
      );
      expect(result.parameters, isEmpty);
    });

    test('integer primary key becomes AUTO_INCREMENT', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.createTable(
          table: 'events',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
            SchemaColumn(name: 'flag', type: ColumnType.boolean),
          ],
        ),
      );
      expect(
        result.sql,
        contains('`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY'),
      );
      // boolean maps to TINYINT(1) (round-trips to Dart bool).
      expect(result.sql, contains('`flag` TINYINT(1) NOT NULL'));
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
      expect(result.sql, isNot(contains('AUTO_INCREMENT')));
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
      expect(result.sql, 'DROP TABLE IF EXISTS `users`');
    });

    test('truncateTable emits TRUNCATE TABLE', () {
      final result = compiler.compileDdl(
        const SchemaDescriptor.truncateTable(table: 'users'),
      );
      expect(result.sql, 'TRUNCATE TABLE `users`');
    });

    test('SchemaIndexDescriptor emits a named CREATE INDEX', () {
      final result = compiler.compileDdl(
        const SchemaIndexDescriptor(collection: 'users', field: 'email'),
      );
      expect(result.sql, 'CREATE INDEX `idx_users_email` ON `users` (`email`)');
    });

    test('SchemaIndexDescriptor unique=true emits CREATE UNIQUE INDEX', () {
      final result = compiler.compileDdl(
        const SchemaIndexDescriptor(
          collection: 'users',
          field: 'email',
          unique: true,
        ),
      );
      expect(
        result.sql,
        'CREATE UNIQUE INDEX `idx_users_email` ON `users` (`email`)',
      );
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
}
