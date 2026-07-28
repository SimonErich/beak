import 'dart:io';

import 'package:worm_sqlite/worm_sqlite.dart';

import '../commands/introspect_command.dart';
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

/// Whether Beak can read the schema of the database [url] names.
bool beakCanReadSchema(Uri url) =>
    isIntrospectableUrl(url) || beakSqliteFileOf(url) != null;

/// The file a SQLite [url] names, or `null` when it names something else.
///
/// `sqlite::memory:` returns null on purpose: an in-memory database belongs to
/// the process that opened it, so there is nothing for another process to
/// read.
String? beakSqliteFileOf(Uri url) {
  if (url.scheme != 'sqlite' && url.scheme != 'file') {
    return null;
  }
  final String path = url.path.isEmpty ? url.toString() : url.path;
  final String file = path.startsWith('sqlite:')
      ? path.substring('sqlite:'.length)
      : path;
  return file.isEmpty || file.contains(':memory:') ? null : file;
}

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
      await openPostgresConnection(url);
  try {
    return await PostgresIntrospector(query).read();
  } finally {
    await close();
  }
}

/// Whether the SQLite file [url] names exists yet, relative to [root].
///
/// Before the first `beak migrate` there is no file, and no schema to be out
/// of step with.
bool beakSqliteFileExists(Uri url, Directory root) {
  final String? file = beakSqliteFileOf(url);
  if (file == null) {
    return false;
  }
  final String path = file.startsWith('/') ? file : '${root.path}/$file';
  return File(path).existsSync();
}

/// The database a project uses when it names none.
///
/// The same default `BeakBackendConfig` applies, so `doctor` checks the file
/// the server would really open rather than reporting that nothing is
/// configured.
const String defaultSqliteUrl = 'sqlite:beak.db';

/// The `DATABASE_URL` from the project's `.env`, when it declares one.
Uri? beakDatabaseUrlOf(Directory root) {
  final env = File('${root.path}/.env');
  if (!env.existsSync()) {
    return null;
  }
  for (final line in env.readAsLinesSync()) {
    final match = RegExp(r'^\s*DATABASE_URL\s*=\s*(\S+)\s*$').firstMatch(line);
    if (match != null) {
      return Uri.tryParse(match.group(1)!);
    }
  }
  return null;
}

/// [url] with a relative SQLite path made absolute against [root].
///
/// `sqlite:beak.db` names a file beside the project, and `doctor` runs from
/// wherever the user happens to be.
Uri beakResolvedDatabaseUrl(Uri url, Directory root) {
  final String? file = beakSqliteFileOf(url);
  if (file == null || file.startsWith('/')) {
    return url;
  }
  return Uri.parse('sqlite:${root.path}/$file');
}
