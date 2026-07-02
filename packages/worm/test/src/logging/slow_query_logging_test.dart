/// Slow-query WARN-logging contract for [LoggingAdapter].
///
/// Two collaborators decide what a "slow query" looks like:
///
/// 1. `LoggingAdapter._emit` reads
///    `StrictnessConfig.slowQueryThreshold` and calls
///    `logger.slowQuery(entry, threshold)` whenever
///    `entry.duration >= threshold` — the notification path.
/// 2. `QueryLogger.log` formats one `[QUERY]` or
///    `[SLOW QUERY]` line per entry, deciding the prefix
///    against `LogConfig.slowQueryThreshold` — the line-text
///    path.
///
/// Production code always aligns these two thresholds.
/// The tests below force the alignment explicitly via
/// `Duration.zero` (every query counts as slow) and
/// `Duration(days: 999)` (no query counts as slow) so the
/// assertions are deterministic regardless of how long the
/// in-memory adapter actually takes.
library;

import 'package:test/test.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/logging/logging_adapter.dart';
import 'package:worm/src/logging/query_logger.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/operator.dart';
import 'package:worm/src/query/predicate.dart';
import 'package:worm/src/query/predicate_tree.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';

import '_test_adapters.dart';

QueryDescriptor _byId(int id) => QueryDescriptor(
  table: 'rows',
  where: LeafNode(Predicate(fieldName: 'id', operator: Operator.eq, value: id)),
);

Future<DelegatingAdapter> _seeded() async {
  final adapter = DelegatingAdapter.fresh();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'rows'),
  );
  await adapter.insert(
    const InsertDescriptor(
      table: 'rows',
      values: <String, Object?>{'id': 1, 'name': 'Alice'},
    ),
  );
  return adapter;
}

LoggingAdapter _wrap(
  DelegatingAdapter inner,
  InMemoryQueryLogger logger, {
  required Duration strictnessThreshold,
}) => LoggingAdapter(
  inner: inner,
  logger: logger,
  strictness: StrictnessConfig(slowQueryThreshold: strictnessThreshold),
  adapterName: 'InMemory',
);

InMemoryQueryLogger _logger({required Duration logThreshold}) =>
    InMemoryQueryLogger(config: LogConfig(slowQueryThreshold: logThreshold));

bool _isSlowLine(String line) => line.contains('[SLOW QUERY]');
bool _isPlainQueryLine(String line) =>
    line.contains('[QUERY]') && !line.contains('[SLOW QUERY]');

void main() {
  group('LoggingAdapter._emit — query is BELOW slow threshold', () {
    test('emits a [QUERY] line and does NOT call logger.slowQuery()', () async {
      // 999 days as threshold guarantees no query the in-memory
      // adapter could possibly take qualifies as slow.
      final inner = await _seeded();
      final logger = _logger(logThreshold: const Duration(days: 999));
      final wrapped = _wrap(
        inner,
        logger,
        strictnessThreshold: const Duration(days: 999),
      );

      await wrapped.select(_byId(1));

      expect(logger.lines.any(_isSlowLine), isFalse);
      expect(logger.lines.any(_isPlainQueryLine), isTrue);
      expect(
        logger.slowQueries,
        isEmpty,
        reason:
            'StrictnessConfig.slowQueryThreshold not exceeded — the '
            'slowQuery() hook must not have fired.',
      );
    });

    test(
      'plain [QUERY] line still contains the SQL statement and bound params',
      () async {
        final inner = await _seeded();
        final logger = _logger(logThreshold: const Duration(days: 999));
        final wrapped = _wrap(
          inner,
          logger,
          strictnessThreshold: const Duration(days: 999),
        );

        await wrapped.select(_byId(42));

        final queryLine = logger.lines.firstWhere(_isPlainQueryLine);
        expect(queryLine, contains('rows'));
        expect(
          queryLine,
          contains('params:'),
          reason: 'Every [QUERY] line must surface the bound parameter list.',
        );
        // The bound parameter value (42) should be in the params section.
        expect(queryLine, contains('42'));
      },
    );
  });

  group('LoggingAdapter._emit — query is AT OR ABOVE slow threshold', () {
    test('emits a [SLOW QUERY] line AND calls logger.slowQuery() — '
        'both signals fire together', () async {
      // Duration.zero is the lowest possible threshold; any
      // observed duration `>= Duration.zero` is true, so the
      // entry is unambiguously slow regardless of in-memory
      // adapter speed.
      final inner = await _seeded();
      final logger = _logger(logThreshold: Duration.zero);
      final wrapped = _wrap(inner, logger, strictnessThreshold: Duration.zero);

      await wrapped.select(_byId(1));

      expect(
        logger.lines.any(_isSlowLine),
        isTrue,
        reason: 'A [SLOW QUERY] line must have been emitted.',
      );
      expect(
        logger.slowQueries,
        hasLength(1),
        reason: 'logger.slowQuery() must have fired exactly once.',
      );
    });

    test('[SLOW QUERY] line carries the SQL statement, bound parameters, and a '
        'reference to the threshold duration', () async {
      final inner = await _seeded();
      final logger = _logger(logThreshold: Duration.zero);
      final wrapped = _wrap(inner, logger, strictnessThreshold: Duration.zero);

      await wrapped.select(_byId(99));

      final slowLine = logger.lines.firstWhere(_isSlowLine);
      expect(slowLine, contains('rows'), reason: 'SQL statement.');
      expect(slowLine, contains('99'), reason: 'Bound parameter value.');
      expect(
        slowLine,
        contains('params:'),
        reason: 'Bound parameter list section.',
      );
      expect(
        slowLine,
        contains('threshold:'),
        reason: 'Slow line must reference the threshold duration.',
      );
      expect(
        slowLine,
        contains('threshold: 0ms'),
        reason:
            'Threshold value rendered in milliseconds — Duration.zero '
            'must round-trip to "0ms".',
      );
    });

    test(
      'InMemoryQueryLogger.slowQuery() captures entries to a queryable list',
      () async {
        final inner = await _seeded();
        final logger = _logger(logThreshold: Duration.zero);
        final wrapped = _wrap(
          inner,
          logger,
          strictnessThreshold: Duration.zero,
        );

        await wrapped.select(_byId(1));
        await wrapped.select(_byId(2));
        await wrapped.select(_byId(3));

        expect(
          logger.slowQueries,
          hasLength(3),
          reason: 'Three slow queries should produce three captures.',
        );
        // Captures retain the QueryLog payload — duration, table, etc.
        final captured = logger.slowQueries;
        expect(captured.first.table, 'rows');
        expect(captured.last.table, 'rows');
        // Captures preserve the bound-parameters list verbatim.
        expect(captured.first.parameters, contains(1));
        expect(captured.last.parameters, contains(3));
      },
    );

    test(
      'selectOne also emits the [SLOW QUERY] line and fires slowQuery()',
      () async {
        final inner = await _seeded();
        final logger = _logger(logThreshold: Duration.zero);
        final wrapped = _wrap(
          inner,
          logger,
          strictnessThreshold: Duration.zero,
        );

        await wrapped.selectOne(_byId(1));

        expect(logger.lines.any(_isSlowLine), isTrue);
        expect(logger.slowQueries, hasLength(1));
      },
    );
  });

  group('LoggingAdapter._emit — threshold coherence', () {
    test('StrictnessConfig threshold above LogConfig threshold: line is slow '
        'but the slowQuery() hook stays quiet — the two thresholds are '
        'independent by design', () async {
      // log threshold = 0ms → every line gets [SLOW QUERY] prefix.
      // strictness threshold = 999d → slowQuery() never fires.
      final inner = await _seeded();
      final logger = _logger(logThreshold: Duration.zero);
      final wrapped = _wrap(
        inner,
        logger,
        strictnessThreshold: const Duration(days: 999),
      );

      await wrapped.select(_byId(1));

      expect(logger.lines.any(_isSlowLine), isTrue);
      expect(
        logger.slowQueries,
        isEmpty,
        reason:
            'Strictness threshold is set to an unreachable value, so '
            'the notification hook must not fire even though the line '
            'format decided to use [SLOW QUERY].',
      );
    });

    test(
      'StrictnessConfig threshold below LogConfig threshold: hook fires but '
      'the line text uses the plain [QUERY] prefix — again independent',
      () async {
        // log threshold = 999d → no line gets [SLOW QUERY] prefix.
        // strictness threshold = 0ms → slowQuery() always fires.
        final inner = await _seeded();
        final logger = _logger(logThreshold: const Duration(days: 999));
        final wrapped = _wrap(
          inner,
          logger,
          strictnessThreshold: Duration.zero,
        );

        await wrapped.select(_byId(1));

        expect(logger.lines.any(_isSlowLine), isFalse);
        expect(
          logger.slowQueries,
          hasLength(1),
          reason:
              'Strictness threshold of zero means the notification path '
              'always fires regardless of the line-format threshold.',
        );
      },
    );
  });
}
