import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late StringBuffer out;
  late List<List<String>> spawned;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_create_');
    addTearDown(() => root.deleteSync(recursive: true));
    out = StringBuffer();
    spawned = [];
  });

  BeakCliEnvironment environment({int webExitCode = 0}) => BeakCliEnvironment(
    out: out,
    rootDirectory: root,
    now: () => DateTime.utc(2026, 7, 26, 12),
    probe: (host, port) async => false,
    runProcess: (executable, arguments, {workingDirectory}) async {
      spawned.add([executable, ...arguments]);
      return webExitCode;
    },
  );

  Future<int> create(List<String> args, {int webExitCode = 0}) async =>
      await createBeakRunner(
        environment(webExitCode: webExitCode),
      ).run(['create', ...args]) ??
      0;

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  bool exists(String path) => File('${root.path}/$path').existsSync();

  group('scaffold', () {
    test('writes only the files a user actually owns', () async {
      expect(await create(['acme_admin']), 0);

      // What the user writes.
      expect(exists('acme_admin/pubspec.yaml'), isTrue);
      expect(exists('acme_admin/beak.yaml'), isTrue);
      expect(exists('acme_admin/lib/models/note.dart'), isTrue);
      expect(exists('acme_admin/AGENTS.md'), isTrue);

      // What Beak generates, so the project runs as created.
      expect(exists('acme_admin/lib/beak/registry.g.dart'), isTrue);
      expect(exists('acme_admin/lib/main.dart'), isTrue);
      expect(exists('acme_admin/bin/serve.dart'), isTrue);
      expect(exists('acme_admin/bin/migrate.dart'), isTrue);
    });

    test('generates the wiring in the new project, not the parent', () async {
      await create(['acme_admin']);
      expect(exists('lib/beak/registry.g.dart'), isFalse);
      expect(
        read('acme_admin/lib/beak/registry.g.dart'),
        contains('NoteModel'),
      );
    });

    test('git-ignores the entrypoints but not the wiring', () async {
      await create(['acme_admin']);
      final ignored = read('acme_admin/.gitignore');
      expect(ignored, contains('/lib/main.dart'));
      expect(ignored, contains('/bin/serve.dart'));
      expect(ignored, isNot(contains('lib/beak/')));
    });

    test('delegates web/ to flutter create', () async {
      await create(['acme_admin']);
      expect(spawned.single, [
        'flutter',
        'create',
        '--platforms=web',
        '--project-name',
        'acme_admin',
        '.',
      ]);
    });

    test('a failed web scaffold warns but still produces a project', () async {
      expect(await create(['acme_admin'], webExitCode: 1), 0);
      expect(out.toString(), contains('skipped   web/'));
      expect(exists('acme_admin/lib/beak/registry.g.dart'), isTrue);
    });

    test('replaces the flutter counter test with a real smoke test', () async {
      await create(['acme_admin']);
      final smoke = read('acme_admin/test/widget_test.dart');
      expect(smoke, contains('package:acme_admin/beak/app.g.dart'));
      expect(smoke, contains('BeakApp(dataSource:'));
      expect(smoke, isNot(contains('_PACKAGE_')));
      expect(smoke, isNot(contains('MyApp')));
    });
  });

  group('dependencies', () {
    test('default to git, so a project resolves anywhere', () async {
      await create(['acme_admin']);
      final pubspec = read('acme_admin/pubspec.yaml');
      expect(pubspec, contains('github.com/SimonErich/beak.git'));
      for (final package in CreateCommand.beakPackages) {
        expect(pubspec, contains('  $package:'));
      }
      expect(pubspec, contains('obers_ui:'));
    });

    test('--beak-path points at a local checkout instead', () async {
      await create(['acme_admin', '--beak-path', '/opt/beak']);
      final pubspec = read('acme_admin/pubspec.yaml');
      expect(pubspec, contains('path: /opt/beak/packages/beak_core'));
      expect(pubspec, isNot(contains('github.com/SimonErich/beak.git')));
    });
  });

  group('usage', () {
    test('rejects a missing or extra name', () {
      expect(create([]), throwsA(isA<UsageException>()));
      expect(create(['a', 'b']), throwsA(isA<UsageException>()));
    });

    test('rejects a name that is not a Dart package name', () {
      expect(create(['AcmeAdmin']), throwsA(isA<UsageException>()));
      expect(create(['acme-admin']), throwsA(isA<UsageException>()));
      expect(create(['1acme']), throwsA(isA<UsageException>()));
    });
  });

  group('scaffoldFiles is pure', () {
    test('so the scaffold can be asserted without a file system', () {
      final files = CreateCommand.scaffoldFiles('acme_admin');
      expect(files.map((file) => file.path), contains('acme_admin/beak.yaml'));
      expect(
        files.firstWhere((file) => file.path.endsWith('AGENTS.md')).contents,
        contains('Never write a column key or table name as a string'),
      );
    });
  });
}
