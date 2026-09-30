import 'package:test/test.dart';
import 'package:worm/src/exception/exception.dart';

void main() {
  group('WormException', () {
    test('is abstract and implements Exception', () {
      const e = ModelNotFoundException(
        model: 'User',
        id: 1,
        message: 'not found',
      );
      expect(e, isA<Exception>());
      expect(e, isA<WormException>());
    });
  });

  group('ModelException umbrella', () {
    test('is base of every model-layer exception', () {
      const errors = <WormException>[
        ValidationException(
          field: 'email',
          rule: 'required',
          message: 'email is required',
        ),
        MassAssignmentException(
          model: 'User',
          field: 'role',
          message: 'role is guarded',
        ),
        ModelNotFoundException(model: 'User', id: 1, message: 'not found'),
        UninitializedFieldException(
          model: 'User',
          field: 'email',
          message: 'email not initialized',
        ),
        RelationNotLoadedException(
          model: 'User',
          relationName: 'posts',
          message: 'posts not loaded',
        ),
        CastException(
          field: 'age',
          fromType: 'String',
          toType: 'int',
          message: 'cannot cast age',
        ),
        LazyLoadingException(
          modelName: 'User',
          relationName: 'posts',
          message: 'lazy load forbidden in strict mode',
        ),
      ];
      for (final e in errors) {
        expect(e, isA<ModelException>(), reason: '$e is not ModelException');
        expect(e, isA<WormException>());
      }
    });

    test('catch (ModelException) catches every model-layer throw', () {
      const throws = <WormException>[
        ValidationException(
          field: 'email',
          rule: 'required',
          message: 'required',
        ),
        MassAssignmentException(model: 'U', field: 'r', message: 'guarded'),
        ModelNotFoundException(model: 'U', id: 1, message: 'm'),
        UninitializedFieldException(model: 'U', field: 'f', message: 'm'),
        RelationNotLoadedException(model: 'U', relationName: 'r', message: 'm'),
        CastException(field: 'f', fromType: 'A', toType: 'B', message: 'm'),
        LazyLoadingException(modelName: 'U', relationName: 'r', message: 'm'),
      ];
      for (final ex in throws) {
        var caught = false;
        try {
          // ignore: only_throw_errors — testing exception flow.
          throw ex;
        } on ModelException {
          caught = true;
        }
        expect(caught, isTrue, reason: 'did not catch $ex via ModelException');
      }
    });
  });

  group('AdapterException umbrella', () {
    test('is base of every adapter-layer exception', () {
      const errors = <WormException>[
        ConnectionException(host: 'localhost', port: 5432, message: 'refused'),
        ConnectionTimeoutException(
          host: 'localhost',
          port: 5432,
          timeoutMs: 5000,
          message: 'timeout',
        ),
        AuthenticationException(host: 'localhost', message: 'wrong password'),
        QueryException(query: 'SELECT 1', message: 'failed'),
        SyntaxException(query: 'SELEC 1', message: 'syntax'),
        ForeignKeyException(
          table: 'posts',
          column: 'user_id',
          message: 'fk violated',
        ),
        UniqueConstraintException(
          table: 'users',
          column: 'email',
          message: 'duplicate',
        ),
        CheckConstraintException(
          table: 'users',
          constraintName: 'positive_age',
          message: 'check failed',
        ),
        TransactionException(message: 'deadlock'),
        MigrationException(migration: '001_x', message: 'failed'),
        AdapterMismatchException(
          expectedAdapter: 'pg',
          actualAdapter: 'mongo',
          message: 'mismatch',
        ),
      ];
      for (final e in errors) {
        expect(
          e,
          isA<AdapterException>(),
          reason: '$e is not AdapterException',
        );
        expect(e, isA<WormException>());
      }
    });

    test('catch (AdapterException) catches every adapter throw', () {
      const throws = <WormException>[
        ConnectionException(host: 'h', port: 1, message: 'm'),
        QueryException(query: 'q', message: 'm'),
        TransactionException(message: 'm'),
        MigrationException(migration: 'm', message: 'm'),
        AdapterMismatchException(
          expectedAdapter: 'a',
          actualAdapter: 'b',
          message: 'm',
        ),
      ];
      for (final ex in throws) {
        var caught = false;
        try {
          // ignore: only_throw_errors — testing exception flow.
          throw ex;
        } on AdapterException {
          caught = true;
        }
        expect(
          caught,
          isTrue,
          reason: 'did not catch $ex via AdapterException',
        );
      }
    });
  });

  group('FullTableScan ↔ DangerousQuery alias', () {
    test('DangerousQueryException is FullTableScanException', () {
      const e = FullTableScanException(table: 'users', message: 'unsafe');
      expect(e, isA<DangerousQueryException>());
      const d = DangerousQueryException(table: 'users', message: 'unsafe');
      expect(d, isA<FullTableScanException>());
    });

    test('thrown as either name, caught by the other', () {
      var caught = false;
      try {
        // ignore: only_throw_errors — testing exception flow.
        throw const DangerousQueryException(table: 'users', message: 'unsafe');
      } on FullTableScanException {
        caught = true;
      }
      expect(caught, isTrue);

      caught = false;
      try {
        // ignore: only_throw_errors — testing exception flow.
        throw const FullTableScanException(table: 'users', message: 'unsafe');
      } on DangerousQueryException {
        caught = true;
      }
      expect(caught, isTrue);
    });
  });

  group('ModelNotFoundException', () {
    const e = ModelNotFoundException(
      model: 'User',
      id: 42,
      message: 'User with id 42 not found',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends ModelException', () {
      expect(e, isA<ModelException>());
      expect(e, isA<WormException>());
    });

    test('exposes typed fields', () {
      expect(e.model, 'User');
      expect(e.id, 42);
      expect(e.message, 'User with id 42 not found');
    });

    test('id accepts Object types', () {
      const withString = ModelNotFoundException(
        model: 'Post',
        id: 'abc-123',
        message: 'not found',
      );
      expect(withString.id, 'abc-123');
    });

    test('toString includes model context', () {
      expect(
        e.toString(),
        'ModelNotFoundException: User with id 42 not found '
        '(model: User, id: 42)',
      );
    });
  });

  group('AdapterMismatchException', () {
    const e = AdapterMismatchException(
      expectedAdapter: 'PostgreSQL',
      actualAdapter: 'MongoDB',
      message: 'SQL not supported on MongoDB',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends AdapterException', () {
      expect(e, isA<AdapterException>());
    });

    test('exposes typed fields', () {
      expect(e.expectedAdapter, 'PostgreSQL');
      expect(e.actualAdapter, 'MongoDB');
      expect(e.message, 'SQL not supported on MongoDB');
    });

    test('toString includes adapter context', () {
      expect(
        e.toString(),
        'AdapterMismatchException: SQL not supported on MongoDB '
        '(expected: PostgreSQL, actual: MongoDB)',
      );
    });
  });

  group('QueryException', () {
    const e = QueryException(
      query: 'SELECT * FROM users',
      message: 'syntax error',
      nativeError: 'pg_error_42601',
      table: 'users',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends AdapterException', () {
      expect(e, isA<AdapterException>());
    });

    test('exposes typed fields', () {
      expect(e.query, 'SELECT * FROM users');
      expect(e.message, 'syntax error');
      expect(e.nativeError, 'pg_error_42601');
      expect(e.table, 'users');
    });

    test('nativeError and table are nullable', () {
      const without = QueryException(query: 'SELECT 1', message: 'failed');
      expect(without.nativeError, isNull);
      expect(without.table, isNull);
    });

    test('toString includes query context', () {
      expect(
        e.toString(),
        'QueryException: syntax error '
        '(table: users, query: SELECT * FROM users, '
        'nativeError: pg_error_42601)',
      );
    });
  });

  group('FullTableScanException', () {
    const e = FullTableScanException(
      table: 'users',
      message: 'full table scan detected',
      queryHint: 'Add a WHERE clause',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends WormException directly (umbrella-free)', () {
      expect(e, isA<WormException>());
    });

    test('exposes typed fields', () {
      expect(e.table, 'users');
      expect(e.message, 'full table scan detected');
      expect(e.queryHint, 'Add a WHERE clause');
    });

    test('queryHint is nullable', () {
      const withoutHint = FullTableScanException(
        table: 'posts',
        message: 'dangerous',
      );
      expect(withoutHint.queryHint, isNull);
      expect(
        withoutHint.toString(),
        'FullTableScanException: dangerous (table: posts)',
      );
    });

    test('toString includes table context', () {
      expect(
        e.toString(),
        'FullTableScanException: full table scan detected '
        '(table: users, hint: Add a WHERE clause)',
      );
    });
  });

  group('MassAssignmentException', () {
    const e = MassAssignmentException(
      model: 'User',
      field: 'role',
      message: 'role is guarded',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends ModelException', () {
      expect(e, isA<ModelException>());
    });

    test('exposes typed fields', () {
      expect(e.model, 'User');
      expect(e.field, 'role');
      expect(e.message, 'role is guarded');
    });

    test('toString includes model and field', () {
      expect(
        e.toString(),
        'MassAssignmentException: role is guarded '
        '(model: User, field: role)',
      );
    });
  });

  group('UniqueConstraintException', () {
    const e = UniqueConstraintException(
      table: 'users',
      column: 'email',
      message: 'duplicate email',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends AdapterException', () {
      expect(e, isA<AdapterException>());
    });

    test('exposes typed fields', () {
      expect(e.table, 'users');
      expect(e.column, 'email');
      expect(e.message, 'duplicate email');
    });

    test('toString includes table and column', () {
      expect(
        e.toString(),
        'UniqueConstraintException: duplicate email '
        '(table: users, column: email)',
      );
    });
  });

  group('ForeignKeyException', () {
    const e = ForeignKeyException(
      table: 'posts',
      column: 'user_id',
      message: 'referenced user missing',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends AdapterException', () {
      expect(e, isA<AdapterException>());
    });

    test('exposes typed fields', () {
      expect(e.table, 'posts');
      expect(e.column, 'user_id');
      expect(e.message, 'referenced user missing');
    });

    test('toString includes table and column', () {
      expect(
        e.toString(),
        'ForeignKeyException: referenced user missing '
        '(table: posts, column: user_id)',
      );
    });
  });

  group('ValidationException', () {
    const e = ValidationException(
      field: 'email',
      rule: 'required',
      message: 'email is required',
      value: '',
      model: 'User',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends ModelException', () {
      expect(e, isA<ModelException>());
    });

    test('exposes typed fields', () {
      expect(e.field, 'email');
      expect(e.rule, 'required');
      expect(e.message, 'email is required');
      expect(e.value, '');
      expect(e.model, 'User');
    });

    test('value is nullable', () {
      const withNull = ValidationException(
        field: 'name',
        rule: 'required',
        message: 'name is required',
      );
      expect(withNull.value, isNull);
      expect(withNull.model, isNull);
    });

    test('toString includes model, field, rule when set', () {
      expect(
        e.toString(),
        'ValidationException: email is required '
        '(model: User, field: email, rule: required)',
      );
    });

    test('toString omits empty field/rule for fromMap', () {
      final fromMap = ValidationException.fromMap(<String, List<String>>{
        'email': <String>['malformed'],
      }, model: 'User');
      expect(fromMap.toString().contains('field:'), isFalse);
      expect(fromMap.toString().contains('rule:'), isFalse);
      expect(fromMap.toString().contains('model: User'), isTrue);
    });
  });

  group('CastException', () {
    const e = CastException(
      field: 'age',
      fromType: 'String',
      toType: 'int',
      message: 'cannot cast age',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends ModelException', () {
      expect(e, isA<ModelException>());
    });

    test('exposes typed fields', () {
      expect(e.field, 'age');
      expect(e.fromType, 'String');
      expect(e.toType, 'int');
      expect(e.message, 'cannot cast age');
    });

    test('toString includes field and type context', () {
      expect(
        e.toString(),
        'CastException: cannot cast age '
        '(field: age, from: String, to: int)',
      );
    });
  });

  group('TransactionException', () {
    const e = TransactionException(
      message: 'deadlock detected',
      savepointName: 'sp1',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends AdapterException', () {
      expect(e, isA<AdapterException>());
    });

    test('exposes typed fields', () {
      expect(e.message, 'deadlock detected');
      expect(e.savepointName, 'sp1');
    });

    test('savepointName is nullable', () {
      const withoutSavepoint = TransactionException(message: 'timeout');
      expect(withoutSavepoint.savepointName, isNull);
      expect(withoutSavepoint.toString(), 'TransactionException: timeout');
    });

    test('toString includes savepoint when set', () {
      expect(
        e.toString(),
        'TransactionException: deadlock detected (savepoint: sp1)',
      );
    });
  });

  group('ConfigurationException', () {
    const e = ConfigurationException(
      key: 'database.host',
      message: 'host is required',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends WormException directly (umbrella-free)', () {
      expect(e, isA<WormException>());
    });

    test('exposes typed fields', () {
      expect(e.key, 'database.host');
      expect(e.message, 'host is required');
    });

    test('toString includes key', () {
      expect(
        e.toString(),
        'ConfigurationException: host is required (key: database.host)',
      );
    });
  });

  group('ConnectionException', () {
    const e = ConnectionException(
      host: 'localhost',
      port: 5432,
      message: 'connection refused',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends AdapterException', () {
      expect(e, isA<AdapterException>());
    });

    test('exposes typed fields', () {
      expect(e.host, 'localhost');
      expect(e.port, 5432);
      expect(e.message, 'connection refused');
    });

    test('toString includes host and port', () {
      expect(
        e.toString(),
        'ConnectionException: connection refused '
        '(host: localhost, port: 5432)',
      );
    });
  });

  group('MigrationException', () {
    const e = MigrationException(
      migration: '001_create_users',
      message: 'migration failed',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends AdapterException', () {
      expect(e, isA<AdapterException>());
    });

    test('exposes typed fields', () {
      expect(e.migration, '001_create_users');
      expect(e.message, 'migration failed');
    });

    test('toString includes migration name', () {
      expect(
        e.toString(),
        'MigrationException: migration failed '
        '(migration: 001_create_users)',
      );
    });
  });

  group('RelationNotLoadedException', () {
    const e = RelationNotLoadedException(
      model: 'User',
      relationName: 'posts',
      message: 'posts not loaded',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends ModelException', () {
      expect(e, isA<ModelException>());
    });

    test('exposes typed fields', () {
      expect(e.model, 'User');
      expect(e.relationName, 'posts');
      expect(e.message, 'posts not loaded');
    });

    test('toString includes model and relation', () {
      expect(
        e.toString(),
        'RelationNotLoadedException: posts not loaded '
        '(model: User, relation: posts)',
      );
    });
  });

  group('UninitializedFieldException', () {
    const e = UninitializedFieldException(
      model: 'User',
      field: 'email',
      message: 'email not initialized',
    );

    test('is const constructible', () {
      expect(e, isNotNull);
    });

    test('extends ModelException', () {
      expect(e, isA<ModelException>());
    });

    test('exposes typed fields', () {
      expect(e.model, 'User');
      expect(e.field, 'email');
      expect(e.message, 'email not initialized');
    });

    test('toString includes model and field', () {
      expect(
        e.toString(),
        'UninitializedFieldException: email not initialized '
        '(model: User, field: email)',
      );
    });
  });

  group('ConnectionTimeoutException (new)', () {
    const e = ConnectionTimeoutException(
      host: 'db.internal',
      port: 5432,
      timeoutMs: 5000,
      message: 'connect timeout',
    );

    test('is const constructible and inherits ConnectionException', () {
      expect(e, isA<ConnectionException>());
      expect(e, isA<AdapterException>());
      expect(e, isA<WormException>());
    });

    test('exposes timeoutMs and host/port', () {
      expect(e.host, 'db.internal');
      expect(e.port, 5432);
      expect(e.timeoutMs, 5000);
    });

    test('toString includes host/port/timeoutMs context', () {
      expect(
        e.toString(),
        'ConnectionTimeoutException: connect timeout '
        '(host: db.internal, port: 5432, timeoutMs: 5000)',
      );
    });
  });

  group('AuthenticationException (new)', () {
    const e = AuthenticationException(
      host: 'db.internal',
      username: 'app_user',
      message: 'wrong password',
    );

    test('is an AdapterException', () {
      expect(e, isA<AdapterException>());
      expect(e, isA<WormException>());
    });

    test('exposes host and username', () {
      expect(e.host, 'db.internal');
      expect(e.username, 'app_user');
    });

    test('username defaults to null when omitted', () {
      const without = AuthenticationException(
        host: 'db.internal',
        message: 'wrong password',
      );
      expect(without.username, isNull);
    });

    test('toString includes host and username context when set', () {
      expect(
        e.toString(),
        'AuthenticationException: wrong password '
        '(host: db.internal, username: app_user)',
      );
    });

    test('toString omits username when null', () {
      const noUser = AuthenticationException(
        host: 'db.internal',
        message: 'wrong password',
      );
      expect(noUser.toString().contains('username:'), isFalse);
      expect(noUser.toString().contains('host: db.internal'), isTrue);
    });
  });

  group('DataException', () {
    const e = DataException(
      table: 'users',
      column: 'name',
      message: 'value too long for type character varying(255)',
    );

    test('is an AdapterException', () {
      expect(e, isA<AdapterException>());
      expect(e, isA<WormException>());
    });

    test('exposes table and column', () {
      expect(e.table, 'users');
      expect(e.column, 'name');
    });

    test('column defaults to null when the driver names none', () {
      const minimal = DataException(table: 'users', message: 'bad value');
      expect(minimal.column, isNull);
    });

    test('context carries table and column', () {
      expect(e.context, {'table': 'users', 'column': 'name'});
    });

    test('toString names the table and, when known, the column', () {
      expect(
        e.toString(),
        'DataException: value too long for type character varying(255) '
        '(table: users, column: name)',
      );
      expect(
        const DataException(table: 'users', message: 'bad').toString(),
        'DataException: bad (table: users)',
      );
    });
  });

  group('CheckConstraintException (new)', () {
    const e = CheckConstraintException(
      table: 'users',
      constraintName: 'age_positive',
      column: 'age',
      message: 'age must be positive',
    );

    test('is an AdapterException', () {
      expect(e, isA<AdapterException>());
      expect(e, isA<WormException>());
    });

    test('exposes table, column, constraintName', () {
      expect(e.table, 'users');
      expect(e.column, 'age');
      expect(e.constraintName, 'age_positive');
    });

    test('column and constraintName default to null when omitted', () {
      const minimal = CheckConstraintException(
        table: 'users',
        message: 'check failed',
      );
      expect(minimal.column, isNull);
      expect(minimal.constraintName, isNull);
    });

    test('toString includes table/column/constraintName context', () {
      expect(
        e.toString(),
        'CheckConstraintException: age must be positive '
        '(table: users, column: age, constraintName: age_positive)',
      );
    });
  });

  group('SyntaxException (new)', () {
    const e = SyntaxException(
      query: 'SELEC 1',
      message: 'unexpected token',
      position: 5,
      table: 'users',
      nativeError: '42601',
    );

    test('is a QueryException and AdapterException', () {
      expect(e, isA<QueryException>());
      expect(e, isA<AdapterException>());
    });

    test('exposes query, position, nativeError, table', () {
      expect(e.query, 'SELEC 1');
      expect(e.position, 5);
      expect(e.nativeError, '42601');
      expect(e.table, 'users');
    });

    test('toString includes query context', () {
      expect(
        e.toString(),
        'SyntaxException: unexpected token '
        '(table: users, query: SELEC 1, position: 5, nativeError: 42601)',
      );
    });
  });

  group('LazyLoadingException (new)', () {
    const e = LazyLoadingException(
      modelName: 'User',
      relationName: 'posts',
      message: 'lazy load forbidden in strict mode',
    );

    test('is a ModelException and WormException', () {
      expect(e, isA<ModelException>());
      expect(e, isA<WormException>());
    });

    test('exposes modelName and relation', () {
      expect(e.modelName, 'User');
      expect(e.relationName, 'posts');
    });

    test('toString includes modelName and relation context', () {
      expect(
        e.toString(),
        'LazyLoadingException: lazy load forbidden in strict mode '
        '(modelName: User, relation: posts)',
      );
    });
  });

  group('MigrationLockException (new)', () {
    const e = MigrationLockException(
      migration: '001_create_users',
      message: 'cannot acquire migration lock',
      lockHolder: 'pid=42',
    );

    test('extends WormException directly (umbrella-free)', () {
      expect(e, isA<WormException>());
      expect(e, isNot(isA<ModelException>()));
      expect(e, isNot(isA<AdapterException>()));
      expect(e, isNot(isA<MigrationException>()));
    });

    test('exposes migration and lockHolder', () {
      expect(e.migration, '001_create_users');
      expect(e.lockHolder, 'pid=42');
    });

    test('lockHolder defaults to null when omitted', () {
      const minimal = MigrationLockException(
        migration: '001_create_users',
        message: 'cannot acquire migration lock',
      );
      expect(minimal.lockHolder, isNull);
    });

    test('toString includes migration and lockHolder context', () {
      expect(
        e.toString(),
        'MigrationLockException: cannot acquire migration lock '
        '(migration: 001_create_users, lockHolder: pid=42)',
      );
    });
  });

  group('IrreversibleMigrationException (new)', () {
    const e = IrreversibleMigrationException(
      migration: '001_drop_users',
      message: 'cannot roll back',
      reason: 'data lost',
    );

    test('extends WormException directly (umbrella-free)', () {
      expect(e, isA<WormException>());
      expect(e, isNot(isA<ModelException>()));
      expect(e, isNot(isA<AdapterException>()));
      expect(e, isNot(isA<MigrationException>()));
    });

    test('exposes migration and reason', () {
      expect(e.migration, '001_drop_users');
      expect(e.reason, 'data lost');
    });

    test('toString includes migration and reason context', () {
      expect(
        e.toString(),
        'IrreversibleMigrationException: cannot roll back '
        '(migration: 001_drop_users, reason: data lost)',
      );
    });
  });

  group('UnsupportedOperationException (new)', () {
    const e = UnsupportedOperationException(
      operation: 'savepoint',
      adapter: 'MongoDB',
      message: 'MongoDB does not support savepoints',
    );

    test('extends WormException directly (umbrella-free)', () {
      expect(e, isA<WormException>());
      expect(e, isNot(isA<AdapterException>()));
      expect(e, isNot(isA<ModelException>()));
    });

    test('exposes operation and adapter', () {
      expect(e.operation, 'savepoint');
      expect(e.adapter, 'MongoDB');
    });

    test('adapter defaults to null when omitted', () {
      const minimal = UnsupportedOperationException(
        operation: 'savepoint',
        message: 'not supported',
      );
      expect(minimal.adapter, isNull);
      expect(minimal.operation, 'savepoint');
    });

    test('toString includes operation and adapter context', () {
      expect(
        e.toString(),
        'UnsupportedOperationException: '
        'MongoDB does not support savepoints '
        '(operation: savepoint, adapter: MongoDB)',
      );
    });
  });

  group('OperationCancelledException (new)', () {
    const e = OperationCancelledException(
      operation: 'save',
      message: 'save cancelled by beforeSave hook',
      hook: 'beforeSave',
    );

    test('extends WormException directly (umbrella-free)', () {
      expect(e, isA<WormException>());
      expect(e, isNot(isA<ModelException>()));
      expect(e, isNot(isA<AdapterException>()));
    });

    test('exposes operation and hook', () {
      expect(e.operation, 'save');
      expect(e.hook, 'beforeSave');
    });

    test('hook defaults to null when omitted', () {
      const minimal = OperationCancelledException(
        operation: 'save',
        message: 'cancelled',
      );
      expect(minimal.hook, isNull);
      expect(minimal.operation, 'save');
    });

    test('toString includes operation and hook context', () {
      expect(
        e.toString(),
        'OperationCancelledException: save cancelled by beforeSave hook '
        '(operation: save, hook: beforeSave)',
      );
    });
  });
}
