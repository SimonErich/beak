@Tags(['e2e'])
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

import '../support/beak_cli_internals.dart';

/// Reading a real Postgres catalog: which schema is read, and which table
/// each constraint belongs to.
///
/// Both went wrong in ways a canned `information_schema` cannot show. The
/// `schema` argument was dropped on the way to the introspector, so `--schema
/// app` read `public`; and a constraint name is only unique within its table,
/// so two tables that hand-name a foreign key alike were each given the
/// other's columns. It needs a server, and skips when there is none, like the
/// other suites that do.
Future<void> main() async {
  final Uri url = Uri.parse(
    Platform.environment['DATABASE_URL'] ??
        'postgres://beak:beak@localhost:25432/beak',
  );
  final bool reachable = await _reachable(url);
  const String schema = 'beak_introspect_review';
  const String quoted = "beak_o'neil_review";
  late DatabaseAdapter admin;

  setUpAll(() async {
    if (!reachable) {
      return;
    }
    admin = _adapterFor(url);
    await admin.connect();
    for (final name in const [schema, quoted]) {
      await admin.rawQuery('DROP SCHEMA IF EXISTS "$name" CASCADE', const []);
      await admin.rawQuery('CREATE SCHEMA "$name"', const []);
    }
    for (final statement in [
      'CREATE TABLE "$schema".owners (id integer PRIMARY KEY, name text)',
      'CREATE TABLE "$schema".others (id integer PRIMARY KEY, name text)',
      'CREATE TABLE "$schema".a (id integer PRIMARY KEY, owner_id integer, '
          'CONSTRAINT fk_owner FOREIGN KEY (owner_id) '
          'REFERENCES "$schema".owners (id))',
      'CREATE TABLE "$schema".b (code text PRIMARY KEY, other_id integer, '
          'CONSTRAINT fk_owner FOREIGN KEY (other_id) '
          'REFERENCES "$schema".others (id))',
      'CREATE TABLE "$quoted".quoted_only (id integer PRIMARY KEY)',
    ]) {
      await admin.rawQuery(statement, const []);
    }
  });

  tearDownAll(() async {
    if (!reachable) {
      return;
    }
    for (final name in const [schema, quoted]) {
      await admin.rawQuery('DROP SCHEMA IF EXISTS "$name" CASCADE', const []);
    }
    await admin.disconnect();
  });

  final String? skip = reachable
      ? null
      : 'Postgres is unreachable: start it with `melos run up`.';

  test('reads the schema it was asked for, and only that', () async {
    final List<IntrospectedTable> tables = await beakReadLiveSchema(
      url,
      schema: schema,
    );

    expect(tables.map((table) => table.name), ['a', 'b', 'others', 'owners']);
  }, skip: skip);

  test('gives each table its own foreign key and its own key', () async {
    final List<IntrospectedTable> tables = await beakReadLiveSchema(
      url,
      schema: schema,
    );
    final Map<String, IntrospectedTable> byName = {
      for (final table in tables) table.name: table,
    };

    final IntrospectedForeignKey a = byName['a']!.foreignKeys.single;
    expect((a.column, a.referencedTable), ('owner_id', 'owners'));
    final IntrospectedForeignKey b = byName['b']!.foreignKeys.single;
    expect((b.column, b.referencedTable), ('other_id', 'others'));
    expect(byName['a']!.primaryKey, 'id');
    expect(byName['b']!.primaryKey, 'code');
  }, skip: skip);

  test('reads a schema whose name has a quote in it', () async {
    final List<IntrospectedTable> tables = await beakReadLiveSchema(
      url,
      schema: quoted,
    );

    expect(tables.map((table) => table.name), ['quoted_only']);
  }, skip: skip);
}

Future<bool> _reachable(Uri url) async {
  try {
    final socket = await Socket.connect(
      url.host,
      url.hasPort ? url.port : 5432,
      timeout: const Duration(seconds: 2),
    );
    await socket.close();
    return true;
  } on Object {
    return false;
  }
}

/// A Postgres adapter over [url], for the setup statements.
PostgresAdapter _adapterFor(Uri url) {
  final String userInfo = url.userInfo;
  final int separator = userInfo.indexOf(':');
  return PostgresAdapter(
    pool: PostgresConnectionPool.fromConfig(
      ConnectionConfig(
        driver: 'postgres',
        host: url.host,
        port: url.hasPort ? url.port : 5432,
        database: url.pathSegments.isEmpty
            ? 'postgres'
            : url.pathSegments.first,
        username: separator < 0 ? null : userInfo.substring(0, separator),
        password: separator < 0 ? null : userInfo.substring(separator + 1),
      ),
    ),
  );
}
