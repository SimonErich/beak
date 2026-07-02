/// Sink for executed query records.
library;

import 'dart:io';

import 'file_logger.dart';
import 'query_log.dart';

/// Log severity levels.
///
/// Ordered from least to most severe. [severity] returns an `int`
/// allowing direct comparison: `LogLevel.warning.severity > debug.severity`.
enum LogLevel {
  /// Diagnostic detail; everything is logged.
  debug,

  /// Informational events.
  info,

  /// Recoverable problems.
  warning,

  /// Errors and failures.
  error;

  /// Numeric severity. Higher means more severe.
  int get severity => index;
}

/// Runtime logging configuration.
///
/// Drives the master enable switch, slow-query detection threshold,
/// parameter redaction, and the optional file sink. Defaults:
/// logging enabled, debug level, no file, 200ms slow threshold,
/// parameters logged, SQL pretty-printed.
final class LogConfig {
  /// Creates a [LogConfig] with spec-default field values.
  const LogConfig({
    this.enabled = true,
    this.level = LogLevel.debug,
    this.file,
    this.slowQueryThreshold = const Duration(milliseconds: 200),
    this.logQueryParameters = true,
    this.formatQueries = true,
  });

  /// Master enable switch. When `false` every log method is a no-op
  /// and no output is produced.
  final bool enabled;

  /// Minimum severity that should be emitted. Reserved for future
  /// filter use; the current logger does not yet drop sub-threshold
  /// entries.
  final LogLevel level;

  /// Optional output file path.
  ///
  /// Consumed by [QueryLogger.fromConfig]: when non-null the factory
  /// returns a `FileLogger` that appends to this path; when null it
  /// returns a [ConsoleQueryLogger] writing to stdout. Directly
  /// constructed loggers ignore this field — wire it via the factory
  /// or construct `FileLogger` yourself.
  final String? file;

  /// Queries with [QueryLog.duration] at or above this threshold are
  /// formatted with the `[SLOW QUERY]` prefix instead of `[QUERY]`.
  final Duration slowQueryThreshold;

  /// Whether bound parameter values are included in log output.
  /// When `false`, the params section reads `params: [REDACTED]`.
  final bool logQueryParameters;

  /// Whether SQL statements should be pretty-printed. Reserved for
  /// future formatter work.
  final bool formatQueries;

  /// Returns a copy of this config with selected fields overridden.
  LogConfig copyWith({
    bool? enabled,
    LogLevel? level,
    String? file,
    Duration? slowQueryThreshold,
    bool? logQueryParameters,
    bool? formatQueries,
  }) => LogConfig(
    enabled: enabled ?? this.enabled,
    level: level ?? this.level,
    file: file ?? this.file,
    slowQueryThreshold: slowQueryThreshold ?? this.slowQueryThreshold,
    logQueryParameters: logQueryParameters ?? this.logQueryParameters,
    formatQueries: formatQueries ?? this.formatQueries,
  );
}

/// Receiver for [QueryLog] records and free-form diagnostic messages.
///
/// Implementations expose a single primitive — [emitLine] — and
/// inherit the formatted [log], [logWarning], [logError], and
/// [warning] entry points. The `config.enabled` flag is enforced
/// uniformly here; subclasses only see line writes that should
/// actually appear in their sink.
abstract class QueryLogger {
  /// Const constructor for subclasses.
  const QueryLogger();

  /// Returns the logger that satisfies [config]:
  ///
  /// * `config.file == null` → a [ConsoleQueryLogger] writing to
  ///   stdout.
  /// * `config.file != null` → a `FileLogger` appending to that
  ///   path.
  factory QueryLogger.fromConfig(LogConfig config) {
    final file = config.file;
    if (file != null) return FileLogger(file, config: config);
    return ConsoleQueryLogger(config: config);
  }

  /// Active configuration for this logger.
  LogConfig get config;

  /// Record one executed query. Emits either a `[QUERY]` line or a
  /// `[SLOW QUERY]` line depending on whether [QueryLog.duration] is
  /// at or above [LogConfig.slowQueryThreshold].
  void log(QueryLog entry) {
    if (!config.enabled) return;
    onQueryRecorded(entry);
    emitLine(formatQueryLine(entry, config));
  }

  /// Notification that an entry was flagged as slow by an external
  /// observer. The default implementation is a no-op because [log]
  /// already emits the `[SLOW QUERY]` line based on
  /// [LogConfig.slowQueryThreshold]. Capture loggers may override
  /// to maintain a separate slow-query list.
  void slowQuery(QueryLog entry, Duration threshold) {}

  /// Record a structured strictness warning.
  ///
  /// [code] is a stable identifier (`n+1`, `missing-index`, …) and
  /// [message] is the human-readable explanation.
  void warning({
    required String code,
    required String message,
    QueryLog? entry,
  }) {
    if (!config.enabled) return;
    onStructuredWarning(code, message, entry);
    emitLine(formatStructuredWarning(code, message, entry));
  }

  /// Emit a `[WARNING]` line carrying [message].
  void logWarning(String message) {
    if (!config.enabled) return;
    emitLine(formatWarningLine(message));
  }

  /// Emit an `[ERROR]` line carrying [message] and the optional
  /// associated [error].
  void logError(String message, [Object? error]) {
    if (!config.enabled) return;
    emitLine(formatErrorLine(message, error));
  }

  /// Subclass hook called before [emitLine] for [log]. Default
  /// no-op; capture loggers override to record [entry].
  void onQueryRecorded(QueryLog entry) {}

  /// Subclass hook called before [emitLine] for [warning]. Default
  /// no-op; capture loggers override to retain the structured warning.
  void onStructuredWarning(String code, String message, QueryLog? entry) {}

  /// Writes one formatted [line] to the logger's underlying sink.
  /// Called only when `config.enabled` is `true`.
  void emitLine(String line);
}

/// Logger that writes spec-formatted lines to a [StringSink].
///
/// Defaults to [stdout] when no sink is supplied.
final class ConsoleQueryLogger extends QueryLogger {
  /// Creates a [ConsoleQueryLogger] writing to [sink] (defaults to
  /// stdout).
  ConsoleQueryLogger({this.config = const LogConfig(), StringSink? sink})
    : _sink = sink ?? stdout;

  @override
  final LogConfig config;

  final StringSink _sink;

  @override
  void emitLine(String line) => _sink.writeln(line);
}

/// Logger that retains every event in memory.
///
/// Intended for tests and short-lived diagnostics. Not safe for
/// long-running production processes — entries accumulate
/// indefinitely.
final class InMemoryQueryLogger extends QueryLogger {
  /// Creates an empty in-memory logger.
  InMemoryQueryLogger({this.config = const LogConfig()});

  @override
  final LogConfig config;

  final List<QueryLog> _entries = <QueryLog>[];
  final List<QueryLog> _slow = <QueryLog>[];
  final List<LoggedWarning> _warnings = <LoggedWarning>[];
  final List<String> _lines = <String>[];

  /// Every recorded query entry (insertion order).
  List<QueryLog> get entries => List<QueryLog>.unmodifiable(_entries);

  /// Every entry flagged as slow (insertion order).
  List<QueryLog> get slowQueries => List<QueryLog>.unmodifiable(_slow);

  /// Every captured structured warning (insertion order).
  List<LoggedWarning> get warnings =>
      List<LoggedWarning>.unmodifiable(_warnings);

  /// Every formatted output line in emission order. Useful for
  /// asserting against the spec-compliant format without touching
  /// stdout or the filesystem.
  List<String> get lines => List<String>.unmodifiable(_lines);

  @override
  void emitLine(String line) => _lines.add(line);

  @override
  void onQueryRecorded(QueryLog entry) => _entries.add(entry);

  @override
  void onStructuredWarning(String code, String message, QueryLog? entry) {
    _warnings.add(LoggedWarning(code: code, message: message, entry: entry));
  }

  @override
  void slowQuery(QueryLog entry, Duration threshold) {
    if (!config.enabled) return;
    _slow.add(entry);
  }

  /// Clear all captured state.
  void clear() {
    _entries.clear();
    _slow.clear();
    _warnings.clear();
    _lines.clear();
  }
}

/// One structured warning recorded by [InMemoryQueryLogger].
final class LoggedWarning {
  /// Creates a [LoggedWarning].
  const LoggedWarning({required this.code, required this.message, this.entry});

  /// Stable warning identifier (`n+1`, `missing-index`, `slow`).
  final String code;

  /// Human-readable description.
  final String message;

  /// Query entry the warning was raised against (if any).
  final QueryLog? entry;
}

/// Formats one [QueryLog] entry into a spec-compliant line.
///
/// Returns either `[TIMESTAMP] [QUERY] …` or
/// `[TIMESTAMP] [SLOW QUERY] … (threshold: Nms)` depending on the
/// entry's duration relative to [LogConfig.slowQueryThreshold].
/// When [LogConfig.logQueryParameters] is `false` the params
/// section reads `params: [REDACTED]`.
String formatQueryLine(QueryLog entry, LogConfig config) {
  final isSlow = entry.duration >= config.slowQueryThreshold;
  final prefix = isSlow ? '[SLOW QUERY]' : '[QUERY]';
  final body = _formatBody(entry, config);
  if (!isSlow) return '${formatTimestamp()} $prefix $body';
  final thresholdMs = config.slowQueryThreshold.inMilliseconds;
  return '${formatTimestamp()} $prefix $body (threshold: ${thresholdMs}ms)';
}

/// Formats a `[WARNING]` line carrying a free-form message.
String formatWarningLine(String message) =>
    '${formatTimestamp()} [WARNING] $message';

/// Formats an `[ERROR]` line carrying a free-form message and the
/// optional associated error.
String formatErrorLine(String message, [Object? error]) {
  final tail = error == null ? '' : ' :: $error';
  return '${formatTimestamp()} [ERROR] $message$tail';
}

/// Formats a structured warning line (with stable [code]) emitted via
/// [QueryLogger.warning].
String formatStructuredWarning(String code, String message, QueryLog? entry) {
  final tail = entry == null ? '' : ' :: $entry';
  return '${formatTimestamp()} [WARNING] [$code] $message$tail';
}

String _formatBody(QueryLog entry, LogConfig config) {
  final params = config.logQueryParameters
      ? '${entry.parameters}'
      : '[REDACTED]';
  final ms = entry.duration.inMicroseconds / 1000;
  return '${entry.statement} | params: $params | ${_fmtMs(ms)}ms';
}

String _fmtMs(double ms) {
  if (ms == ms.roundToDouble()) return ms.toStringAsFixed(0);
  return ms.toStringAsFixed(1);
}

/// Returns the current wall-clock timestamp in
/// `[yyyy-MM-dd HH:mm:ss.SSS]` UTC form.
String formatTimestamp() => _formatTimestamp(DateTime.now().toUtc());

String _formatTimestamp(DateTime now) {
  final y = now.year.toString().padLeft(4, '0');
  final mo = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final h = now.hour.toString().padLeft(2, '0');
  final mi = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  final ms = now.millisecond.toString().padLeft(3, '0');
  return '[$y-$mo-$d $h:$mi:$s.$ms]';
}
