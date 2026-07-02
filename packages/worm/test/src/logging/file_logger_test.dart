import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/src/logging/file_logger.dart';
import 'package:worm/src/logging/query_log.dart';
import 'package:worm/src/logging/query_logger.dart';

const _timestampPrefix = r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]';

void main() {
  group('FileLogger', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('worm_file_logger_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('writes [QUERY] / [SLOW QUERY] / [WARNING] / [ERROR] lines', () async {
      final path = '${tempDir.path}/queries.log';
      final logger = FileLogger(
        path,
        config: const LogConfig(slowQueryThreshold: Duration(milliseconds: 10)),
      );
      const fast = QueryLog(
        statement: 'SELECT 1',
        parameters: <Object?>[1],
        duration: Duration(microseconds: 50),
        rowCount: 1,
        adapter: 'InMemory',
      );
      const slow = QueryLog(
        statement: 'SELECT 2',
        parameters: <Object?>[2],
        duration: Duration(milliseconds: 25),
        rowCount: 1,
        adapter: 'InMemory',
      );
      logger
        ..log(fast)
        ..log(slow)
        ..warning(code: 'n+1', message: 'detected')
        ..logWarning('plain warning')
        ..logError('boom');
      await logger.close();

      final lines = File(path).readAsLinesSync();
      expect(lines, hasLength(5));
      expect(lines[0], matches('$_timestampPrefix \\[QUERY\\] '));
      expect(lines[1], matches('$_timestampPrefix \\[SLOW QUERY\\] '));
      expect(lines[1], contains('(threshold: 10ms)'));
      expect(lines[2], matches('$_timestampPrefix \\[WARNING\\] \\[n\\+1\\] '));
      expect(
        lines[3],
        matches('$_timestampPrefix \\[WARNING\\] plain warning'),
      );
      expect(lines[4], matches('$_timestampPrefix \\[ERROR\\] boom'));
    });

    test('appends to existing content rather than overwriting', () async {
      final path = '${tempDir.path}/queries.log';
      File(path).writeAsStringSync('PREEXISTING\n');

      final logger = FileLogger(path);
      const entry = QueryLog(
        statement: 'SELECT 1',
        parameters: <Object?>[],
        duration: Duration(microseconds: 50),
        rowCount: 1,
        adapter: 'InMemory',
      );
      logger.log(entry);
      await logger.close();

      final lines = File(path).readAsLinesSync();
      expect(lines.first, 'PREEXISTING');
      expect(lines, hasLength(2));
      expect(lines.last, matches('$_timestampPrefix \\[QUERY\\] SELECT 1'));
    });

    test('writes nothing when LogConfig.enabled is false', () async {
      final path = '${tempDir.path}/queries.log';
      final logger = FileLogger(path, config: const LogConfig(enabled: false));
      const entry = QueryLog(
        statement: 'SELECT 1',
        parameters: <Object?>[1],
        duration: Duration(microseconds: 50),
        rowCount: 1,
        adapter: 'InMemory',
      );
      logger
        ..log(entry)
        ..logWarning('hidden')
        ..logError('also hidden');
      await logger.close();

      expect(File(path).readAsBytesSync(), isEmpty);
    });
  });

  group('QueryLogger.fromConfig', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('worm_logger_factory_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('returns a ConsoleQueryLogger when config.file is null', () {
      final logger = QueryLogger.fromConfig(const LogConfig());
      expect(logger, isA<ConsoleQueryLogger>());
    });

    test('returns a FileLogger appending to config.file when set', () async {
      final path = '${tempDir.path}/wired.log';
      final logger = QueryLogger.fromConfig(LogConfig(file: path));
      expect(logger, isA<FileLogger>());

      const entry = QueryLog(
        statement: 'SELECT 1',
        parameters: <Object?>[],
        duration: Duration(microseconds: 50),
        rowCount: 1,
        adapter: 'InMemory',
      );
      logger.log(entry);
      if (logger case final FileLogger file) {
        await file.close();
      }

      final lines = File(path).readAsLinesSync();
      expect(lines, hasLength(1));
      expect(lines.single, matches('$_timestampPrefix \\[QUERY\\] SELECT 1'));
    });
  });
}
