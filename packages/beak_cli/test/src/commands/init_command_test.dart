import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart';

import '../../support/beak_cli_internals.dart';
import 'package:test/test.dart';

const String _flutterPubspec = '''
name: my_app
description: An existing Flutter app.
publish_to: none
version: 1.0.0+1

environment:
  sdk: ^3.11.0

dependencies:
  # The framework.
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
''';

const String _appMain = '''
import 'package:flutter/widgets.dart';

void main() => runApp(const SizedBox());
''';

void main() {
  late Directory root;
  late StringBuffer out;
  late List<List<String>> spawned;
  late int refreshed;

  /// Writes [contents] to [path] under the test project.
  void write(String path, String contents) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_init_');
    addTearDown(() => root.deleteSync(recursive: true));
    out = StringBuffer();
    spawned = [];
    refreshed = 0;
    write('pubspec.yaml', _flutterPubspec);
    write('lib/main.dart', _appMain);
  });

  BeakCliEnvironment environment({int pubExit = 0}) => BeakCliEnvironment(
    out: out,
    rootDirectory: root,
    now: () => DateTime.utc(2026, 9, 28, 10, 15),
    probe: (host, port) async => false,
    runProcess: (executable, arguments, {workingDirectory}) async {
      spawned.add([executable, ...arguments]);
      return pubExit;
    },
  );

  Future<int> init(List<String> args, {int pubExit = 0}) async {
    final runner = createBeakRunner(environment(pubExit: pubExit));
    return await runner.run(['init', ...args]) ?? 0;
  }

  /// An `init` whose agent-files seam counts its calls.
  Future<int> initCounting(List<String> args) async {
    final runner = CommandRunner<int>('beak', 'test')
      ..addCommand(
        InitCommand(
          environment(),
          refreshAgentFiles: (environment) async => refreshed++,
        ),
      );
    return await runner.run(['init', ...args]) ?? 0;
  }

  bool exists(String path) => File('${root.path}/$path').existsSync();

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  /// Every file under the project, by relative path.
  Map<String, String> snapshot() => {
    for (final file in root.listSync(recursive: true).whereType<File>())
      file.path.substring(root.path.length + 1): file.readAsStringSync(),
  };

  YamlMap pubspec() => loadYaml(read('pubspec.yaml')) as YamlMap;

  group('the dependency', () {
    test('is beak from git, pinned to the release of this CLI', () async {
      expect(await init(['--no-pub']), 0);

      final beak = (pubspec()['dependencies'] as YamlMap)['beak'] as YamlMap;
      final git = beak['git'] as YamlMap;
      expect(git['url'], 'https://github.com/SimonErich/beak.git');
      expect(git['ref'], 'v$beakCliVersion');
      expect(git['path'], 'packages/beak');
    });

    test('--beak-ref names another ref', () async {
      await init(['--no-pub', '--beak-ref', 'main']);

      final beak = (pubspec()['dependencies'] as YamlMap)['beak'] as YamlMap;
      expect((beak['git'] as YamlMap)['ref'], 'main');
    });

    test('--beak-path depends on a local checkout instead', () async {
      await init(['--no-pub', '--beak-path', '../beak']);

      final beak = (pubspec()['dependencies'] as YamlMap)['beak'] as YamlMap;
      expect(beak['path'], '../beak/packages/beak');
      expect(beak.containsKey('git'), isFalse);
    });

    test('a ref and a path together are a usage error', () {
      expect(
        init(['--beak-ref', 'main', '--beak-path', '../beak']),
        throwsA(isA<UsageException>()),
      );
    });

    test('is added without disturbing the rest of the pubspec', () async {
      await init(['--no-pub']);

      final String source = read('pubspec.yaml');
      expect(source, contains('# The framework.'));
      expect(source, contains('cupertino_icons: ^1.0.8'));
      expect(source, contains('description: An existing Flutter app.'));
      expect(source, contains('flutter_test:'));
      // The addition is the only difference.
      expect(
        source.replaceFirst(RegExp(r'  beak:\n(    .*\n)+'), ''),
        _flutterPubspec,
      );
    });
  });

  group('beak.yaml', () {
    test(
      'is written with the name, the api origin and the entrypoint',
      () async {
        await init(['--no-pub']);

        final BeakProjectConfig config = BeakProjectConfig.parse(
          read('beak.yaml'),
          packageName: 'my_app',
        );
        expect(config.name, 'My App');
        expect(config.api.baseUrl, 'http://localhost:8080');
        expect(config.panel.entrypoint, 'lib/admin_main.dart');
      },
    );

    test('explains itself in comments', () async {
      await init(['--no-pub']);

      expect(read('beak.yaml'), contains('# '));
    });

    test(
      'gains a panel key when it has none, and keeps its comments',
      () async {
        write('beak.yaml', '''
# Mine.
name: Acme Admin

api:
  # Where the API lives.
  baseUrl: https://api.example.com

resources:
  notes:
    icon: fileText
''');

        await init(['--no-pub']);

        final String source = read('beak.yaml');
        expect(source, contains('# Mine.'));
        expect(source, contains('# Where the API lives.'));
        expect(source, contains('baseUrl: https://api.example.com'));
        final BeakProjectConfig config = BeakProjectConfig.parse(
          source,
          packageName: 'my_app',
        );
        expect(config.panel.entrypoint, 'lib/admin_main.dart');
        expect(config.resources['notes']?.icon, 'fileText');
      },
    );

    test('a file with only comments gains the key too', () async {
      write('beak.yaml', '# Every key is optional.\n');

      await init(['--no-pub']);

      expect(read('beak.yaml'), startsWith('# Every key is optional.\n'));
      expect(
        BeakProjectConfig.parse(
          read('beak.yaml'),
          packageName: 'my_app',
        ).panel.entrypoint,
        'lib/admin_main.dart',
      );
    });

    test('keeps an entrypoint it already names', () async {
      write('beak.yaml', 'panel:\n  entrypoint: lib/back_office.dart\n');

      await init(['--no-pub']);

      expect(read('beak.yaml'), 'panel:\n  entrypoint: lib/back_office.dart\n');
      expect(exists('lib/back_office.dart'), isTrue);
      expect(exists('lib/admin_main.dart'), isFalse);
    });

    test('a broken file is reported by name, and nothing is written', () async {
      write('beak.yaml', 'colour: blue\n');
      final before = snapshot();

      expect(await init(['--no-pub']), 1);

      expect(out.toString(), contains('beak.yaml'));
      expect(out.toString(), contains('colour'));
      expect(snapshot(), before);
    });
  });

  group('the entrypoint', () {
    test('is lib/admin_main.dart while the app owns lib/main.dart', () async {
      await init(['--no-pub']);

      expect(exists('lib/admin_main.dart'), isTrue);
      expect(read('lib/main.dart'), _appMain);
      expect(
        BeakProjectConfig.parse(
          read('beak.yaml'),
          packageName: 'my_app',
        ).panel.entrypoint,
        'lib/admin_main.dart',
      );
    });

    test('is authored: no generated header, BeakPanel and runApp', () async {
      await init(['--no-pub']);

      final String source = read('lib/admin_main.dart');
      expect(source, isNot(contains('GENERATED')));
      expect(source, contains("import 'package:beak/panel.dart';"));
      expect(source, contains('runApp'));
      expect(source, contains('BeakPanel('));
      expect(source, contains('resources:'));
      expect(source, contains("title: 'My App'"));
      expect(BeakEmitters.format(source), source);
    });

    test('is lib/main.dart when the app has none', () async {
      File('${root.path}/lib/main.dart').deleteSync();

      await init(['--no-pub']);

      expect(read('lib/main.dart'), contains('BeakPanel('));
      expect(
        BeakProjectConfig.parse(
          read('beak.yaml'),
          packageName: 'my_app',
        ).panel.entrypoint,
        'lib/main.dart',
      );
    });

    test(
      'is lib/main.dart when Beak wrote it, replacing the generated one',
      () async {
        write('lib/main.dart', '${BeakEmitters.header}void main() {}\n');

        await init(['--no-pub']);

        expect(read('lib/main.dart'), contains('BeakPanel('));
        expect(read('lib/main.dart'), isNot(contains('GENERATED')));
      },
    );

    test('--entrypoint chooses the file', () async {
      await init(['--no-pub', '--entrypoint', 'lib/back_office.dart']);

      expect(exists('lib/back_office.dart'), isTrue);
      expect(exists('lib/admin_main.dart'), isFalse);
      expect(read('beak.yaml'), contains('entrypoint: lib/back_office.dart'));
    });

    for (final bad in const [
      'main.dart',
      'lib/admin/main.dart',
      'lib/admin_main',
      '/lib/admin_main.dart',
      '../lib/admin_main.dart',
      'test/admin_main.dart',
    ]) {
      test('--entrypoint $bad is a usage error', () {
        expect(
          init(['--no-pub', '--entrypoint', bad]),
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains('lib/'),
            ),
          ),
        );
        expect(exists('beak.yaml'), isFalse);
      });
    }

    test('one the app already wrote is left as it is', () async {
      write('lib/admin_main.dart', '// mine\n');

      expect(await init(['--no-pub']), 0);

      expect(read('lib/admin_main.dart'), '// mine\n');
      expect(out.toString(), contains('lib/admin_main.dart already exists'));
    });

    test('--entrypoint may not contradict beak.yaml', () async {
      write('beak.yaml', 'panel:\n  entrypoint: lib/back_office.dart\n');
      final before = snapshot();

      expect(await init(['--no-pub', '--entrypoint', 'lib/other.dart']), 1);

      expect(out.toString(), contains('lib/back_office.dart'));
      expect(snapshot(), before);
    });

    test('--entrypoint may repeat what beak.yaml says', () async {
      write('beak.yaml', 'panel:\n  entrypoint: lib/back_office.dart\n');

      expect(
        await init(['--no-pub', '--entrypoint', 'lib/back_office.dart']),
        0,
      );
    });
  });

  group('--example', () {
    test('writes a first schema class and its resource', () async {
      await init(['--no-pub', '--example']);

      final String schema = read('lib/resources/notes/models/note.dart');
      expect(schema, contains('final class Note extends BeakSchema'));
      expect(schema, contains("part 'note.beak.dart';"));
      final String resource = read('lib/resources/notes/note_resource.dart');
      expect(resource, contains('final class NoteResource extends'));
      expect(resource, contains("import 'models/note.dart';"));
    });

    test('lists the resource in the entrypoint', () async {
      await init(['--no-pub', '--example']);

      final String source = read('lib/admin_main.dart');
      expect(source, contains("import 'resources/notes/note_resource.dart';"));
      expect(source, contains('NoteResource()'));
    });

    test('is not written without the flag', () async {
      await init(['--no-pub']);

      expect(exists('lib/resources'), isFalse);
    });

    test('never overwrites a file the app already has', () async {
      write('lib/resources/notes/models/note.dart', '// mine\n');

      await init(['--no-pub', '--example']);

      expect(read('lib/resources/notes/models/note.dart'), '// mine\n');
      expect(exists('lib/resources/notes/note_resource.dart'), isTrue);
    });

    test('prepares into a project the panel can boot', () async {
      expect(await init(['--example']), 0);

      expect(exists('lib/beak/registry.g.dart'), isTrue);
      expect(read('lib/beak/registry.g.dart'), contains('NoteModel()'));
      expect(exists('lib/resources/notes/models/note.beak.dart'), isTrue);
      expect(exists('lib/migrations/create_notes_table.dart'), isTrue);
      // The app's own main is not overwritten by generation.
      expect(read('lib/main.dart'), _appMain);
    });
  });

  group('.gitignore', () {
    test('is created with a block for what Beak generates', () async {
      await init(['--no-pub']);

      final String source = read('.gitignore');
      expect(source, contains('# BEGIN beak'));
      expect(source, contains('# END beak'));
      for (final entry in const [
        '/bin/serve.dart',
        '/bin/migrate.dart',
        '/*.db*',
        '/storage/',
        '.env',
      ]) {
        expect(source.split('\n'), contains(entry));
      }
      expect(
        source.indexOf('# BEGIN beak'),
        lessThan(source.indexOf('/bin/serve.dart')),
      );
      expect(
        source.indexOf('/storage/'),
        lessThan(source.indexOf('# END beak')),
      );
    });

    test('is appended to, keeping what the app already ignores', () async {
      write('.gitignore', '.dart_tool/\nbuild/');

      await init(['--no-pub']);

      final String source = read('.gitignore');
      expect(source, startsWith('.dart_tool/\nbuild/\n'));
      expect(source, contains('# BEGIN beak'));
    });

    test('gets its block once, however often init runs', () async {
      await init(['--no-pub']);
      await init(['--no-pub']);

      expect('# BEGIN beak'.allMatches(read('.gitignore')), hasLength(1));
      expect('# END beak'.allMatches(read('.gitignore')), hasLength(1));
    });

    test('a block the user edited is left alone', () async {
      write('.gitignore', '# BEGIN beak\n/bin/serve.dart\n# END beak\n');

      await init(['--no-pub']);

      expect(read('.gitignore'), '# BEGIN beak\n/bin/serve.dart\n# END beak\n');
    });
  });

  group('afterwards', () {
    test('resolves packages, then prepares', () async {
      expect(await init([]), 0);

      expect(spawned, [
        ['flutter', 'pub', 'get'],
      ]);
      expect(exists('lib/beak/registry.g.dart'), isTrue);
      expect(exists('bin/serve.dart'), isTrue);
      expect(exists('bin/migrate.dart'), isTrue);
    });

    test('never writes lib/main.dart while preparing', () async {
      await init([]);

      expect(read('lib/main.dart'), _appMain);
    });

    test('--no-pub does neither', () async {
      expect(await init(['--no-pub']), 0);

      expect(spawned, isEmpty);
      expect(exists('lib/beak'), isFalse);
      expect(out.toString(), contains('flutter pub get'));
      expect(out.toString(), contains('beak prepare'));
    });

    test(
      'a failed pub get is reported, exits 1, and keeps the files',
      () async {
        expect(await init([], pubExit: 1), 1);

        expect(out.toString(), contains('flutter pub get'));
        expect(exists('lib/admin_main.dart'), isTrue);
        expect(read('pubspec.yaml'), contains('beak:'));
      },
    );

    test('a generation failure exits 1', () async {
      write('lib/models/broken.dart', '''
import 'package:beak_core/beak_core.dart';

final class BrokenModel extends BeakModel {
  BrokenModel(this.table);
  @override
  final String table;
}
''');

      expect(await init([]), 1);
      expect(out.toString(), contains('Cannot generate'));
    });

    test('tells the user to start the panel with the entrypoint', () async {
      await init([]);

      expect(
        out.toString(),
        contains('flutter run -d chrome -t lib/admin_main.dart'),
      );
    });

    test('prints the strict analyzer flags it did not add', () async {
      await init(['--no-pub']);

      expect(out.toString(), contains('strict-casts: true'));
      expect(out.toString(), contains('strict-inference: true'));
      expect(out.toString(), contains('strict-raw-types: true'));
      expect(exists('analysis_options.yaml'), isFalse);
    });

    test('leaves analysis_options.yaml exactly as it was', () async {
      write(
        'analysis_options.yaml',
        'include: package:lints/recommended.yaml\n',
      );

      await init(['--no-pub']);

      expect(
        read('analysis_options.yaml'),
        'include: package:lints/recommended.yaml\n',
      );
      expect(out.toString(), contains('strict-casts: true'));
    });

    test('says nothing about flags the app already has', () async {
      write('analysis_options.yaml', '''
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
''');

      await init(['--no-pub']);

      expect(out.toString(), isNot(contains('strict-casts')));
    });

    test('hands over to the agent files after preparing', () async {
      expect(await initCounting([]), 0);

      expect(refreshed, 1);
    });

    test('does not refresh agent files without packages to read', () async {
      await initCounting(['--no-pub']);

      expect(refreshed, 0);
    });

    test('does not refresh agent files after a failure', () async {
      write('lib/models/broken.dart', '''
import 'package:beak_core/beak_core.dart';

final class BrokenModel extends BeakModel {
  BrokenModel(this.table);
  @override
  final String table;
}
''');

      expect(await initCounting([]), 1);
      expect(refreshed, 0);
    });
  });

  group('preconditions', () {
    test('a directory without a pubspec is not a project', () async {
      File('${root.path}/pubspec.yaml').deleteSync();

      expect(await init([]), 1);

      expect(out.toString(), contains('pubspec.yaml'));
      expect(exists('beak.yaml'), isFalse);
    });

    test('a pure Dart project is refused', () async {
      write('pubspec.yaml', 'name: cli_tool\ndependencies:\n  args: ^2.0.0\n');
      final before = snapshot();

      expect(await init([]), 1);

      expect(out.toString(), contains('Flutter projects only'));
      expect(snapshot(), before);
    });

    test('a pubspec that is not valid YAML is reported', () async {
      write('pubspec.yaml', 'name: [oops\n');

      expect(await init([]), 1);

      expect(out.toString(), contains('pubspec.yaml'));
    });

    test('a pubspec whose dependencies are not a mapping is refused', () async {
      write('pubspec.yaml', 'name: odd\ndependencies: nothing\n');

      expect(await init([]), 1);

      expect(out.toString(), contains('Flutter projects only'));
    });

    const serverpodHint =
        'add the admin app to your Serverpod workspace instead '
        '(see the Serverpod section of the docs)';

    test('a project depending on serverpod is refused', () async {
      write(
        'pubspec.yaml',
        _flutterPubspec.replaceFirst(
          '  cupertino_icons: ^1.0.8\n',
          '  cupertino_icons: ^1.0.8\n  serverpod_flutter: 4.0.0\n',
        ),
      );
      final before = snapshot();

      expect(await init([]), 1);

      expect(out.toString(), contains(serverpodHint));
      expect(snapshot(), before);
      expect(spawned, isEmpty);
    });

    test('a workspace with a serverpod member is refused', () async {
      write('pubspec.yaml', '$_flutterPubspec\nworkspace:\n  - acme_server\n');
      write(
        'acme_server/pubspec.yaml',
        'name: acme_server\nresolution: workspace\n'
            'dependencies:\n  serverpod: 4.0.0\n',
      );
      final before = snapshot();

      expect(await init([]), 1);

      expect(out.toString(), contains(serverpodHint));
      expect(snapshot(), before);
    });

    test('a workspace member without serverpod is fine', () async {
      write('pubspec.yaml', '$_flutterPubspec\nworkspace:\n  - shared\n');
      write('shared/pubspec.yaml', 'name: shared\nresolution: workspace\n');

      expect(await init(['--no-pub']), 0);
    });

    test('a workspace member that is missing is skipped', () async {
      write('pubspec.yaml', '$_flutterPubspec\nworkspace:\n  - ghost\n');

      expect(await init(['--no-pub']), 0);
    });

    test('an app inside a serverpod workspace is refused', () async {
      Directory('${root.path}/acme_flutter').createSync();
      File('${root.path}/pubspec.yaml').writeAsStringSync(
        'name: acme\nenvironment:\n  sdk: ^3.11.0\n'
        'workspace:\n  - acme_server\n  - acme_flutter\n',
      );
      write(
        'acme_server/pubspec.yaml',
        'name: acme_server\nresolution: workspace\n'
            'dependencies:\n  serverpod: 4.0.0\n',
      );
      write(
        'acme_flutter/pubspec.yaml',
        _flutterPubspec.replaceFirst(
          'environment:',
          'resolution: workspace\nenvironment:',
        ),
      );
      final app = Directory('${root.path}/acme_flutter');
      final runner = createBeakRunner(
        BeakCliEnvironment(
          out: out,
          rootDirectory: app,
          now: () => DateTime.utc(2026),
          probe: (host, port) async => false,
        ),
      );

      expect(await runner.run(['init', '--no-pub']), 1);

      expect(out.toString(), contains(serverpodHint));
      expect(File('${app.path}/beak.yaml').existsSync(), isFalse);
    });

    test('an app in a workspace without serverpod is fine', () async {
      Directory('${root.path}/app').createSync();
      File('${root.path}/pubspec.yaml').writeAsStringSync(
        'name: mono\nenvironment:\n  sdk: ^3.11.0\nworkspace:\n  - app\n',
      );
      write(
        'app/pubspec.yaml',
        _flutterPubspec.replaceFirst(
          'environment:',
          'resolution: workspace\nenvironment:',
        ),
      );
      final app = Directory('${root.path}/app');
      final runner = createBeakRunner(
        BeakCliEnvironment(
          out: out,
          rootDirectory: app,
          now: () => DateTime.utc(2026),
          probe: (host, port) async => false,
        ),
      );

      expect(await runner.run(['init', '--no-pub']), 0);
    });
  });

  group('repair mode', () {
    const withBeak = '''
name: my_app
environment:
  sdk: ^3.11.0
dependencies:
  # Pinned by hand.
  beak:
    path: ../beak/packages/beak
  flutter:
    sdk: flutter
''';

    test('leaves the dependency alone and exits 0', () async {
      write('pubspec.yaml', withBeak);

      expect(await init(['--no-pub']), 0);

      expect(read('pubspec.yaml'), withBeak);
      expect(out.toString(), contains('already depends on beak'));
    });

    test('writes whatever is missing', () async {
      write('pubspec.yaml', withBeak);

      await init(['--no-pub']);

      expect(exists('beak.yaml'), isTrue);
      expect(exists('lib/admin_main.dart'), isTrue);
      expect(read('.gitignore'), contains('# BEGIN beak'));
    });

    test('recognises the dependency under any spelling', () async {
      write(
        'pubspec.yaml',
        withBeak.replaceFirst(
          '  beak:\n    path: ../beak/packages/beak\n',
          '  beak: ^0.9.0\n',
        ),
      );

      expect(await init(['--no-pub']), 0);

      expect(read('pubspec.yaml'), contains('beak: ^0.9.0'));
    });

    test('still prepares', () async {
      write('pubspec.yaml', withBeak);

      expect(await init([]), 0);

      expect(spawned, [
        ['flutter', 'pub', 'get'],
      ]);
      expect(exists('lib/beak/registry.g.dart'), isTrue);
    });
  });

  group('running it again', () {
    test('writes nothing', () async {
      expect(await init(['--example']), 0);
      final after = snapshot();
      out.clear();

      expect(await init(['--example']), 0);

      expect(snapshot(), after);
      expect(out.toString(), isNot(contains('created')));
      expect(out.toString(), isNot(contains('updated')));
    });

    test('writes nothing without the example either', () async {
      await init([]);
      final after = snapshot();

      await init([]);

      expect(snapshot(), after);
    });

    test('keeps choosing the entrypoint it chose the first time', () async {
      File('${root.path}/lib/main.dart').deleteSync();
      await init(['--no-pub']);
      final after = snapshot();

      // lib/main.dart is now Beak's authored entrypoint, and the app's own
      // no longer: the second run must not go looking for another file.
      await init(['--no-pub']);

      expect(snapshot(), after);
      expect(exists('lib/admin_main.dart'), isFalse);
    });
  });

  group('--dry-run', () {
    test('writes and spawns nothing, and says what it would do', () async {
      final before = snapshot();

      expect(await init(['--dry-run', '--example']), 0);

      expect(snapshot(), before);
      expect(spawned, isEmpty);
      final String text = out.toString();
      expect(text, contains('would add the beak dependency'));
      expect(text, contains('would create beak.yaml'));
      expect(text, contains('would create lib/admin_main.dart'));
      expect(text, contains('would create .gitignore'));
      expect(
        text,
        contains('would create lib/resources/notes/models/note.dart'),
      );
    });

    test('describes an update of a file that is there', () async {
      write('.gitignore', 'build/\n');
      write('beak.yaml', 'name: Acme\n');

      await init(['--dry-run']);

      expect(out.toString(), contains('would update .gitignore'));
      expect(out.toString(), contains('would update beak.yaml'));
    });

    test('in repair mode leaves out the dependency', () async {
      write(
        'pubspec.yaml',
        _flutterPubspec.replaceFirst(
          'dependencies:\n',
          'dependencies:\n  beak: ^0.9.0\n',
        ),
      );

      await init(['--dry-run']);

      expect(out.toString(), isNot(contains('would add the beak dependency')));
    });
  });
}
