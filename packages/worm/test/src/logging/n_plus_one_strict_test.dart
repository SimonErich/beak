/// Strict-mode contract for the N+1 detection path:
/// `throwOnN1Queries` escalates the same boolean signal
/// from a `[WARNING]` log line to a thrown
/// `DangerousQueryException`. The detector itself stays a
/// pure signal emitter — every test here drives the
/// behaviour through `LoggingAdapter`, never through the
/// detector class directly.
library;

import 'package:test/test.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/exception/dangerous_query_exception.dart';
import 'package:worm/src/exception/full_table_scan_exception.dart';
import 'package:worm/src/logging/logging_adapter.dart';
import 'package:worm/src/logging/n_plus_one_detector.dart';
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
  DelegatingAdapter inner, {
  required StrictnessConfig strictness,
  required InMemoryQueryLogger logger,
  required NPlusOneDetector detector,
}) => LoggingAdapter(
  inner: inner,
  logger: logger,
  strictness: strictness,
  detector: detector,
);

NPlusOneDetector _detectorAt(int threshold) =>
    NPlusOneDetector(threshold: threshold, window: const Duration(seconds: 1));

bool _isN1Warning(String line) =>
    line.contains('[WARNING]') && line.contains('N+1');

void main() {
  group('StrictnessConfig.throwOnN1Queries', () {
    test('defaults to false', () {
      expect(const StrictnessConfig().throwOnN1Queries, isFalse);
    });

    test('flag is independent of warnOnN1Queries', () {
      const config = StrictnessConfig(throwOnN1Queries: true);
      expect(config.throwOnN1Queries, isTrue);
      expect(config.warnOnN1Queries, isFalse);
    });

    test('copyWith preserves and overrides throwOnN1Queries', () {
      const base = StrictnessConfig(throwOnN1Queries: true);
      expect(base.copyWith().throwOnN1Queries, isTrue);
      expect(base.copyWith(throwOnN1Queries: false).throwOnN1Queries, isFalse);
    });
  });

  group('LoggingAdapter._checkNPlusOne — strict mode', () {
    test(
      'throwOnN1Queries=true escalates the third lookup to '
      'DangerousQueryException once the detector threshold is crossed',
      () async {
        final inner = await _seeded();
        final logger = InMemoryQueryLogger();
        final wrapped = _wrap(
          inner,
          strictness: const StrictnessConfig(throwOnN1Queries: true),
          logger: logger,
          detector: _detectorAt(3),
        );

        await wrapped.select(_byId(1));
        await wrapped.select(_byId(1));
        await expectLater(
          wrapped.select(_byId(1)),
          throwsA(isA<DangerousQueryException>()),
        );
      },
    );

    test('DangerousQueryException.table is the table that tripped the '
        'detector', () async {
      final inner = await _seeded();
      final logger = InMemoryQueryLogger();
      final wrapped = _wrap(
        inner,
        strictness: const StrictnessConfig(throwOnN1Queries: true),
        logger: logger,
        detector: _detectorAt(3),
      );

      await wrapped.select(_byId(1));
      await wrapped.select(_byId(1));
      try {
        await wrapped.select(_byId(1));
        fail('expected DangerousQueryException');
      } on FullTableScanException catch (e) {
        // DangerousQueryException is a typedef alias for
        // FullTableScanException — catching either name works.
        expect(e.table, 'rows');
        expect(e.message, contains('N+1'));
        expect(e.message, contains('rows'));
      }
    });

    test('strict-mode throws even when warnOnN1Queries is false — the strict '
        'flag is sufficient on its own', () async {
      final inner = await _seeded();
      final logger = InMemoryQueryLogger();
      final wrapped = _wrap(
        inner,
        strictness: const StrictnessConfig(throwOnN1Queries: true),
        logger: logger,
        detector: _detectorAt(2),
      );

      await wrapped.select(_byId(1));
      await expectLater(
        wrapped.select(_byId(1)),
        throwsA(isA<DangerousQueryException>()),
      );
    });

    test('strict mode does NOT emit a [WARNING] line before throwing — the '
        'exception itself carries the diagnostic', () async {
      final inner = await _seeded();
      final logger = InMemoryQueryLogger();
      final wrapped = _wrap(
        inner,
        strictness: const StrictnessConfig(throwOnN1Queries: true),
        logger: logger,
        detector: _detectorAt(2),
      );

      await wrapped.select(_byId(1));
      await expectLater(
        wrapped.select(_byId(1)),
        throwsA(isA<DangerousQueryException>()),
      );

      final n1Warnings = logger.lines.where(_isN1Warning);
      expect(n1Warnings, isEmpty);
    });
  });

  group('LoggingAdapter._checkNPlusOne — non-strict warn mode', () {
    test(
      'warnOnN1Queries=true emits a [WARNING] line and does NOT throw',
      () async {
        final inner = await _seeded();
        final logger = InMemoryQueryLogger();
        final wrapped = _wrap(
          inner,
          strictness: const StrictnessConfig(warnOnN1Queries: true),
          logger: logger,
          detector: _detectorAt(3),
        );

        for (var i = 0; i < 3; i++) {
          await wrapped.select(_byId(1));
        }

        final n1Warnings = logger.lines.where(_isN1Warning);
        expect(n1Warnings, isNotEmpty);
      },
    );

    test(
      'warn-mode keeps issuing queries normally after the warning fires',
      () async {
        final inner = await _seeded();
        final logger = InMemoryQueryLogger();
        final wrapped = _wrap(
          inner,
          strictness: const StrictnessConfig(warnOnN1Queries: true),
          logger: logger,
          detector: _detectorAt(2),
        );

        await wrapped.select(_byId(1));
        await wrapped.select(_byId(1));
        // Fourth call still returns normally — no throw.
        final rows = await wrapped.select(_byId(1));
        expect(rows, hasLength(1));
      },
    );
  });

  group('LoggingAdapter._checkNPlusOne — flags both off', () {
    test('detector is never armed, no warning, no throw', () async {
      final inner = await _seeded();
      final logger = InMemoryQueryLogger();
      final wrapped = _wrap(
        inner,
        strictness: const StrictnessConfig(),
        logger: logger,
        detector: _detectorAt(2),
      );

      for (var i = 0; i < 5; i++) {
        await wrapped.select(_byId(1));
      }

      expect(logger.lines.where(_isN1Warning), isEmpty);
    });
  });

  group('NPlusOneDetector remains a pure signal emitter', () {
    test('shouldWarn returns a boolean even when strict mode would have '
        'thrown via LoggingAdapter', () {
      final detector = _detectorAt(2)
        ..recordQuery('rows')
        ..recordQuery('rows');

      // The detector class itself never throws — strictness lives
      // exclusively in [LoggingAdapter]. Calling shouldWarn must
      // therefore return cleanly.
      expect(detector.shouldWarn('rows'), isTrue);
    });
  });
}
