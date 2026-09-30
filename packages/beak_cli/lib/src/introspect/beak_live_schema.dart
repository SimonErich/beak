import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

import '../project/beak_dotenv.dart';
import 'beak_schema_introspection.dart';
import 'postgres_introspector.dart';
import 'sqlite_introspector.dart';

/// Reads the schema a database really has.
///
/// The seam `beak doctor` and the migration generator compare models against.
/// Taking the tables rather than a connection is deliberate: what they need is
/// the schema, and a test that has to fake `information_schema` rows to say
/// "the table has these columns" is a test about SQL, not about drift.
typedef BeakLiveSchemaReader =
    Future<List<IntrospectedTable>> Function(Uri url, {String schema});

/// Whether [url] names a SQLite database, whether or not it names a file.
///
/// Separate from [beakSqliteFileOf], which answers "which file": an
/// in-memory URL is SQLite and has no file, and conflating the two sent
/// `sqlite::memory:` down the Postgres branch to be probed on port 0.
bool beakIsSqliteUrl(Uri url) => url.scheme == 'sqlite' || url.scheme == 'file';

/// Whether Beak can read the schema of the database [url] names.
bool beakCanReadSchema(Uri url) =>
    _isPostgresUrl(url) || beakSqliteFileOf(url) != null;

/// The file a SQLite [url] names, or `null` when it names something else.
///
/// `sqlite::memory:` returns null on purpose: an in-memory database belongs to
/// the process that opened it, so there is nothing for another process to
/// read.
String? beakSqliteFileOf(Uri url) {
  if (!beakIsSqliteUrl(url)) {
    return null;
  }
  // `Uri.parse` percent-encodes what a file path may legitimately contain, a
  // space above all, so decode rather than hand the encoded form to the
  // filesystem. `sqlite:beak.db` has no authority and so an empty `path`,
  // which is why the whole string is the fallback.
  final String path = url.path.isEmpty
      ? Uri.decodeFull(url.toString())
      : Uri.decodeFull(url.path);
  final String file = path.startsWith('sqlite:')
      ? path.substring('sqlite:'.length)
      : path;
  return file.isEmpty || file.contains(':memory:') ? null : file;
}

/// Whether [file] already names a location rather than one relative to a
/// project.
///
/// A leading slash covers POSIX; a drive letter covers Windows, where
/// `sqlite:C:\data\beak.db` parses to the path `C:/data/beak.db` and
/// joining it to the project root would name a directory nobody has.
bool beakIsAbsolutePath(String file) =>
    file.startsWith('/') || RegExp(r'^[A-Za-z]:[/\\]').hasMatch(file);

/// Reads every table of the database [url] names.
///
/// Dispatches on the scheme so one caller covers both the zero-setup SQLite
/// default and a Postgres server. [schema] names the Postgres schema and is
/// ignored for SQLite, which has one. Throws when the database cannot be read,
/// which the caller reports rather than treating as an empty schema: a
/// connection failure is not the same fact as a database with no tables.
Future<List<IntrospectedTable>> beakReadLiveSchema(
  Uri url, {
  String schema = 'public',
}) async {
  if (beakIsSqliteUrl(url) && beakSqliteFileOf(url) == null) {
    // Without this, an in-memory URL fell through to the Postgres branch
    // below and surfaced as a socket error on port 0. Callers gate on
    // [beakCanReadSchema]; throwing here keeps a caller that forgot from
    // producing that riddle.
    throw ArgumentError.value(
      '$url',
      'url',
      'an in-memory SQLite database belongs to the process that opened it, '
          'so there is no schema on disk to read',
    );
  }
  if (beakSqliteFileOf(url) case final String file) {
    final adapter = SqliteAdapter.open(file);
    await adapter.connect();
    try {
      return await SqliteIntrospector(
        (sql) => adapter.rawQuery(sql, const []),
      ).read();
    } finally {
      await adapter.disconnect();
    }
  }
  final (BeakSqlReader query, Future<void> Function() close) =
      await _openPostgres(url);
  try {
    return await PostgresIntrospector(query, schema: schema).read();
  } finally {
    await close();
  }
}

/// Whether the SQLite file [url] names exists yet, relative to [root].
///
/// Before the first `beak migrate` there is no file, and no schema to be out
/// of step with.
bool beakSqliteFileExists(Uri url, Directory root) {
  // Through the same resolution the reader uses, so the two cannot disagree
  // about which file they mean. They used to: this joined strings while the
  // reader round-tripped through a Uri, and a project directory containing a
  // percent-escape passed the existence check here and failed to open there.
  final String? file = beakSqliteFileOf(beakResolvedDatabaseUrl(url, root));
  return file != null && File(file).existsSync();
}

/// The database a project uses when it names none.
///
/// The same default `BeakBackendConfig` applies, so `doctor` checks the file
/// the server would really open rather than reporting that nothing is
/// configured.
const String defaultSqliteUrl = 'sqlite:beak.db';

/// [text] read as a database URL, or `null` when it is not one.
///
/// [Uri.parse] removes the dot segments of a path, so `sqlite:../legacy.db`
/// arrives as `sqlite:legacy.db` and `sqlite:./a/../b.db` as `sqlite:/b.db`:
/// the file is somewhere else than the URL says. A relative SQLite path with a
/// dot segment in it is therefore resolved against [root] here, before it
/// becomes a [Uri], and comes out absolute, which has none left to lose.
Uri? beakParseDatabaseUrl(String text, Directory root) {
  final String trimmed = text.trim();
  final RegExpMatch? sqlite = RegExp(
    r'^(?:sqlite|file):(?!//)(.*)$',
  ).firstMatch(trimmed);
  final String? path = sqlite?.group(1);
  if (path != null &&
      path.isNotEmpty &&
      !path.contains(':memory:') &&
      !beakIsAbsolutePath(path) &&
      path.split('/').any((segment) => segment == '.' || segment == '..')) {
    final String resolved = p.normalize(
      p.join(root.absolute.path, Uri.decodeFull(path)),
    );
    // As in [beakResolvedDatabaseUrl]: `%` is escaped so that decoding gives
    // the path back.
    return Uri(scheme: 'sqlite', path: resolved.replaceAll('%', '%25'));
  }
  return Uri.tryParse(trimmed);
}

/// The `DATABASE_URL` the project's server would use, when one is set.
///
/// From the process environment, or failing that the project's `.env`: the
/// order the server reads them in. `null` means neither sets it, and the
/// default SQLite file applies.
Uri? beakDatabaseUrlOf(
  Directory root, {
  required Map<String, String> processEnvironment,
}) {
  final String? value = BeakDotenv.resolve(
    root,
    processEnvironment: processEnvironment,
  )['DATABASE_URL'];
  return value == null || value.isEmpty
      ? null
      : beakParseDatabaseUrl(value, root);
}

/// [url] with a relative SQLite path made absolute against [root].
///
/// `sqlite:beak.db` names a file beside the project, and `doctor` runs from
/// wherever the user happens to be.
Uri beakResolvedDatabaseUrl(Uri url, Directory root) {
  final String? file = beakSqliteFileOf(url);
  if (file == null || beakIsAbsolutePath(file)) {
    return url;
  }
  // The filesystem path has to survive the trip through a Uri unchanged.
  // `Uri(path:)` percent-encodes what it must (a space becomes %20) but
  // passes an existing %XX through as an already-valid escape, so a
  // directory literally named `feature%2Ffoo` would decode into a different
  // path on the way out. Escaping the one ambiguous character first makes
  // [Uri.decodeFull] the exact inverse.
  final String escaped = '${root.path}/$file'.replaceAll('%', '%25');
  return Uri(scheme: 'sqlite', path: escaped);
}

/// Whether [url] names a Postgres server.
bool _isPostgresUrl(Uri url) =>
    const {'postgres', 'postgresql'}.contains(url.scheme);

/// Connects to the Postgres server [url] names, returning a reader over the
/// connection and the function that closes it.
Future<(BeakSqlReader, Future<void> Function())> _openPostgres(Uri url) async {
  final String? userInfo = url.userInfo.isEmpty ? null : url.userInfo;
  final int separator = userInfo?.indexOf(':') ?? -1;
  final adapter = PostgresAdapter(
    pool: PostgresConnectionPool.fromConfig(
      ConnectionConfig(
        driver: 'postgres',
        host: url.host,
        port: url.hasPort ? url.port : 5432,
        database: url.pathSegments.isEmpty
            ? 'postgres'
            : url.pathSegments.first,
        username: userInfo == null
            ? null
            : Uri.decodeComponent(
                separator < 0 ? userInfo : userInfo.substring(0, separator),
              ),
        password: userInfo == null || separator < 0
            ? null
            : Uri.decodeComponent(userInfo.substring(separator + 1)),
        useSsl: url.queryParameters['sslmode'] == 'require',
      ),
    ),
  );
  await adapter.connect();
  return ((String sql) => adapter.rawQuery(sql, const []), adapter.disconnect);
}
