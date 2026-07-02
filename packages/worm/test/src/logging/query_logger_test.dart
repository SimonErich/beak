import 'package:test/test.dart';
import 'package:worm/src/logging/query_log.dart';
import 'package:worm/src/logging/query_logger.dart';

const _timestampPrefix = r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]';

QueryLog _entry({
  Duration duration = const Duration(microseconds: 500),
  List<Object?> parameters = const <Object?>['alice', 42],
}) => QueryLog(
  statement: 'SELECT * FROM users WHERE id = ?',
  parameters: parameters,
  duration: duration,
  rowCount: 1,
  adapter: 'InMemory',
  table: 'users',
);

String _emit(
  StringSink sink,
  void Function(ConsoleQueryLogger logger) action, {
  LogConfig config = const LogConfig(),
}) {
  final logger = ConsoleQueryLogger(config: config, sink: sink);
  action(logger);
  return sink.toString();
}

void main() {
  group('ConsoleQueryLogger format', () {
    test('emits [QUERY] line when duration is below threshold', () {
      final buffer = StringBuffer();
      _emit(
        buffer,
        (l) => l.log(_entry(duration: const Duration(milliseconds: 5))),
        config: const LogConfig(
          slowQueryThreshold: Duration(milliseconds: 200),
        ),
      );

      final line = buffer.toString().trimRight();
      expect(line, matches('$_timestampPrefix \\[QUERY\\] '));
      expect(line, contains('SELECT * FROM users'));
      expect(line, contains('params: [alice, 42]'));
      expect(line, isNot(contains('threshold')));
    });

    test('emits [SLOW QUERY] line with threshold annotation when slow', () {
      final buffer = StringBuffer();
      _emit(
        buffer,
        (l) => l.log(_entry(duration: const Duration(milliseconds: 25))),
        config: const LogConfig(slowQueryThreshold: Duration(milliseconds: 10)),
      );

      final line = buffer.toString().trimRight();
      expect(line, matches('$_timestampPrefix \\[SLOW QUERY\\] '));
      expect(line, contains('(threshold: 10ms)'));
    });

    test('redacts params when logQueryParameters is false', () {
      final buffer = StringBuffer();
      _emit(
        buffer,
        (l) => l.log(_entry()),
        config: const LogConfig(logQueryParameters: false),
      );

      final line = buffer.toString();
      expect(line, contains('params: [REDACTED]'));
      expect(line, isNot(contains('alice')));
      // Don't assert on the integer parameter literal '42' — the
      // timestamp prefix coincidentally contains digits that can
      // include '42' (e.g. minutes ':42:'), making the check flaky.
      // The [REDACTED] sentinel + missing 'alice' is sufficient.
    });

    test('emits [WARNING] line via logWarning', () {
      final buffer = StringBuffer();
      _emit(buffer, (l) => l.logWarning('something looks off'));

      expect(
        buffer.toString().trimRight(),
        matches('$_timestampPrefix \\[WARNING\\] something looks off'),
      );
    });

    test('emits [ERROR] line via logError, including bound error', () {
      final buffer = StringBuffer();
      _emit(
        buffer,
        (l) => l.logError('failed to connect', const FormatException('bad')),
      );

      final line = buffer.toString().trimRight();
      expect(line, matches('$_timestampPrefix \\[ERROR\\] failed to connect'));
      expect(line, contains('FormatException'));
    });

    test('is a hard no-op when LogConfig.enabled is false', () {
      final buffer = StringBuffer();
      _emit(
        buffer,
        (l) => l
          ..log(_entry(duration: const Duration(milliseconds: 1)))
          ..log(_entry(duration: const Duration(milliseconds: 999)))
          ..logWarning('hidden')
          ..logError('also hidden')
          ..warning(code: 'n+1', message: 'silent'),
        config: const LogConfig(enabled: false),
      );

      expect(buffer.toString(), isEmpty);
    });
  });

  group('InMemoryQueryLogger', () {
    test('captures entries and formatted lines in emission order', () {
      final logger =
          InMemoryQueryLogger(
              config: const LogConfig(
                slowQueryThreshold: Duration(milliseconds: 10),
              ),
            )
            ..log(_entry(duration: const Duration(milliseconds: 1)))
            ..logWarning('msg')
            ..logError('boom');

      expect(logger.entries, hasLength(1));
      expect(logger.lines, hasLength(3));
      expect(logger.lines[0], matches('$_timestampPrefix \\[QUERY\\] '));
      expect(logger.lines[1], matches('$_timestampPrefix \\[WARNING\\] msg'));
      expect(logger.lines[2], matches('$_timestampPrefix \\[ERROR\\] boom'));
    });

    test('records nothing when disabled', () {
      final logger =
          InMemoryQueryLogger(config: const LogConfig(enabled: false))
            ..log(_entry())
            ..logWarning('msg')
            ..logError('boom')
            ..warning(code: 'n+1', message: 'silent')
            ..slowQuery(_entry(), const Duration(milliseconds: 1));

      expect(logger.entries, isEmpty);
      expect(logger.lines, isEmpty);
      expect(logger.warnings, isEmpty);
      expect(logger.slowQueries, isEmpty);
    });
  });

  group('LogConfig', () {
    test('defaults match the documented spec', () {
      const config = LogConfig();
      expect(config.enabled, isTrue);
      expect(config.level, LogLevel.debug);
      expect(config.file, isNull);
      expect(config.slowQueryThreshold, const Duration(milliseconds: 200));
      expect(config.logQueryParameters, isTrue);
      expect(config.formatQueries, isTrue);
    });

    test('copyWith overrides selected fields only', () {
      const original = LogConfig();
      final copy = original.copyWith(
        enabled: false,
        slowQueryThreshold: const Duration(milliseconds: 50),
      );
      expect(copy.enabled, isFalse);
      expect(copy.slowQueryThreshold, const Duration(milliseconds: 50));
      expect(copy.logQueryParameters, isTrue);
      expect(copy.level, LogLevel.debug);
    });
  });

  group('LogLevel', () {
    test('severity is ordered debug < info < warning < error', () {
      expect(LogLevel.debug.severity, lessThan(LogLevel.info.severity));
      expect(LogLevel.info.severity, lessThan(LogLevel.warning.severity));
      expect(LogLevel.warning.severity, lessThan(LogLevel.error.severity));
    });
  });
}
