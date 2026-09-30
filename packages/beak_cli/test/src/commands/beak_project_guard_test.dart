import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';

/// What a command run outside a Beak project sees.
void main() {
  late Directory root;
  late StringBuffer out;
  late List<String> spawned;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_guard_');
    addTearDown(() => root.deleteSync(recursive: true));
    out = StringBuffer();
    spawned = [];
  });

  Future<int> run(List<String> args) async =>
      await createBeakRunner(
        BeakCliEnvironment(
          out: out,
          rootDirectory: root,
          now: () => DateTime.utc(2026, 7, 26, 12),
          probe: (host, port) async => false,
          runProcess: (executable, arguments, {workingDirectory}) async {
            spawned.add('$executable ${arguments.join(' ')}');
            return 0;
          },
        ),
      ).run(args) ??
      0;

  List<String> filesUnderRoot() => [
    for (final entity in root.listSync(recursive: true))
      entity.path.substring(root.path.length + 1),
  ];

  /// A Flutter app that does not use Beak.
  void writePlainFlutterApp() {
    File('${root.path}/pubspec.yaml').writeAsStringSync(
      'name: shop\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
  }

  const outsideCommands = <String, List<String>>{
    'prepare': ['prepare'],
    'dev': ['dev', '--no-serve'],
    'migrate': ['migrate'],
    'seed': ['seed'],
    'make:resource': ['make:resource', 'Product', '--fields', 'name:string'],
    'eject main': ['eject', 'main'],
    'eject panel': ['eject', 'panel'],
    'eject theme': ['eject', 'theme'],
    'make:migration': ['make:migration', 'AddStatus'],
    'make:migration --from-drift': [
      'make:migration',
      'AddStatus',
      '--from-drift',
    ],
  };

  for (final MapEntry(key: label, value: args) in outsideCommands.entries) {
    group('beak $label', () {
      test('refuses an empty directory and writes nothing', () async {
        expect(await run(args), 1);

        expect(filesUnderRoot(), isEmpty);
        expect(spawned, isEmpty);
        expect(out.toString(), contains('no pubspec.yaml here'));
      });

      test('refuses a project that does not depend on Beak and leaves it '
          'as it was', () async {
        writePlainFlutterApp();

        expect(await run(args), 1);

        expect(filesUnderRoot(), ['pubspec.yaml']);
        expect(spawned, isEmpty);
        expect(out.toString(), contains(BeakProjectKind.notABeakProject));
      });
    });
  }

  group('a Beak project', () {
    test('is one that depends on beak', () async {
      File(
        '${root.path}/pubspec.yaml',
      ).writeAsStringSync('name: shop\ndependencies:\n  beak: any\n');

      expect(await run(['prepare']), 0);
    });

    test('is one that depends on a part of it', () async {
      File(
        '${root.path}/pubspec.yaml',
      ).writeAsStringSync('name: shop\ndependencies:\n  beak_backend: any\n');

      expect(await run(['prepare']), 0);
    });
  });
}
