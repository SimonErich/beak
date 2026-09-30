import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../support/agents_fixture.dart';
import '../../support/beak_cli_internals.dart';

void main() {
  late Directory root;
  late StringBuffer out;
  late List<List<String>> spawned;
  late List<List<String>> interactive;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_create_');
    addTearDown(() => root.deleteSync(recursive: true));
    out = StringBuffer();
    spawned = [];
    interactive = [];
  });

  /// The environment `beak create` runs against.
  ///
  /// [webExitCode] is what `flutter create` answers and [pubExitCode] what
  /// `flutter pub get` answers; [whenPubGet] runs at the moment `pub get`
  /// does, with the directory it runs in, to stand in for what it writes.
  /// [at] replaces the directory the project is created in.
  BeakCliEnvironment environment({
    int webExitCode = 0,
    int pubExitCode = 0,
    void Function(String workingDirectory)? whenPubGet,
    Directory? at,
  }) => BeakCliEnvironment(
    out: out,
    rootDirectory: at ?? root,
    now: () => DateTime.utc(2026, 7, 26, 12),
    probe: (host, port) async => false,
    runInteractive: (executable, arguments, {workingDirectory}) async {
      interactive.add([executable, ...arguments]);
      if (workingDirectory != null) {
        whenPubGet?.call(workingDirectory);
      }
      return pubExitCode;
    },
    runProcess: (executable, arguments, {workingDirectory}) async {
      spawned.add([executable, ...arguments]);
      // What the real `flutter create .` does: it fills in the files a
      // Flutter app needs and keeps any that already exist.
      if (webExitCode == 0 && workingDirectory != null) {
        final counterApp = File('$workingDirectory/lib/main.dart');
        if (!counterApp.existsSync()) {
          counterApp
            ..createSync(recursive: true)
            ..writeAsStringSync(
              "import 'package:flutter/material.dart';\n"
              'void main() => runApp(const MyApp());\n',
            );
        }
      }
      return webExitCode;
    },
  );

  Future<int> create(
    List<String> args, {
    int webExitCode = 0,
    int pubExitCode = 0,
    void Function(String workingDirectory)? whenPubGet,
    Directory? at,
  }) async =>
      await createBeakRunner(
        environment(
          webExitCode: webExitCode,
          pubExitCode: pubExitCode,
          whenPubGet: whenPubGet,
          at: at,
        ),
      ).run(['create', ...args]) ??
      0;

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  bool exists(String path) => File('${root.path}/$path').existsSync();

  group('a directory that is already there', () {
    test('that is not empty is refused, and nothing in it is touched', () async {
      // It used to overwrite pubspec.yaml, beak.yaml, lib/main.dart, AGENTS.md
      // and README.md of whatever project lived there.
      File('${root.path}/acme_admin/pubspec.yaml')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('name: precious\n');

      final int code = await create(['acme_admin']);

      expect(code, 1);
      expect(read('acme_admin/pubspec.yaml'), 'name: precious\n');
      expect(exists('acme_admin/beak.yaml'), isFalse);
      expect(spawned, isEmpty);
      expect(interactive, isEmpty);
      expect(out.toString(), contains('acme_admin already exists'));
      expect(out.toString(), contains('not empty'));
    });

    test('that is empty is used', () async {
      Directory('${root.path}/acme_admin').createSync();

      expect(await create(['acme_admin', '--no-pub']), 0);

      expect(exists('acme_admin/beak.yaml'), isTrue);
    });

    test('that is a file is refused', () async {
      File('${root.path}/acme_admin').writeAsStringSync('not a folder');

      expect(await create(['acme_admin']), 1);

      expect(out.toString(), contains('acme_admin already exists'));
    });
  });

  group('scaffold', () {
    test('writes only the files a user actually owns', () async {
      expect(await create(['acme_admin']), 0);

      // What the user writes.
      expect(exists('acme_admin/pubspec.yaml'), isTrue);
      expect(exists('acme_admin/beak.yaml'), isTrue);
      expect(exists('acme_admin/lib/resources/notes/models/note.dart'), isTrue);
      expect(exists('acme_admin/AGENTS.md'), isTrue);
      // The generated panel shows the default resource; a class is written
      // only when the project composes the panel itself.
      expect(
        exists('acme_admin/lib/resources/notes/note_resource.dart'),
        isFalse,
      );

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
      expect(ignored, contains('/bin/migrate.dart'));
      expect(ignored, isNot(contains('lib/beak/')));
    });

    test(
      'the entrypoint is Beak\'s, not flutter create\'s counter app',
      () async {
        // `flutter create .` writes lib/main.dart when there is none, and
        // `prepare` keeps any entrypoint without the generated header, so a
        // new project used to boot a Material counter app.
        await create(['acme_admin']);

        final String main = read('acme_admin/lib/main.dart');
        expect(main, startsWith('// GENERATED BY'));
        expect(main, contains('BeakApp'));
        expect(main, isNot(contains('material.dart')));
      },
    );

    test('ends by pointing at migrate, then dev', () async {
      // `beak dev` on a fresh project served an API whose every request
      // failed on a missing table.
      await create(['acme_admin']);

      final String printed = out.toString();
      final int migrate = printed.indexOf('beak migrate');
      final int dev = printed.indexOf('beak dev');
      expect(printed, contains('cd acme_admin'));
      expect(migrate, greaterThan(-1));
      expect(dev, greaterThan(migrate));
    });

    test('delegates web/ to flutter create, without resolving', () async {
      // `--no-pub`: only the web assets are wanted, and resolving here would
      // make scaffolding fail offline for a step that needs no network.
      await create(['acme_admin']);
      expect(spawned.single, [
        'flutter',
        'create',
        '--platforms=web',
        '--no-pub',
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

  group('gitignore', () {
    test('ignores the default SQLite database', () async {
      // The zero-setup default writes a file beside the project; committing
      // it would put a developer's scratch data in everyone's checkout.
      await create(['acme_admin']);

      expect(read('acme_admin/.gitignore'), contains('/*.db'));
    });

    test('commits the lockfile', () async {
      // An application pins what it was tested against.
      await create(['acme_admin']);

      expect(read('acme_admin/.gitignore'), isNot(contains('pubspec.lock')));
    });
  });

  group('--authored', () {
    test(
      'writes an entrypoint the project owns, listing its resource',
      () async {
        expect(await create(['acme_admin', '--authored']), 0);

        final String main = read('acme_admin/lib/main.dart');
        expect(main, isNot(contains('GENERATED')));
        expect(main, contains('BeakPanel('));
        expect(main, contains('resources: ['));
        expect(main, contains('NoteResource()'));
        expect(main, contains("import 'resources/notes/note_resource.dart';"));
      },
    );

    test('writes the resource class beside its schema', () async {
      await create(['acme_admin', '--authored']);

      final String resource = read(
        'acme_admin/lib/resources/notes/note_resource.dart',
      );
      expect(
        resource,
        contains('final class NoteResource extends BeakResource'),
      );
      expect(resource, contains('model: const NoteModel()'));
      expect(resource, contains("import 'models/note.dart';"));
      expect(resource, contains('OiIcons.fileText'));
      expect(resource, contains("navigationGroup: 'Content'"));
      // Nothing generates a panel around it here: lib/main.dart lists it.
      expect(resource, contains('`resources: [...]` list in `lib/main.dart`'));
      expect(resource, isNot(contains('`beak prepare` finds this class')));
      expect(resource, isNot(contains('stays as Beak generates it')));
    });

    test('prepare leaves the entrypoint alone, and writes no panel that '
        'nothing imports', () async {
      await create(['acme_admin', '--authored']);

      expect(read('acme_admin/lib/main.dart'), isNot(contains('GENERATED')));
      expect(read('acme_admin/lib/main.dart'), contains('NoteResource()'));
      expect(exists('acme_admin/lib/beak/panel.g.dart'), isFalse);
      expect(exists('acme_admin/lib/beak/app.g.dart'), isFalse);
    });

    test(
      'commits the entrypoint but still ignores the generated bin/',
      () async {
        await create(['acme_admin', '--authored']);

        final ignored = read('acme_admin/.gitignore');
        expect(ignored, isNot(contains('/lib/main.dart')));
        expect(ignored, contains('/bin/serve.dart'));
        expect(ignored, contains('/bin/migrate.dart'));
      },
    );

    test('the smoke test pumps the authored panel', () async {
      await create(['acme_admin', '--authored']);

      final smoke = read('acme_admin/test/widget_test.dart');
      expect(smoke, contains('package:acme_admin/main.dart'));
      expect(smoke, contains('buildPanel(dataSource:'));
      expect(smoke, isNot(contains('BeakApp')));
    });

    test('beak.yaml leaves presentation to the resource class', () async {
      await create(['acme_admin', '--authored']);

      expect(read('acme_admin/beak.yaml'), isNot(contains('resources:')));
    });
  });

  group('--no-example', () {
    test('writes no Note schema and no Note resource', () async {
      expect(await create(['acme_admin', '--no-example']), 0);

      expect(exists('acme_admin/lib/resources'), isFalse);
      expect(
        exists('acme_admin/lib/resources/notes/models/note.dart'),
        isFalse,
      );
      expect(exists('acme_admin/pubspec.yaml'), isTrue);
      expect(exists('acme_admin/beak.yaml'), isTrue);
    });

    test('writes no notes block into beak.yaml', () async {
      await create(['acme_admin', '--no-example']);

      final String config = read('acme_admin/beak.yaml');
      expect(config, isNot(contains('resources:')));
      expect(config, isNot(contains('notes')));
      expect(config, contains('name: Acme Admin'));
    });

    test('still generates the wiring, with no model in it', () async {
      await create(['acme_admin', '--no-example']);

      expect(exists('acme_admin/lib/beak/registry.g.dart'), isTrue);
      expect(
        read('acme_admin/lib/beak/registry.g.dart'),
        isNot(contains('NoteModel')),
      );
      expect(exists('acme_admin/bin/migrate.dart'), isTrue);
    });

    test('beak prepare on the empty project succeeds', () async {
      await create(['acme_admin', '--no-example']);
      final project = BeakCliEnvironment(
        out: StringBuffer(),
        rootDirectory: Directory('${root.path}/acme_admin'),
        now: () => DateTime.utc(2026, 7, 26, 12),
        probe: (host, port) async => false,
      );

      expect(await createBeakRunner(project).run(['prepare']), 0);
    });

    test('the generated panel file imports nothing it does not use', () async {
      // `flutter analyze` on a fresh project is the first thing anyone runs,
      // and the icon import is only used by a default resource.
      await create(['acme_admin', '--no-example']);

      expect(
        read('acme_admin/lib/beak/panel.g.dart'),
        isNot(contains("package:beak/ui.dart")),
      );
    });

    test('the smoke test does not pump a panel with nothing in it', () async {
      // A panel needs at least one resource or page, so booting this one
      // throws by design until the first `make:resource`.
      await create(['acme_admin', '--no-example']);

      final smoke = read('acme_admin/test/widget_test.dart');
      expect(smoke, isNot(contains('BeakApp')));
      expect(smoke, isNot(contains('isNotEmpty')));
      expect(smoke, contains('package:acme_admin/beak/registry.g.dart'));
      expect(smoke, contains('beak make:resource'));
      expect(smoke, isNot(contains('_PACKAGE_')));
    });

    test('the README starts from a first resource, not from migrate', () async {
      await create(['acme_admin', '--no-example']);

      final String readme = read('acme_admin/README.md');
      expect(readme, contains('beak make:resource'));
      expect(
        readme.indexOf('beak make:resource'),
        lessThan(readme.indexOf('beak migrate')),
      );
      expect(readme, isNot(contains('Note')));
    });

    test('ends by pointing at make:resource, then migrate, then dev', () async {
      await create(['acme_admin', '--no-example']);

      final String printed = out.toString();
      final int make = printed.indexOf('beak make:resource');
      final int migrate = printed.indexOf('beak migrate');
      final int dev = printed.indexOf('beak dev');
      expect(make, greaterThan(-1));
      expect(migrate, greaterThan(make));
      expect(dev, greaterThan(migrate));
    });

    test('with --authored, the entrypoint lists no resource', () async {
      expect(await create(['acme_admin', '--authored', '--no-example']), 0);

      final String main = read('acme_admin/lib/main.dart');
      expect(main, isNot(contains('GENERATED')));
      expect(main, contains('BeakPanel('));
      expect(main, isNot(contains('NoteResource')));
      expect(
        exists('acme_admin/lib/resources/notes/note_resource.dart'),
        isFalse,
      );
      expect(read('acme_admin/beak.yaml'), isNot(contains('resources:')));
    });

    test('beak agents --check agrees, in both variants', () async {
      for (final variant in [
        const <String>[],
        const ['--authored'],
      ]) {
        root.listSync().forEach((entity) => entity.deleteSync(recursive: true));
        await create(['acme_admin', '--no-example', ...variant]);
        final probe = BeakCliEnvironment(
          out: StringBuffer(),
          rootDirectory: Directory('${root.path}/acme_admin'),
          now: () => DateTime.utc(2026, 7, 26, 12),
          probe: (host, port) async => false,
        );

        expect(
          await createBeakRunner(probe).run(['agents', '--check']),
          0,
          reason: variant.join(' '),
        );
      }
    });

    test('--example is what you get without it', () async {
      await create(['acme_admin', '--example']);

      expect(exists('acme_admin/lib/resources/notes/models/note.dart'), isTrue);
      expect(read('acme_admin/beak.yaml'), contains('notes:'));
    });

    test('the scaffold with the example is unchanged by the flag', () {
      // `examples/quickstart` is checked against the default scaffold, so
      // the flag's default has to be exactly that scaffold.
      expect(
        CreateCommand.scaffoldFiles(
          'acme_admin',
          example: true,
        ).map((f) => f.contents),
        CreateCommand.scaffoldFiles('acme_admin').map((f) => f.contents),
      );
      expect(
        CreateCommand.postScaffoldFiles(
          'acme_admin',
          example: true,
        ).map((f) => f.contents),
        CreateCommand.postScaffoldFiles('acme_admin').map((f) => f.contents),
      );
    });
  });

  group('--pub', () {
    test('resolves the packages before it generates anything', () async {
      late bool wiringExistedThen;
      await create(
        ['acme_admin'],
        whenPubGet: (directory) => wiringExistedThen = File(
          '$directory/lib/beak/registry.g.dart',
        ).existsSync(),
      );

      expect(interactive.single, ['flutter', 'pub', 'get']);
      expect(wiringExistedThen, isFalse, reason: 'pub get comes first');
      expect(exists('acme_admin/lib/beak/registry.g.dart'), isTrue);
    });

    test('runs it in the new project, in the terminal', () async {
      String? ranIn;
      await create([
        'acme_admin',
      ], whenPubGet: (directory) => ranIn = directory);

      expect(ranIn, '${root.path}/acme_admin');
      expect(
        spawned.any(
          (command) => command.contains('pub') && command.contains('get'),
        ),
        isFalse,
        reason: 'a captured run would hide its progress',
      );
    });

    test(
      'ends by pointing at migrate, without asking for pub get again',
      () async {
        await create(['acme_admin']);

        final String next = out.toString().split('  next:').last;
        expect(next, contains('beak migrate'));
        expect(next, isNot(contains('flutter pub get')));
      },
    );

    test('a failed pub get says what to run, and exits 1', () async {
      expect(await create(['acme_admin'], pubExitCode: 65), 1);

      final String printed = out.toString();
      expect(printed, contains('`flutter pub get` failed (exit 65)'));
      expect(printed, contains('beak prepare'));
      expect(exists('acme_admin/pubspec.yaml'), isTrue);
    });

    test('--no-pub resolves nothing and generates nothing', () async {
      expect(await create(['acme_admin', '--no-pub']), 0);

      expect(interactive, isEmpty);
      expect(exists('acme_admin/pubspec.yaml'), isTrue);
      expect(exists('acme_admin/lib/beak'), isFalse);
      expect(exists('acme_admin/bin'), isFalse);
    });

    test('--no-pub prints the commands to run instead', () async {
      await create(['acme_admin', '--no-pub']);

      final String next = out.toString().split('  next:').last;
      final int cd = next.indexOf('cd acme_admin');
      final int pub = next.indexOf('flutter pub get');
      final int prepare = next.indexOf('beak prepare');
      final int migrate = next.indexOf('beak migrate');
      final int dev = next.indexOf('beak dev');
      expect(cd, greaterThan(-1));
      expect(pub, greaterThan(cd));
      expect(prepare, greaterThan(pub));
      expect(migrate, greaterThan(prepare));
      expect(dev, greaterThan(migrate));
    });

    test('--no-pub names the skills it was asked for', () async {
      await create(['acme_admin', '--no-pub', '--skills', 'claude,cursor']);

      expect(out.toString(), contains('beak agents --skills claude,cursor'));
    });

    test('--no-pub --no-example starts from make:resource', () async {
      await create(['acme_admin', '--no-pub', '--no-example']);

      final String next = out.toString().split('  next:').last;
      expect(
        next.indexOf('beak prepare'),
        lessThan(next.indexOf('beak make:resource')),
      );
      expect(
        next.indexOf('beak make:resource'),
        lessThan(next.indexOf('beak migrate')),
      );
    });
  });

  group('--skills', () {
    late AgentsFixture fixture;

    setUp(() {
      fixture = AgentsFixture()
        ..writeBundle()
        ..writeSkill('beak', 'beak-add-resource');
    });

    /// Creates `acme_admin` under the fixture, resolving as `pub get` would.
    Future<int> createResolved(List<String> args) => create(
      ['acme_admin', ...args],
      at: fixture.tmp,
      whenPubGet: (_) =>
          fixture.resolve(['beak', 'beak_core'], workspaceRoot: 'acme_admin'),
    );

    bool installed(String folder) => File(
      '${fixture.tmp.path}/acme_admin/$folder/skills/beak-add-resource/SKILL.md',
    ).existsSync();

    test('installs into the usual agent folders when not asked', () async {
      expect(await createResolved([]), 0);

      expect(installed('.claude'), isTrue);
      expect(installed('.agents'), isTrue);
      expect(installed('.cursor'), isFalse);
    });

    test('installs only where it is told to', () async {
      expect(await createResolved(['--skills', 'cursor']), 0);

      expect(installed('.cursor'), isTrue);
      expect(installed('.claude'), isFalse);
      expect(installed('.agents'), isFalse);
    });

    test('takes several, comma separated', () async {
      await createResolved(['--skills', 'claude,cursor']);

      expect(installed('.claude'), isTrue);
      expect(installed('.cursor'), isTrue);
      expect(installed('.agents'), isFalse);
    });

    test('none installs no skills', () async {
      expect(await createResolved(['--skills', 'none']), 0);

      expect(installed('.claude'), isFalse);
      expect(installed('.agents'), isFalse);
      expect(installed('.cursor'), isFalse);
    });

    test('rejects a target it does not know', () {
      expect(
        create(['acme_admin', '--skills', 'claude,vim']),
        throwsA(isA<UsageException>()),
      );
    });
  });

  group('dependencies', () {
    test('default to git, so a project resolves anywhere', () async {
      await create(['acme_admin']);
      final pubspec = read('acme_admin/pubspec.yaml');
      expect(pubspec, contains('github.com/SimonErich/beak.git'));
      // Pinned to the release this CLI belongs to, so a scaffold does not
      // silently track whatever the default branch holds today.
      expect(pubspec, contains('ref: $beakReleaseRef'));
      expect(beakReleaseRef, 'v$beakCliVersion');
      for (final package in CreateCommand.beakPackages) {
        expect(pubspec, contains('  $package:'));
      }
      // One line, not five: the umbrella re-exports the panel, the server,
      // the migration DSL, the testing toolkit and obers_ui.
      expect(CreateCommand.beakPackages, ['beak']);
      expect(pubspec, isNot(contains('obers_ui:')));
    });

    test('--beak-path points at a local checkout instead', () async {
      await create(['acme_admin', '--beak-path', '/opt/beak']);
      final pubspec = read('acme_admin/pubspec.yaml');
      expect(pubspec, contains('path: /opt/beak/packages/beak'));
      expect(pubspec, isNot(contains('github.com/SimonErich/beak.git')));
      expect(pubspec, isNot(contains('ref:')));
    });

    test('--beak-path is written absolute, because the pubspec is one level '
        'below where it was typed', () async {
      await create(['acme_admin', '--beak-path', '../beak']);

      final String expected = p.normalize(p.join(root.path, '../beak'));
      expect(
        read('acme_admin/pubspec.yaml'),
        contains('path: $expected/packages/beak'),
      );
    });

    test(
      '--beak-path with characters YAML reads differently is quoted',
      () async {
        await create(['acme_admin', '--beak-path', '/opt/my beak: #1']);

        final beak =
            (loadYaml(read('acme_admin/pubspec.yaml'))
                    as YamlMap)['dependencies']
                as YamlMap;
        expect(
          (beak['beak'] as YamlMap)['path'],
          '/opt/my beak: #1/packages/beak',
        );
      },
    );

    test('--beak-ref pins another ref', () async {
      await create(['acme_admin', '--beak-ref', 'main']);

      final pubspec = read('acme_admin/pubspec.yaml');
      expect(pubspec, contains('ref: main'));
      expect(pubspec, isNot(contains('ref: $beakReleaseRef')));
    });
  });

  group('docs', () {
    String agents() => CreateCommand.scaffoldFiles(
      'acme_admin',
    ).firstWhere((file) => file.path.endsWith('AGENTS.md')).contents;

    String readme() => CreateCommand.postScaffoldFiles(
      'acme_admin',
    ).firstWhere((file) => file.path.endsWith('README.md')).contents;

    test('the README describes what beak dev actually does', () {
      // `beak dev` serves the API and prints the `flutter run` line; it
      // never served a panel on :3000.
      expect(readme(), isNot(contains('3000')));
      expect(readme(), contains('flutter run'));
      expect(readme(), contains('beak migrate'));
      expect(readme(), contains('lib/resources/<plural>/models/'));
    });

    test('AGENTS.md shows field references, not column constants', () {
      expect(agents(), isNot(contains('NoteColumns')));
      expect(
        agents(),
        contains('Reference fields through the generated model'),
      );
      expect(agents(), contains('`ProductModel.name`'));
      expect(agents(), contains('serves the API only'));
      expect(agents(), contains('flutter run'));
    });

    test('both say how to switch to an authored entrypoint', () {
      expect(agents(), contains('beak eject main'));
      expect(readme(), contains('beak eject main'));
    });
  });

  group('the agent files', () {
    test(
      'AGENTS.md is the new-file template around the standalone block',
      () async {
        await create(['acme_admin']);

        final String agents = read('acme_admin/AGENTS.md');
        expect(
          agents,
          startsWith('# Acme Admin\n\n<!-- BEGIN:beak-agent-rules -->\n'),
        );
        expect(agents, contains('This is a Beak $beakCliVersion admin panel'));
        expect(agents, contains('`.dart_tool/beak/docs/ai-index.md`'));
        expect(agents, contains('`lib/resources/*/models/*.dart`'));
        expect(agents, contains('`lib/main.dart` is generated'));
        expect(agents, contains('<!-- END:beak-agent-rules -->'));
        expect(agents, contains('## This project'));
        expect(agents, isNot(contains('lib/screens')));
      },
    );

    test('CLAUDE.md imports it', () async {
      await create(['acme_admin']);

      expect(read('acme_admin/CLAUDE.md'), '@AGENTS.md\n');
    });

    test(
      'an authored project says lib/main.dart is where resources are registered',
      () async {
        await create(['acme_admin', '--authored']);

        final String agents = read('acme_admin/AGENTS.md');
        expect(
          agents,
          contains('`lib/main.dart` registers each `BeakResource`'),
        );
        expect(agents, isNot(contains('is generated')));
      },
    );

    test('the refresh after the scaffold finds them current', () async {
      await create(['acme_admin']);

      expect(
        out.toString(),
        contains('  agents     up to date · docs not materialized: '),
      );
      expect(out.toString(), contains('flutter pub get'));
    });

    test('beak agents --check then agrees, in both variants', () async {
      for (final variant in [
        const <String>[],
        const ['--authored'],
      ]) {
        root.listSync().forEach((entity) => entity.deleteSync(recursive: true));
        await create(['acme_admin', ...variant]);
        final probe = BeakCliEnvironment(
          out: StringBuffer(),
          rootDirectory: Directory('${root.path}/acme_admin'),
          now: () => DateTime.utc(2026, 7, 26, 12),
          probe: (host, port) async => false,
        );

        expect(
          await createBeakRunner(probe).run(['agents', '--check']),
          0,
          reason: variant.join(' '),
        );
      }
    });
  });

  group('usage', () {
    test('rejects a missing or extra name', () {
      expect(create([]), throwsA(isA<UsageException>()));
      expect(create(['a', 'b']), throwsA(isA<UsageException>()));
    });

    test('rejects a ref for a dependency that is not git', () {
      // A local checkout replaces the git dependency, so the ref would
      // silently mean nothing.
      expect(
        create([
          'acme_admin',
          '--beak-path',
          '/opt/beak',
          '--beak-ref',
          'main',
        ]),
        throwsA(isA<UsageException>()),
      );
    });

    test('rejects a name that is not a Dart package name', () {
      expect(create(['AcmeAdmin']), throwsA(isA<UsageException>()));
      expect(create(['acme-admin']), throwsA(isA<UsageException>()));
      expect(create(['1acme']), throwsA(isA<UsageException>()));
    });

    test('rejects a name pub would refuse or that collides with a '
        'dependency of the scaffold', () async {
      // `name: beak` depending on `beak` is a self-dependency, and a Dart
      // keyword is not a package name; neither is worth writing files for.
      for (final name in ['beak', 'flutter', 'flutter_test', 'class', 'if']) {
        await expectLater(
          create([name]),
          throwsA(
            isA<UsageException>().having(
              (error) => error.message,
              'message',
              contains('"$name"'),
            ),
          ),
          reason: name,
        );
      }
      expect(root.listSync(), isEmpty);
    });
  });

  group('scaffoldFiles is pure', () {
    test('so the scaffold can be asserted without a file system', () {
      final files = CreateCommand.scaffoldFiles('acme_admin');
      expect(files.map((file) => file.path), contains('acme_admin/beak.yaml'));
      expect(
        files.firstWhere((file) => file.path.endsWith('AGENTS.md')).contents,
        contains('Reference fields through the generated model'),
      );
    });
  });
}
