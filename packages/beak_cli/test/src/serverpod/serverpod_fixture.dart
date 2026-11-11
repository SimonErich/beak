import 'dart:convert';
import 'dart:io';

import 'package:beak_cli/src/cli_runner.dart';
import 'package:beak_cli/src/serverpod/database_definition.dart';
import 'package:beak_cli/src/serverpod/definition_set_builder.dart';
import 'package:beak_cli/src/serverpod/definition_paths.dart';
import 'package:beak_cli/src/serverpod/definition_reader.dart';
import 'package:beak_cli/src/serverpod/generate_issue.dart';
import 'package:beak_cli/src/serverpod/generate_settings.dart';
import 'package:beak_cli/src/serverpod/serverpod_ir.dart';
import 'package:beak_cli/src/serverpod/spy_reader.dart';
import 'package:path/path.dart' as p;

/// A Serverpod admin project in a temporary folder: a server with models and
/// a migration, a definitions package and `beak.yaml`.
final class ServerpodFixture {
  /// Creates the project in a new temporary folder.
  ServerpodFixture() : root = Directory.systemTemp.createTempSync('beak-sp-');

  /// The project folder, which holds `beak.yaml`.
  final Directory root;

  /// The settings the IR helpers use.
  static const settings = BeakGenerateSettings(
    prefix: 'Shop',
    areas: {
      'catalog': BeakAreaRoles(read: ['readCatalog'], write: ['writeCatalog']),
    },
    conventions: BeakGenerateConventions(dateOnly: ['*Date']),
  );

  /// Removes the folder.
  void delete() => root.deleteSync(recursive: true);

  /// Writes [source] to [path] under the project.
  void write(String path, String source) {
    File(p.join(root.path, path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(source);
  }

  /// Reads [path] under the project.
  String read(String path) => File(p.join(root.path, path)).readAsStringSync();

  /// Whether [path] exists under the project.
  bool exists(String path) => File(p.join(root.path, path)).existsSync();

  /// The CLI environment rooted at the project.
  BeakCliEnvironment env() => BeakCliEnvironment(
    out: StringBuffer(),
    rootDirectory: root,
    now: () => DateTime.utc(2026),
    probe: (host, port) async => false,
  );

  /// `beak.yaml`, the panel and definitions pubspecs and the server's.
  void project({String labels = '', String? handlers}) {
    write('pubspec.yaml', 'name: shop_admin\n');
    write('definitions/pubspec.yaml', 'name: shop_definitions\n');
    write('server/pubspec.yaml', 'name: shop_server\n');
    write('beak.yaml', '''
$labels
serverpod:
  server: server
  models: [lib/src]
  migrations: migrations
generate:
  definitions: definitions
${handlers == null ? '' : '  handlers: $handlers\n'}  prefix: Shop
  areas:
    catalog: {read: readCatalog, write: writeCatalog}
  conventions:
    dateOnly: ['*Date']
''');
  }

  /// A Serverpod model file.
  void model(String file, String source) =>
      write('server/lib/src/$file.spy.yaml', source);

  /// A definition class library at `lib/src/<library>.dart`, with the
  /// imports and part directive `beak generate` asks for.
  void define(
    String library,
    String source, {
    bool writes = false,
    List<String> imports = const [],
  }) {
    final folder = p.posix.basename(p.posix.dirname(library));
    final part = definitionPartUri(
      area: folder,
      name: p.basename(library),
      library: 'src/$library.dart',
    );
    const support =
        'package:shop_definitions/src/generated/definitions_support.dart';
    final uris = <String>{
      if (writes) support,
      for (final uri in imports)
        uri.endsWith('generated/enums.dart') ||
                uri.endsWith('generated/writes.dart')
            ? support
            : uri,
    };
    write('definitions/lib/src/$library.dart', '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/schema.dart';
${uris.map((uri) => "import '$uri';").join('\n')}

part '$part';

$source
''');
  }

  /// The newest migration, holding [tables].
  void database(List<Map<String, Object?>> tables) => write(
    'server/migrations/0001/definition_project.json',
    jsonEncode({'tables': tables}),
  );

  /// One migration table; a column named `id*`, `*Id` or `_*` is a UUID.
  static Map<String, Object?> table(
    String name,
    List<String> columns, {
    Map<String, String> types = const {},
    List<Map<String, Object?>> foreignKeys = const [],
    List<Map<String, Object?>> indexes = const [],
  }) => {
    'name': name,
    'columns': [
      for (final column in columns)
        {
          'name': column,
          'dartType':
              types[column] ??
              (column.startsWith('id') ||
                      column.endsWith('Id') ||
                      column.startsWith('_')
                  ? 'UuidValue?'
                  : 'String?'),
        },
    ],
    'foreignKeys': foreignKeys,
    'indexes': indexes,
  };

  /// Builds the IR from the server and the definition classes, throwing the
  /// first run's issues as a [BeakGenerateException].
  ServerpodIr ir() {
    final server = Directory(p.join(root.path, 'server'));
    const serverpod = BeakServerpodSettings(server: 'server');
    final project = SpyReader(server, serverpod).read();
    final database = DatabaseDefinition.read(server, 'migrations');
    final issues = BeakIssueSink();
    final classes = readDefinitions(
      Directory(p.join(root.path, 'definitions')),
      'definitions',
      issues,
    );
    final checked = definitionSetOf(
      classes,
      project,
      database,
      settings,
      issues,
    );
    issues.throwIfAny();
    return buildServerpodIr(
      project: project,
      database: database,
      definitions: checked,
      settings: settings,
      prefix: 'Shop',
    );
  }
}
