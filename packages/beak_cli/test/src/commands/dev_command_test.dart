import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';

const String noteModel = '''
import 'package:beak_core/beak_core.dart';

final class NoteModel extends BeakModel {
  const NoteModel();
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [];
}
''';

const String brokenModel = '''
import 'package:beak_core/beak_core.dart';

final class BrokenModel extends BeakModel {
  BrokenModel(this.table);
  @override
  final String table;
}
''';

void main() {
  late Directory root;
  late StringBuffer out;
  late List<List<String>> spawned;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_dev_');
    addTearDown(() => root.deleteSync(recursive: true));
    File(
      '${root.path}/pubspec.yaml',
    ).writeAsStringSync('name: acme_admin\ndependencies:\n  beak: any\n');
    File('${root.path}/lib/models/note.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(noteModel);
    out = StringBuffer();
    spawned = [];
  });

  BeakCliEnvironment environment({
    int exitCode = 0,
    Map<String, String> processEnvironment = const {},
  }) => BeakCliEnvironment(
    out: out,
    rootDirectory: root,
    now: () => DateTime.utc(2026, 7, 26, 12),
    probe: (host, port) async => false,
    processEnvironment: processEnvironment,
    runProcess: (executable, arguments, {workingDirectory}) async {
      spawned.add([executable, ...arguments]);
      return exitCode;
    },
  );

  Future<int> run(
    List<String> args, {
    int exitCode = 0,
    Map<String, String> processEnvironment = const {},
  }) async =>
      await createBeakRunner(
        environment(exitCode: exitCode, processEnvironment: processEnvironment),
      ).run(args) ??
      0;

  group('dev', () {
    test('regenerates, then serves the API', () async {
      expect(await run(['dev']), 0);
      expect(
        File('${root.path}/lib/beak/registry.g.dart').existsSync(),
        isTrue,
      );
      expect(spawned.single, ['dart', 'run', 'bin/serve.dart']);
    });

    test('prints the flutter run line rather than proxying it', () async {
      await run(['dev', '-d', 'linux']);
      expect(out.toString(), contains('flutter run -d linux'));
    });

    test('--no-serve only regenerates', () async {
      expect(await run(['dev', '--no-serve']), 0);
      expect(spawned, isEmpty);
      expect(File('${root.path}/lib/main.dart').existsSync(), isTrue);
    });

    test('a generation failure stops before spawning anything', () async {
      File(
        '${root.path}/lib/models/broken.dart',
      ).writeAsStringSync(brokenModel);
      expect(await run(['dev']), 1);
      expect(spawned, isEmpty);
      expect(out.toString(), contains('Cannot generate'));
    });

    test('surfaces the server exit code', () async {
      expect(await run(['dev'], exitCode: 70), 70);
    });
  });

  group('migrate', () {
    test('regenerates, then runs the migrations', () async {
      expect(await run(['migrate']), 0);
      expect(spawned.single, ['dart', 'run', 'bin/migrate.dart', 'migrate']);
    });

    const verbs = {
      'up': 'migrate',
      'status': 'migrate:status',
      'down': 'migrate:rollback',
      'fresh': 'migrate:fresh',
      'refresh': 'migrate:refresh',
    };
    for (final MapEntry(key: verb, value: subcommand) in verbs.entries) {
      test('beak migrate $verb runs worm $subcommand', () async {
        expect(await run(['migrate', verb]), 0);
        expect(spawned.single, ['dart', 'run', 'bin/migrate.dart', subcommand]);
      });
    }

    test('forwards the flags of the verb it maps', () async {
      await run(['migrate', '--pretend']);
      await run(['migrate', '--step', '3']);
      await run(['migrate', 'down', '--steps=2']);
      await run(['migrate', 'fresh', '--seed', '--force']);
      expect(spawned.map((command) => command.skip(3).join(' ')), [
        'migrate --pretend',
        'migrate --step=3',
        'migrate:rollback --steps=2',
        'migrate:fresh --seed --force',
      ]);
    });

    const misplaced = <(List<String>, String, String)>[
      (['migrate', 'up', '--steps', '2'], '--steps', 'down'),
      (['migrate', '--steps', '2'], '--steps', 'down'),
      (['migrate', 'down', '--pretend'], '--pretend', 'up'),
      (['migrate', 'down', '--step', '1'], '--step', 'up'),
      (['migrate', 'status', '--seed'], '--seed', 'fresh'),
      (['migrate', 'refresh', '--seed'], '--seed', 'fresh'),
      (['migrate', 'up', '--force'], '--force', 'fresh'),
    ];
    for (final (arguments, flag, home) in misplaced) {
      test('refuses ${arguments.skip(1).join(' ')} as a usage error, before '
          'worm can', () async {
        // Forwarded, these reached worm, which refused with its own usage
        // and exit 2 instead of Beak's 64.
        await expectLater(
          run(arguments),
          throwsA(
            isA<UsageException>().having(
              (error) => error.message,
              'message',
              allOf(contains(flag), contains('beak migrate $home')),
            ),
          ),
        );
        expect(spawned, isEmpty);
      });
    }

    test('names every flag a verb takes when it refuses one', () async {
      await expectLater(
        run(['migrate', 'status', '--pretend']),
        throwsA(
          isA<UsageException>().having(
            (error) => error.message,
            'message',
            contains('`beak migrate status`, which takes no flags'),
          ),
        ),
      );
      await expectLater(
        run(['migrate', 'up', '--seed']),
        throwsA(
          isA<UsageException>().having(
            (error) => error.message,
            'message',
            contains('`beak migrate up`, which takes --pretend, --step'),
          ),
        ),
      );
    });

    group('WORM_ENV=production', () {
      // Worm reads WORM_ENV from the process alone, so a production marker
      // that lives in .env, where the server reads it, armed nothing.
      void inDotenv(String value) =>
          File('${root.path}/.env').writeAsStringSync('WORM_ENV=$value\n');

      for (final verb in ['fresh', 'refresh']) {
        test('in .env refuses migrate $verb without --force', () async {
          inDotenv('production');

          expect(await run(['migrate', verb]), 1);

          expect(spawned, isEmpty);
          expect(
            out.toString(),
            contains(
              'error: refusing to run destructive command in production '
              'without --force',
            ),
          );
        });

        test('in .env lets migrate $verb through with --force', () async {
          inDotenv('production');

          expect(await run(['migrate', verb, '--force']), 0);

          expect(spawned.single, [
            'dart',
            'run',
            'bin/migrate.dart',
            'migrate:$verb',
            '--force',
          ]);
        });
      }

      test('is read whatever its case', () async {
        inDotenv('Production');

        expect(await run(['migrate', 'fresh']), 1);
      });

      test('from the shell is refused the same way', () async {
        expect(
          await run(
            ['migrate', 'fresh'],
            processEnvironment: {'WORM_ENV': 'production'},
          ),
          1,
        );
        expect(spawned, isEmpty);
      });

      test('a shell value beats the .env', () async {
        inDotenv('production');

        expect(
          await run(
            ['migrate', 'fresh'],
            processEnvironment: {'WORM_ENV': 'development'},
          ),
          0,
        );
      });

      test('leaves the verbs that destroy nothing alone', () async {
        inDotenv('production');

        for (final verb in ['up', 'status', 'down']) {
          expect(await run(['migrate', verb]), 0, reason: verb);
        }
      });

      test('is no reason to stop when it is not production', () async {
        inDotenv('staging');

        expect(await run(['migrate', 'fresh']), 0);
      });
    });

    test('passes what follows -- to the worm subcommand untouched', () async {
      await run(['migrate', 'status', '--', '--some-flag', 'value']);
      await run(['migrate', '--', '--pretend']);
      expect(spawned.map((command) => command.skip(3).join(' ')), [
        'migrate:status --some-flag value',
        'migrate --pretend',
      ]);
    });

    test('refuses a verb it does not know, before running anything', () async {
      await expectLater(
        run(['migrate', 'statsu']),
        throwsA(
          isA<UsageException>().having(
            (error) => error.message,
            'message',
            allOf(contains('statsu'), contains('status')),
          ),
        ),
      );
      expect(spawned, isEmpty);
    });

    test('refuses more than one verb', () async {
      await expectLater(
        run(['migrate', 'up', 'down']),
        throwsA(isA<UsageException>()),
      );
      expect(spawned, isEmpty);
    });

    test('hands the terminal to the migrations, not a captured run', () async {
      final interactive = <List<String>>[];
      final captured = <List<String>>[];
      final BeakCliEnvironment split = BeakCliEnvironment(
        out: out,
        rootDirectory: root,
        now: () => DateTime.utc(2026, 7, 26, 12),
        probe: (host, port) async => false,
        runProcess: (executable, arguments, {workingDirectory}) async {
          captured.add([executable, ...arguments]);
          return 0;
        },
        runInteractive: (executable, arguments, {workingDirectory}) async {
          interactive.add([executable, ...arguments]);
          return 0;
        },
      );
      await createBeakRunner(split).run(['migrate', 'status']);
      await createBeakRunner(split).run(['seed']);
      await createBeakRunner(split).run(['dev']);
      expect(captured, isEmpty);
      expect(interactive.map((command) => command.skip(2).join(' ')), [
        'bin/migrate.dart migrate:status',
        'bin/migrate.dart db:seed',
        'bin/serve.dart',
      ]);
    });

    test('surfaces the exit code of the migrations', () async {
      expect(await run(['migrate', 'status'], exitCode: 2), 2);
    });

    test('a generation failure stops before spawning anything', () async {
      File(
        '${root.path}/lib/models/broken.dart',
      ).writeAsStringSync(brokenModel);
      expect(await run(['migrate']), 1);
      expect(spawned, isEmpty);
    });
  });

  group('seed', () {
    test('delegates to db:seed', () async {
      expect(await run(['seed']), 0);
      expect(spawned.single, ['dart', 'run', 'bin/migrate.dart', 'db:seed']);
    });

    test('forwards its flags', () async {
      await run(['seed', '--class', 'UserSeeder', '--force', '--env=dev']);
      expect(
        spawned.single.skip(3).join(' '),
        'db:seed --class=UserSeeder '
        '--env=dev --force',
      );
    });

    test('passes what follows -- to db:seed untouched', () async {
      await run(['seed', '--', '--anything']);
      expect(spawned.single.skip(3).join(' '), 'db:seed --anything');
    });

    test('takes no positional argument', () async {
      await expectLater(
        run(['seed', 'UserSeeder']),
        throwsA(isA<UsageException>()),
      );
      expect(spawned, isEmpty);
    });

    test('surfaces the exit code of the seeders', () async {
      expect(await run(['seed'], exitCode: 1), 1);
    });

    test('a generation failure stops before spawning anything', () async {
      File(
        '${root.path}/lib/models/broken.dart',
      ).writeAsStringSync(brokenModel);
      expect(await run(['seed']), 1);
      expect(spawned, isEmpty);
    });
  });

  group('the production runners', () {
    late File script;

    setUp(() {
      script = File('${root.path}/exit_with.dart')
        ..writeAsStringSync(
          "import 'dart:io';\n"
          'void main(List<String> args) => exit(int.parse(args.single));\n',
        );
    });

    final BeakCliEnvironment production = BeakCliEnvironment.production();
    for (final (label, runner) in [
      ('runProcess', production.runProcess),
      ('runInteractive', production.runInteractive),
    ]) {
      test('$label returns the exit code of the process', () async {
        expect(
          await runner(Platform.resolvedExecutable, [
            script.path,
            '7',
          ], workingDirectory: root.path),
          7,
        );
      });
    }
  });
}
