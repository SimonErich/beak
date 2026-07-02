import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/logging/explain_runner.dart';
import 'package:worm/src/logging/logging_adapter.dart';
import 'package:worm/src/logging/n_plus_one_detector.dart';
import 'package:worm/src/logging/query_log.dart';
import 'package:worm/src/logging/query_logger.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/operator.dart';
import 'package:worm/src/query/predicate.dart';
import 'package:worm/src/query/predicate_tree.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/schema/column_type.dart';

import '_test_adapters.dart';

Future<void> _setupUsers(DatabaseAdapter adapter) async {
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'users',
      columns: <SchemaColumn>[
        SchemaColumn(name: 'id', type: ColumnType.text),
        SchemaColumn(name: 'name', type: ColumnType.text),
      ],
    ),
  );
  await adapter.insert(
    const InsertDescriptor(
      table: 'users',
      values: <String, Object?>{'id': '1', 'name': 'Alice'},
    ),
  );
  await adapter.insert(
    const InsertDescriptor(
      table: 'users',
      values: <String, Object?>{'id': '2', 'name': 'Bob'},
    ),
  );
}

bool _isNPlusOne(String line) =>
    line.contains('[WARNING]') && line.contains('N+1');
bool _isMissingIndex(String line) =>
    line.contains('[WARNING]') && line.contains('missing-index');

void main() {
  group('LoggingAdapter — query capture', () {
    test('records statement, params, duration and row count', () async {
      final inner = InMemoryAdapter();
      await _setupUsers(inner);
      final logger = InMemoryQueryLogger();
      final wrapped = LoggingAdapter(
        inner: inner,
        logger: logger,
        strictness: const StrictnessConfig(),
        adapterName: 'InMemory',
      );

      final rows = await wrapped.select(
        const QueryDescriptor(
          table: 'users',
          where: LeafNode(
            Predicate(fieldName: 'name', operator: Operator.eq, value: 'Alice'),
          ),
        ),
      );

      expect(rows, hasLength(1));
      expect(logger.entries, hasLength(1));
      final entry = logger.entries.single;
      expect(entry.statement, contains('users'));
      expect(entry.parameters, <Object?>['Alice']);
      expect(entry.adapter, 'InMemory');
      expect(entry.table, 'users');
      expect(entry.rowCount, 1);
    });
  });

  group('LoggingAdapter — slow query', () {
    test('logs slow query when duration exceeds threshold', () async {
      final inner = SlowAdapter();
      await _setupUsers(inner);
      final logger = InMemoryQueryLogger(
        config: const LogConfig(slowQueryThreshold: Duration(milliseconds: 5)),
      );
      final wrapped = LoggingAdapter(
        inner: inner,
        logger: logger,
        strictness: const StrictnessConfig(
          slowQueryThreshold: Duration(milliseconds: 5),
        ),
      );

      await wrapped.select(const QueryDescriptor(table: 'users'));

      expect(logger.slowQueries, hasLength(1));
    });
  });

  group('LoggingAdapter — N+1 detection', () {
    test(
      'emits warning after threshold same-table single-row lookups',
      () async {
        final inner = InMemoryAdapter();
        await inner.connect();
        await inner.executeSchema(
          const SchemaDescriptor.createTable(
            table: 'posts',
            columns: <SchemaColumn>[
              SchemaColumn(name: 'id', type: ColumnType.text),
              SchemaColumn(name: 'user_id', type: ColumnType.text),
            ],
          ),
        );
        for (var i = 1; i <= 3; i++) {
          await inner.insert(
            InsertDescriptor(
              table: 'posts',
              values: <String, Object?>{'id': '$i', 'user_id': '$i'},
            ),
          );
        }
        final logger = InMemoryQueryLogger();
        final wrapped = LoggingAdapter(
          inner: inner,
          logger: logger,
          strictness: const StrictnessConfig(warnOnN1Queries: true),
          detector: NPlusOneDetector(threshold: 3),
        );

        for (var i = 1; i <= 3; i++) {
          await wrapped.select(
            QueryDescriptor(
              table: 'posts',
              where: LeafNode(
                Predicate(
                  fieldName: 'user_id',
                  operator: Operator.eq,
                  value: '$i',
                ),
              ),
              limit: 1,
            ),
          );
        }

        final fires = logger.lines.where(_isNPlusOne).toList();
        expect(fires, hasLength(1));
        expect(fires.single, contains('posts'));
      },
    );

    test('does not throw or warn when flag is off', () async {
      final inner = InMemoryAdapter();
      await _setupUsers(inner);
      final logger = InMemoryQueryLogger();
      final wrapped = LoggingAdapter(
        inner: inner,
        logger: logger,
        strictness: const StrictnessConfig(),
      );

      for (var i = 0; i < 10; i++) {
        await wrapped.selectOne(
          const QueryDescriptor(
            table: 'users',
            where: LeafNode(
              Predicate(fieldName: 'id', operator: Operator.eq, value: '1'),
            ),
            limit: 1,
          ),
        );
      }
      expect(logger.lines.where(_isNPlusOne), isEmpty);
    });

    test('multi-row queries do not contribute to N+1 detection', () async {
      final inner = InMemoryAdapter();
      await _setupUsers(inner);
      final logger = InMemoryQueryLogger();
      final wrapped = LoggingAdapter(
        inner: inner,
        logger: logger,
        strictness: const StrictnessConfig(warnOnN1Queries: true),
        detector: NPlusOneDetector(threshold: 3),
      );

      for (var i = 0; i < 5; i++) {
        await wrapped.select(const QueryDescriptor(table: 'users'));
      }

      expect(logger.lines.where(_isNPlusOne), isEmpty);
    });
  });

  group('LoggingAdapter — missing index', () {
    test('logs warning when explain reports no index', () async {
      final inner = ExplainAdapter(indexed: const <String>{'id'});
      await _setupUsers(inner);
      final logger = InMemoryQueryLogger();
      final wrapped = LoggingAdapter(
        inner: inner,
        logger: logger,
        strictness: const StrictnessConfig(warnOnMissingIndex: true),
      );

      await wrapped.select(
        const QueryDescriptor(
          table: 'users',
          where: LeafNode(
            Predicate(fieldName: 'name', operator: Operator.eq, value: 'Alice'),
          ),
        ),
      );

      final fires = logger.lines.where(_isMissingIndex).toList();
      expect(fires, hasLength(1));
      expect(fires.single, contains('users'));
      expect(fires.single, contains('name'));
    });

    test('does not warn when an index is present', () async {
      final inner = ExplainAdapter(indexed: const <String>{'id'});
      await _setupUsers(inner);
      final logger = InMemoryQueryLogger();
      final wrapped = LoggingAdapter(
        inner: inner,
        logger: logger,
        strictness: const StrictnessConfig(warnOnMissingIndex: true),
      );

      await wrapped.select(
        const QueryDescriptor(
          table: 'users',
          where: LeafNode(
            Predicate(fieldName: 'id', operator: Operator.eq, value: '1'),
          ),
        ),
      );

      expect(logger.lines.where(_isMissingIndex), isEmpty);
    });

    test('stays silent when the adapter cannot EXPLAIN', () async {
      final inner = CapabilityFreeExplainAdapter();
      await _setupUsers(inner);
      final logger = InMemoryQueryLogger();
      final wrapped = LoggingAdapter(
        inner: inner,
        logger: logger,
        strictness: const StrictnessConfig(warnOnMissingIndex: true),
      );

      await wrapped.select(
        const QueryDescriptor(
          table: 'users',
          where: LeafNode(
            Predicate(fieldName: 'name', operator: Operator.eq, value: 'Alice'),
          ),
        ),
      );

      expect(logger.lines.where(_isMissingIndex), isEmpty);
    });
  });

  group('MissingIndexWarner — direct', () {
    test('writes a [WARNING] line via logger.logWarning', () async {
      final adapter = ExplainAdapter(indexed: const <String>{'id'});
      final logger = InMemoryQueryLogger();
      const warner = MissingIndexWarner();

      await warner.checkAfterQuery(
        descriptor: const QueryDescriptor(
          table: 'users',
          where: LeafNode(
            Predicate(fieldName: 'email', operator: Operator.eq, value: 'a@b'),
          ),
        ),
        capabilities: adapter.capabilities,
        adapter: adapter,
        logger: logger,
      );

      expect(logger.lines.where(_isMissingIndex), hasLength(1));
    });

    test('no output when capabilities.supportsExplain is false', () async {
      final adapter = CapabilityFreeExplainAdapter();
      final logger = InMemoryQueryLogger();
      const warner = MissingIndexWarner();

      await warner.checkAfterQuery(
        descriptor: const QueryDescriptor(
          table: 'users',
          where: LeafNode(
            Predicate(fieldName: 'email', operator: Operator.eq, value: 'a@b'),
          ),
        ),
        capabilities: adapter.capabilities,
        adapter: adapter,
        logger: logger,
      );

      expect(logger.lines, isEmpty);
    });

    test('no output when ExplainResult.usesIndex is true', () async {
      final adapter = ExplainAdapter(indexed: const <String>{'id'});
      final logger = InMemoryQueryLogger();
      const warner = MissingIndexWarner();

      await warner.checkAfterQuery(
        descriptor: const QueryDescriptor(
          table: 'users',
          where: LeafNode(
            Predicate(fieldName: 'id', operator: Operator.eq, value: '1'),
          ),
        ),
        capabilities: adapter.capabilities,
        adapter: adapter,
        logger: logger,
      );

      expect(logger.lines, isEmpty);
    });
  });

  group('ExplainResult', () {
    test('is const-constructible and immutable', () {
      const a = ExplainResult(usesIndex: true, raw: 'plan');
      const b = ExplainResult(usesIndex: true, raw: 'plan');
      expect(identical(a, b), isTrue);
      expect(a.usesIndex, isTrue);
      expect(a.estimatedCost, 0);
      expect(a.estimatedRows, 0);
      expect(a.indexName, isNull);
      expect(a.scannedTables, isEmpty);
    });
  });

  group('InMemoryAdapter — explain', () {
    test('returns ExplainResult with usesIndex: true', () async {
      final adapter = InMemoryAdapter();
      final result = await adapter.explain(
        const QueryDescriptor(table: 'users'),
      );
      expect(result.usesIndex, isTrue);
      expect(adapter.capabilities.supportsExplain, isTrue);
    });
  });

  group('Logger surface used by LoggingAdapter', () {
    test('logWarning yields a [WARNING] line', () {
      final logger = InMemoryQueryLogger()..logWarning('something');
      expect(logger.lines.single, contains('[WARNING] something'));
    });

    test('captured QueryLog is independent of warning output', () {
      const entry = QueryLog(
        statement: 'SELECT 1',
        parameters: <Object?>[],
        duration: Duration(microseconds: 1),
        rowCount: 0,
        adapter: 'InMemory',
      );
      final logger = InMemoryQueryLogger()..log(entry);
      expect(logger.entries, hasLength(1));
    });
  });
}
