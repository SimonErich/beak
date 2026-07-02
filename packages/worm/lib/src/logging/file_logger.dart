/// File-backed query logger.
library;

import 'dart:io';

import 'query_logger.dart';

/// Persists query logs to a file on disk.
///
/// Opens the file in append mode — pre-existing content is preserved
/// and new lines are written at the tail. Each line is one event;
/// designed for production tail-friendly logs.
final class FileLogger extends QueryLogger {
  /// Creates a [FileLogger] that appends to [path].
  FileLogger(this.path, {this.config = const LogConfig()})
    : _sink = File(path).openWrite(mode: FileMode.append);

  /// Absolute or relative path the logger writes to.
  final String path;

  @override
  final LogConfig config;

  final IOSink _sink;

  @override
  void emitLine(String line) => _sink.writeln(line);

  /// Flush pending bytes and release the file handle.
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
