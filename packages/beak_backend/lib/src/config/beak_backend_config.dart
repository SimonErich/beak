import 'dart:io';

import 'package:beak_core/beak_core.dart';

/// Whether [databaseUrl] names a SQLite database.
///
/// `sqlite:beak.db`, `sqlite:///tmp/beak.db` and `sqlite::memory:` all count;
/// the last opens an in-memory database that vanishes with the process, which
/// is what a demo or a throwaway container wants.
bool isSqliteUrl(Uri databaseUrl) =>
    databaseUrl.scheme == 'sqlite' || databaseUrl.scheme == 'file';

/// The file path a SQLite [databaseUrl] points at, or `null` for in-memory.
///
/// `sqlite:beak.db` names a file beside the process. A URL whose path is
/// `:memory:`, or which has no path at all, is in-memory.
String? sqliteFilePathOf(Uri databaseUrl) {
  final String path = databaseUrl.path.isNotEmpty
      ? databaseUrl.path
      : databaseUrl.toString().substring('${databaseUrl.scheme}:'.length);
  final String trimmed = Uri.decodeFull(
    path.startsWith('//') ? path.substring(2) : path,
  );
  return trimmed.isEmpty || trimmed == ':memory:' ? null : trimmed;
}

/// [raw] read as a `DATABASE_URL`, or `null` when it is not a URL.
///
/// [Uri.parse] removes the dot segments of a path, so `sqlite:../legacy.db`
/// would arrive as `sqlite:legacy.db` and `sqlite:./data/../x.db` as
/// `sqlite:/x.db`: a different file than the one written, silently created
/// empty. It also turns `file:data/beak.db` into the absolute
/// `file:///data/beak.db`. A relative file path is therefore read from the
/// text itself: kept as written (bar `.` segments) when it climbs nowhere,
/// resolved against the working directory when it has a `..` segment.
Uri? _parseDatabaseUrl(String raw) {
  final String? path = RegExp(
    r'^(?:sqlite|file):(?!//)(.+)$',
  ).firstMatch(raw)?.group(1);
  if (path == null || path.contains(':memory:')) return Uri.tryParse(raw);
  final String decoded = Uri.decodeFull(path);
  final List<String> segments = decoded.split('/');
  final bool absolute = decoded.startsWith('/');
  final String file = absolute || !segments.contains('..')
      ? (absolute ? decoded : segments.where((s) => s != '.').join('/'))
      : _resolvedAgainstWorkingDirectory(segments);
  // `%` is escaped first so that decoding gives the file name back.
  return Uri(scheme: 'sqlite', path: file.replaceAll('%', '%25'));
}

/// The absolute path of the relative [segments], dot segments resolved
/// against the working directory. A path cannot climb above the root.
String _resolvedAgainstWorkingDirectory(List<String> segments) {
  final List<String> resolved = Directory.current.absolute.path
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  for (final String segment in segments) {
    if (segment == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
    } else if (segment.isNotEmpty && segment != '.') {
      resolved.add(segment);
    }
  }
  return '/${resolved.join('/')}';
}

/// Typed, validated runtime configuration for a Beak backend.
///
/// Built once at startup — usually with [fromEnv] over `BeakEnv.resolve()` —
/// and passed to the server; nothing else reads environment variables. Its
/// [toString] redacts the [databaseUrl] credentials so it is safe to log.
///
/// ```dart
/// final config = BeakBackendConfig.fromEnv(
///   environment: BeakEnv.resolve(), // .env overlaid by the real environment
/// );
/// final server = BeakServer(
///   config: config,
///   registry: registry,
///   dataSource: dataSource,
/// );
/// ```
final class BeakBackendConfig {
  /// Creates a configuration from already-validated parts.
  // --8<-- [start:BeakBackendConfig]
  const BeakBackendConfig({
    required this.databaseUrl,
    this.port = defaultPort,
    this.host = defaultHost,
  });
  // --8<-- [end:BeakBackendConfig]

  /// The database a project gets when it names none.
  ///
  /// A file beside the project, so the very first `beak dev` needs no Docker,
  /// no credentials and no `.env`. Requiring a database to see anything at all
  /// loses more first-time users than any other step.
  static const String defaultDatabaseUrl = 'sqlite:beak.db';

  /// Reads and validates the configuration from [environment] (defaults to
  /// [Platform.environment]).
  ///
  /// `DATABASE_URL` defaults to [defaultDatabaseUrl]; `PORT` (1–65535, default
  /// [defaultPort]) and `HOST` (non-empty, default [defaultHost]) are
  /// optional. Throws a [BeakConfigurationException] on anything malformed.
  factory BeakBackendConfig.fromEnv({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final String rawDatabaseUrl = env['DATABASE_URL'] ?? defaultDatabaseUrl;
    final Uri? databaseUrl = _parseDatabaseUrl(rawDatabaseUrl);
    if (databaseUrl == null || databaseUrl.scheme.isEmpty) {
      throw BeakConfigurationException(
        'DATABASE_URL must be an absolute URL, got '
        '"${_withoutCredentials(rawDatabaseUrl)}".',
      );
    }
    // A file-backed sqlite URL has a path and no host; every server database
    // has a host, and one without is a typo worth naming.
    if (!isSqliteUrl(databaseUrl) && databaseUrl.host.isEmpty) {
      throw BeakConfigurationException(
        'DATABASE_URL must be an absolute URL with a host, '
        'got "${_withoutCredentials(rawDatabaseUrl)}".',
      );
    }
    final rawPort = env['PORT'];
    final int port = rawPort == null ? defaultPort : _parsePort(rawPort);
    final host = env['HOST'] ?? defaultHost;
    if (host.isEmpty) {
      throw const BeakConfigurationException('HOST must not be empty.');
    }
    return BeakBackendConfig(databaseUrl: databaseUrl, port: port, host: host);
  }

  /// The port the server listens on when `PORT` is unset.
  static const int defaultPort = 8080;

  /// The interface the server binds when `HOST` is unset.
  static const String defaultHost = '0.0.0.0';

  /// The database connection URL (credentials included — see [toString]).
  final Uri databaseUrl;

  /// The port the HTTP server listens on.
  final int port;

  /// The interface the HTTP server binds.
  final String host;

  /// [rawUrl] with everything between `://` and the last `@` of its
  /// authority replaced by `***`, so a message can quote a URL it rejected
  /// without printing the password in it.
  static String _withoutCredentials(String rawUrl) {
    const schemeEnd = '://';
    final int start = rawUrl.indexOf(schemeEnd);
    if (start < 0) return rawUrl;
    final int credentialsStart = start + schemeEnd.length;
    final int authorityEnd = rawUrl.indexOf('/', credentialsStart);
    final String authority = authorityEnd < 0
        ? rawUrl.substring(credentialsStart)
        : rawUrl.substring(credentialsStart, authorityEnd);
    final int at = authority.lastIndexOf('@');
    if (at < 0) return rawUrl;
    return '${rawUrl.substring(0, credentialsStart)}***'
        '${rawUrl.substring(credentialsStart + at)}';
  }

  static int _parsePort(String raw) {
    final int? port = int.tryParse(raw);
    if (port == null || port < 1 || port > 65535) {
      throw BeakConfigurationException(
        'PORT must be an integer between 1 and 65535, got "$raw".',
      );
    }
    return port;
  }

  @override
  String toString() =>
      'BeakBackendConfig(databaseUrl: ${databaseUrl.replace(userInfo: '')}, '
      'port: $port, host: $host)';
}
