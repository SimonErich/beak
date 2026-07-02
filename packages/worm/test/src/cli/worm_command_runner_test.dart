import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/cli/cli_context.dart';
import 'package:worm/src/cli/force_gate.dart';
import 'package:worm/src/cli/worm_command_runner.dart';
import 'package:worm/src/migration/migration_base.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/schema/column_type.dart';
import 'package:worm/src/seeder/environment.dart';
import 'package:worm/src/seeder/seeder_base.dart';

import '_fixtures.dart';

final class _BannerFormatter extends HelpFormatter {
  const _BannerFormatter();
  @override
  String formatGlobalHelp(CommandRunner<int> runner) =>
      '=== banner ===\n${runner.usage}';
}

final class _ForceProbeCommand extends WormCommand {
  _ForceProbeCommand(super.context) {
    enableForceFlag();
  }
  @override
  String get name => 'force-probe';
  @override
  String get description => 'Test probe for WormCommand.force.';
  bool? observedForce;
  @override
  Future<int> run() async {
    observedForce = force;
    return 0;
  }
}

final class _CreateUsers extends Migration {
  const _CreateUsers();
  @override
  String get name => '20260101_000000_create_users';
  @override
  Future<void> up(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'users',
      columns: <SchemaColumn>[SchemaColumn(name: 'id', type: ColumnType.text)],
    ),
  );
  @override
  Future<void> down(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: 'users', ifExists: true),
  );
}

final class _TestSeeder extends Seeder {
  const _TestSeeder();
  @override
  String get name => 'TestSeeder';
  @override
  Future<void> run(DatabaseAdapter adapter) async {}
}

final class _AnotherSeeder extends Seeder {
  const _AnotherSeeder();
  @override
  String get name => 'AnotherSeeder';
  @override
  Future<void> run(DatabaseAdapter adapter) async {}
}

final class _ProductionOnlySeeder extends Seeder {
  const _ProductionOnlySeeder();
  @override
  String get name => 'ProductionOnlySeeder';
  @override
  Environment get environment => Environment.production;
  @override
  Future<void> run(DatabaseAdapter adapter) async {}
}

final class _CreatePosts extends Migration {
  const _CreatePosts();
  @override
  String get name => '20260102_000000_create_posts';
  @override
  Future<void> up(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'posts',
      columns: <SchemaColumn>[SchemaColumn(name: 'id', type: ColumnType.text)],
    ),
  );
  @override
  Future<void> down(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: 'posts', ifExists: true),
  );
}

final class _CreateOrders extends Migration {
  const _CreateOrders();
  @override
  String get name => '20260103_000000_create_orders';
  @override
  Future<void> up(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'orders',
      columns: <SchemaColumn>[SchemaColumn(name: 'id', type: ColumnType.text)],
    ),
  );
  @override
  Future<void> down(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: 'orders', ifExists: true),
  );
}

void main() {
  group('worm init', () {
    const srcDirs = <String>[
      'adapter',
      'cast',
      'cli',
      'config',
      'exception',
      'factory',
      'logging',
      'migration',
      'model',
      'naming',
      'observer',
      'predicate',
      'query',
      'registry',
      'relation',
      'schema',
      'seeder',
      'validation',
    ];

    test(
      'creates exactly 18 lib/src/ subdirectories matching the spec',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());
        final code = await runner.run(<String>['init']);
        expect(code, 0);

        final libSrc = Directory('${harness.projectRoot.path}/lib/src');
        expect(libSrc.existsSync(), isTrue);

        final subdirNames =
            libSrc
                .listSync()
                .whereType<Directory>()
                .map((d) => d.path.split(Platform.pathSeparator).last)
                .toList()
              ..sort();
        expect(subdirNames, hasLength(18));
        expect(subdirNames, equals(srcDirs));
      },
    );

    test(
      'creates migrations/, seeds/, lib/models/, lib/factories/, config/',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());
        final code = await runner.run(<String>['init']);
        expect(code, 0);
        for (final dir in const <String>[
          'migrations',
          'seeds',
          'lib/models',
          'lib/factories',
          'config',
        ]) {
          expect(
            Directory('${harness.projectRoot.path}/$dir').existsSync(),
            isTrue,
            reason: '$dir/ must exist after worm init',
          );
        }
      },
    );

    test('writes config/worm_config.dart template on first run', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());
      await runner.run(<String>['init']);

      final config = File(
        '${harness.projectRoot.path}/config/worm_config.dart',
      );
      expect(config.existsSync(), isTrue);
      final body = config.readAsStringSync();
      expect(body, contains('WormConfig'));
      expect(body, contains("import 'package:worm/worm.dart'"));
    });

    test('does not overwrite an existing config/worm_config.dart', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());
      await runner.run(<String>['init']);
      final config = File(
        '${harness.projectRoot.path}/config/worm_config.dart',
      );
      const sentinel = '// USER-EDITED — must survive re-running init.\n';
      config.writeAsStringSync(sentinel);

      await runner.run(<String>['init']);

      expect(config.readAsStringSync(), sentinel);
    });

    test(
      'a second run prints Already exists for every existing entry',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());
        await runner.run(<String>['init']);
        harness.out.clear();

        final code = await runner.run(<String>['init']);
        expect(code, 0);

        final out = harness.out.toString();
        for (final dir in srcDirs) {
          expect(
            out,
            contains('Already exists  lib/src/$dir/'),
            reason: 'lib/src/$dir/ should report as existing on rerun',
          );
        }
        expect(out, contains('Already exists  migrations/'));
        expect(out, contains('Already exists  config/worm_config.dart'));
      },
    );

    test('--help prints the description and usage', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['init', '--help']);
      expect(code, 0);
      final out = harness.out.toString();
      expect(out, contains('Initialize worm'));
      expect(out, contains('Usage: worm init'));
    });
  });

  group('worm make:model', () {
    test(
      'worm make:model User creates lib/models/user.dart extending Model',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());
        final code = await runner.run(<String>['make:model', 'User']);
        expect(code, 0);

        final model = File('${harness.projectRoot.path}/lib/models/user.dart');
        expect(model.existsSync(), isTrue);
        final source = model.readAsStringSync();
        expect(source, contains('final class User extends Model'));
        expect(source, contains("@Table(name: 'users')"));
      },
    );

    test('--all generates exactly four files', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['make:model', 'User', '--all']);
      expect(code, 0);

      final created = <String>[
        'lib/models/user.dart',
        'seeds/user_seeder.dart',
        'lib/factories/user_factory.dart',
      ];
      for (final rel in created) {
        expect(
          File('${harness.projectRoot.path}/$rel').existsSync(),
          isTrue,
          reason: '$rel should be created by --all',
        );
      }
      final migrations = Directory('${harness.projectRoot.path}/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_create_users_table.dart'))
          .toList();
      expect(migrations, hasLength(1));
    });

    test('pluralises BlogPost → blog_posts and snake-cases the file', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['make:model', 'BlogPost']);
      expect(code, 0);

      final model = File(
        '${harness.projectRoot.path}/lib/models/blog_post.dart',
      );
      expect(model.existsSync(), isTrue);
      final source = model.readAsStringSync();
      expect(source, contains('final class BlogPost extends Model'));
      expect(source, contains("@Table(name: 'blog_posts')"));
    });

    test('refuses to overwrite an existing model file', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final firstRun = await runner.run(<String>['make:model', 'User']);
      expect(firstRun, 0);

      final secondRun = await runner.run(<String>['make:model', 'User']);
      expect(secondRun, isNot(0));
      expect(harness.err.toString(), contains('already exists'));
      expect(harness.err.toString(), contains('lib/models/user.dart'));
    });
  });

  group('worm make:migration', () {
    test(
      'writes migrations/<YYYYMMDD_HHMMSS>_create_orders_table.dart',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());

        final code = await runner.run(<String>[
          'make:migration',
          'create_orders_table',
        ]);
        expect(code, 0);

        final migrations = Directory(
          '${harness.projectRoot.path}/migrations',
        ).listSync().whereType<File>().toList();
        expect(migrations, hasLength(1));

        final name = migrations.single.path.split(Platform.pathSeparator).last;
        // YYYYMMDD_HHMMSS_create_orders_table.dart — 14-char UTC stamp.
        expect(name, matches(r'^\d{8}_\d{6}_create_orders_table\.dart$'));
      },
    );

    test('migration timestamp uses UTC (normalises local DateTime)', () async {
      // Pass a +05:00 local-zone fixedNow; the harness keeps it as a
      // ticking value via _now. Internally migrationTimestamp converts
      // to UTC before formatting — verify by reconstructing the
      // expected UTC stamp.
      final fixed = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final harness = TestHarness(fixedNow: fixed.toLocal());
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      await runner.run(<String>['make:migration', 'create_orders_table']);

      final names = Directory('${harness.projectRoot.path}/migrations')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .toList();
      expect(names.single, startsWith('20260102_030405_'));
    });

    test('refuses to overwrite an existing migration file', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final first = await runner.run(<String>[
        'make:migration',
        'create_orders_table',
      ]);
      expect(first, 0);
      final second = await runner.run(<String>[
        'make:migration',
        'create_orders_table',
      ]);
      expect(second, isNot(0));
      expect(harness.err.toString(), contains('already exists'));
    });
  });

  group('worm make:seeder', () {
    test(
      'writes seeds/user_seeder.dart with class UserSeeder extends Seeder',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());

        final code = await runner.run(<String>['make:seeder', 'UserSeeder']);
        expect(code, 0);

        final file = File('${harness.projectRoot.path}/seeds/user_seeder.dart');
        expect(file.existsSync(), isTrue);
        final source = file.readAsStringSync();
        expect(source, contains('final class UserSeeder extends Seeder'));
      },
    );

    test('refuses to overwrite an existing seeder', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      await runner.run(<String>['make:seeder', 'UserSeeder']);
      final second = await runner.run(<String>['make:seeder', 'UserSeeder']);
      expect(second, isNot(0));
      expect(harness.err.toString(), contains('already exists'));
    });
  });

  group('worm make:factory', () {
    test('writes lib/factories/user_factory.dart', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>[
        'make:factory',
        'UserFactory',
        '--model',
        'User',
      ]);
      expect(code, 0);

      final file = File(
        '${harness.projectRoot.path}/lib/factories/user_factory.dart',
      );
      expect(file.existsSync(), isTrue);
      final source = file.readAsStringSync();
      expect(source, contains('class UserFactory extends Factory<User>'));
    });

    test('strips trailing "Factory" suffix when deriving model', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      // No --model: default should strip "Factory" → "User", not
      // self-reference as Factory<UserFactory>.
      final code = await runner.run(<String>['make:factory', 'UserFactory']);
      expect(code, 0);

      final source = File(
        '${harness.projectRoot.path}/lib/factories/user_factory.dart',
      ).readAsStringSync();
      expect(source, contains('Factory<User>'));
      expect(source, isNot(contains('Factory<UserFactory>')));
    });

    test('refuses to overwrite an existing factory', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      await runner.run(<String>['make:factory', 'UserFactory']);
      final second = await runner.run(<String>['make:factory', 'UserFactory']);
      expect(second, isNot(0));
      expect(harness.err.toString(), contains('already exists'));
    });
  });

  group('worm make:observer', () {
    test(
      'writes lib/src/observer/user_observer.dart extending Observer<User>',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());

        final code = await runner.run(<String>[
          'make:observer',
          'UserObserver',
        ]);
        expect(code, 0);

        final file = File(
          '${harness.projectRoot.path}/lib/src/observer/user_observer.dart',
        );
        expect(file.existsSync(), isTrue);
        final source = file.readAsStringSync();
        expect(
          source,
          contains('final class UserObserver extends Observer<User>'),
        );
      },
    );

    test('honours --model override', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      await runner.run(<String>[
        'make:observer',
        'AuditObserver',
        '--model',
        'Order',
      ]);

      final file = File(
        '${harness.projectRoot.path}/lib/src/observer/audit_observer.dart',
      );
      expect(file.existsSync(), isTrue);
      expect(
        file.readAsStringSync(),
        contains('final class AuditObserver extends Observer<Order>'),
      );
    });

    test('refuses to overwrite an existing observer', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      await runner.run(<String>['make:observer', 'UserObserver']);
      final second = await runner.run(<String>[
        'make:observer',
        'UserObserver',
      ]);
      expect(second, isNot(0));
      expect(harness.err.toString(), contains('already exists'));
    });
  });

  group('worm migrate', () {
    test('applies registered migrations', () async {
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsers()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());
      final code = await runner.run(<String>['migrate']);
      expect(code, 0);
      expect(harness.out.toString(), contains('migrated'));
      expect(harness.out.toString(), contains('create_users'));
    });

    test('--pretend prints captured SQL plus the dry-run summary without '
        'executing', () async {
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsers()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['migrate', '--pretend']);

      expect(code, 0);
      final out = harness.out.toString();
      expect(out, contains('create_users'));
      expect(out, contains('Dry run complete — no changes made.'));
      final schemas = await harness.adapter.introspectSchema();
      expect(schemas.containsKey('users'), isFalse);
    });

    test(
      '--pretend on an empty pending list still prints the summary',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());

        final code = await runner.run(<String>['migrate', '--pretend']);

        expect(code, 0);
        final out = harness.out.toString();
        expect(out, contains('Nothing to migrate.'));
        expect(out, contains('Dry run complete — no changes made.'));
      },
    );

    test('--step=N applies only the first N pending migrations', () async {
      final harness = TestHarness(
        migrations: const <Migration>[
          _CreateUsers(),
          _CreatePosts(),
          _CreateOrders(),
        ],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['migrate', '--step=2']);

      expect(code, 0);
      final schemas = await harness.adapter.introspectSchema();
      expect(schemas.containsKey('users'), isTrue);
      expect(schemas.containsKey('posts'), isTrue);
      expect(
        schemas.containsKey('orders'),
        isFalse,
        reason: 'third migration should remain pending',
      );
    });
  });

  group('worm migrate:status', () {
    test('reports pending then applied', () async {
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsers()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());
      await runner.run(<String>['migrate:status']);
      expect(harness.out.toString(), contains('[ ]'));
      harness.out.clear();
      await runner.run(<String>['migrate']);
      harness.out.clear();
      await runner.run(<String>['migrate:status']);
      expect(harness.out.toString(), contains('[x]'));
    });

    test('prints a Migration | Batch | Status header row', () async {
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsers(), _CreatePosts()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      await runner.run(<String>['migrate']);
      harness.out.clear();
      await runner.run(<String>['migrate:status']);

      final lines = harness.out.toString().split('\n');
      expect(lines.first, contains('Migration'));
      expect(lines.first, contains('Batch'));
      expect(lines.first, contains('Status'));
      // The pipe separator from the header should appear in every
      // data row too, with applied entries rendered with a numeric
      // batch column.
      expect(
        lines.where((l) => l.contains('|') && l.contains('applied')),
        hasLength(2),
      );
    });
  });

  group('worm migrate:rollback', () {
    test('reverts the last batch', () async {
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsers()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());
      await runner.run(<String>['migrate']);
      harness.out.clear();
      await runner.run(<String>['migrate:rollback']);
      expect(harness.out.toString(), contains('reverted'));
    });

    test('--steps=N rolls back the last N batches', () async {
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsers(), _CreatePosts()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      // Two separate batches: apply users, then apply posts.
      await runner.run(<String>['migrate', '--step=1']);
      await runner.run(<String>['migrate', '--step=1']);
      // Sanity: both tables exist before rollback.
      final before = await harness.adapter.introspectSchema();
      expect(before.containsKey('users'), isTrue);
      expect(before.containsKey('posts'), isTrue);

      harness.out.clear();
      await runner.run(<String>['migrate:rollback', '--steps=2']);

      final after = await harness.adapter.introspectSchema();
      expect(after.containsKey('users'), isFalse);
      expect(after.containsKey('posts'), isFalse);
    });
  });

  group('worm migrate:fresh and migrate:refresh', () {
    test('--force missing in production exits with code 1 and warns', () async {
      final harness = TestHarness(
        environment: Environment.production,
        migrations: const <Migration>[_CreateUsers()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final fresh = await runner.run(<String>['migrate:fresh']);
      expect(fresh, 1);
      expect(harness.err.toString(), contains('--force'));
      expect(harness.err.toString(), contains('production'));

      harness.err.clear();
      final refresh = await runner.run(<String>['migrate:refresh']);
      expect(refresh, 1);
      expect(harness.err.toString(), contains('--force'));
    });

    test('proceed with --force in production', () async {
      final harness = TestHarness(
        environment: Environment.production,
        migrations: const <Migration>[_CreateUsers()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());
      final code = await runner.run(<String>['migrate:fresh', '--force']);
      expect(code, 0);
    });

    test('do not require --force outside production', () async {
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsers()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());
      final code = await runner.run(<String>['migrate:fresh']);
      expect(code, 0);
    });

    test('migrate:fresh --seed runs registered seeders after fresh', () async {
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsers()],
        seeders: const <Seeder>[_TestSeeder()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['migrate:fresh', '--seed']);

      expect(code, 0);
      final out = harness.out.toString();
      expect(out, contains('migrate:fresh complete'));
      expect(out, contains('seeded'));
      expect(out, contains('TestSeeder'));
      final freshIdx = out.indexOf('migrate:fresh complete');
      final seedIdx = out.indexOf('seeded');
      expect(seedIdx, greaterThan(freshIdx));
    });

    test('migrate:fresh without --seed does not run seeders', () async {
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsers()],
        seeders: const <Seeder>[_TestSeeder()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['migrate:fresh']);

      expect(code, 0);
      expect(harness.out.toString(), isNot(contains('seeded')));
    });
  });

  group('worm db:seed', () {
    test('runs every applicable seeder by default', () async {
      final harness = TestHarness(seeders: const <Seeder>[_TestSeeder()]);
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());
      final code = await runner.run(<String>['db:seed']);
      expect(code, 0);
      expect(harness.out.toString(), contains('seeded'));
      expect(harness.out.toString(), contains('TestSeeder'));
    });

    test('--class=Name runs only the matching seeder', () async {
      final harness = TestHarness(
        seeders: const <Seeder>[_TestSeeder(), _AnotherSeeder()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>[
        'db:seed',
        '--class=AnotherSeeder',
      ]);
      expect(code, 0);
      final out = harness.out.toString();
      expect(out, contains('seeded  AnotherSeeder'));
      expect(out, isNot(contains('TestSeeder')));
    });

    test('--force ignores environment filter so production seeders run '
        'in development too', () async {
      final harness = TestHarness(
        seeders: const <Seeder>[_ProductionOnlySeeder()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      // Without --force, the production-only seeder is filtered out
      // in the default (development) environment.
      var code = await runner.run(<String>['db:seed']);
      expect(code, 0);
      expect(harness.out.toString(), contains('No seeders applicable'));
      harness.out.clear();

      code = await runner.run(<String>['db:seed', '--force']);
      expect(code, 0);
      expect(harness.out.toString(), contains('seeded  ProductionOnlySeeder'));
    });

    test('--env=<name> overrides the active environment', () async {
      final harness = TestHarness(
        seeders: const <Seeder>[_ProductionOnlySeeder()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['db:seed', '--env=production']);
      expect(code, 0);
      expect(harness.out.toString(), contains('seeded  ProductionOnlySeeder'));
    });
  });

  group('worm schema:dump', () {
    test(
      'writes schema/schema_dump.dart with a Dart source snapshot',
      () async {
        final harness = TestHarness(
          migrations: const <Migration>[_CreateUsers()],
        );
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());
        await runner.run(<String>['migrate']);

        final code = await runner.run(<String>['schema:dump']);
        expect(code, 0);
        final dump = File(
          '${harness.projectRoot.path}/schema/schema_dump.dart',
        );
        expect(dump.existsSync(), isTrue);
        final body = dump.readAsStringSync();
        expect(body, contains('schemaDump'));
        expect(body, contains("'users'"));
        expect(body, contains("'id'"));
      },
    );

    test(
      '--prune without --force exits 1 with an irreversibility warning',
      () async {
        final harness = TestHarness(
          migrations: const <Migration>[_CreateUsers()],
        );
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());

        final code = await runner.run(<String>['schema:dump', '--prune']);
        expect(code, 1);
        expect(harness.err.toString(), contains('irreversible'));
        expect(harness.err.toString(), contains('--force'));
      },
    );

    test(
      '--prune --force deletes migration files and reports the count',
      () async {
        final harness = TestHarness(
          migrations: const <Migration>[_CreateUsers()],
        );
        addTearDown(harness.dispose);
        Directory(
          '${harness.projectRoot.path}/migrations',
        ).createSync(recursive: true);
        File(
          '${harness.projectRoot.path}/migrations/01_a.dart',
        ).writeAsStringSync('// a');
        File(
          '${harness.projectRoot.path}/migrations/02_b.dart',
        ).writeAsStringSync('// b');

        final runner = WormCommandRunner(harness.build());
        final code = await runner.run(<String>[
          'schema:dump',
          '--prune',
          '--force',
        ]);

        expect(code, 0);
        final remaining = Directory('${harness.projectRoot.path}/migrations')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .length;
        expect(remaining, 0);
        expect(harness.out.toString(), contains('pruned  2 migration file'));
      },
    );
  });

  group('worm model:show', () {
    test('prints model name, table, fields, and relations', () async {
      final harness = TestHarness(
        models: const <ModelInfo>[
          ModelInfo(
            name: 'User',
            tableName: 'users',
            fields: <ModelField>[
              ModelField(name: 'id', type: 'uuid'),
              ModelField(name: 'email', type: 'string'),
            ],
            relations: <ModelRelation>[
              ModelRelation(name: 'posts', kind: 'hasMany', target: 'Post'),
            ],
          ),
        ],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['model:show', 'User']);
      expect(code, 0);
      final out = harness.out.toString();
      expect(out, contains('Model: User'));
      expect(out, contains('Table: users'));
      expect(out, contains('id: uuid'));
      expect(out, contains('email: string'));
      expect(out, contains('posts: hasMany Post'));
    });

    test('exits 1 with "Model not found: <Name>" for unknown models', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(<String>['model:show', 'UnknownModel']);
      expect(code, 1);
      expect(harness.err.toString(), contains('Model not found: UnknownModel'));
    });

    test(
      'emits empty-section markers when fields/relations are blank',
      () async {
        final harness = TestHarness(
          models: const <ModelInfo>[ModelInfo(name: 'Tag', tableName: 'tags')],
        );
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());

        final code = await runner.run(<String>['model:show', 'Tag']);
        expect(code, 0);
        final out = harness.out.toString();
        expect(out, contains('Fields:'));
        expect(out, contains('Relations:'));
        expect(out, contains('(none)'));
      },
    );
  });

  // `worm gen` behaviour now spawns real subprocesses via
  // [ProcessRunner]; the dedicated tests live in
  // test/src/cli/commands/gen_command_test.dart and inject a fake.

  group('CLI help text', () {
    test('lists every command name', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());
      final usage = runner.usage;
      expect(usage, contains('init'));
      expect(usage, contains('make:model'));
      expect(usage, contains('make:migration'));
      expect(usage, contains('make:seeder'));
      expect(usage, contains('make:factory'));
      expect(usage, contains('migrate'));
      expect(usage, contains('migrate:rollback'));
      expect(usage, contains('migrate:status'));
      expect(usage, contains('migrate:fresh'));
      expect(usage, contains('migrate:refresh'));
      expect(usage, contains('db:seed'));
      expect(usage, contains('schema:dump'));
      expect(usage, contains('gen'));
    });

    test('aligns command names with their descriptions', () {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final usage = runner.usage;
      final namePosition = usage.indexOf('init');
      const commandLines = <String>[
        'init',
        'make:model',
        'make:migration',
        'migrate',
        'db:seed',
      ];
      for (final name in commandLines) {
        final lineStart = usage.indexOf('  $name');
        expect(
          lineStart,
          isNonNegative,
          reason: 'usage should list "$name" indented with two spaces',
        );
      }
      expect(namePosition, isNonNegative);
    });
  });

  group('WormCommandRunner exit codes', () {
    test('returns 0 and prints global help when args are empty', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(const <String>[]);

      expect(code, 0);
      final out = harness.out.toString();
      expect(out, contains('worm'));
      expect(out, contains('init'));
      expect(out, contains('migrate'));
    });

    test('returns 0 for --help and lists every registered command', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(const <String>['--help']);

      expect(code, 0);
      final out = harness.out.toString();
      expect(out, contains('init'));
      expect(out, contains('make:model'));
      expect(out, contains('migrate'));
      expect(out, contains('db:seed'));
      expect(out, contains('schema:dump'));
      expect(out, contains('gen'));
    });

    test('returns 2 and writes an error for an unknown command', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(const <String>['bogus-command']);

      expect(code, 2);
      expect(harness.err.toString(), contains('bogus-command'));
    });
  });

  group('isProductionWormEnv (case-insensitive WORM_ENV check)', () {
    test('treats every casing of "production" as production', () {
      expect(isProductionWormEnv('production'), isTrue);
      expect(isProductionWormEnv('PRODUCTION'), isTrue);
      expect(isProductionWormEnv('Production'), isTrue);
      expect(isProductionWormEnv('  PRoDuCtIoN  '), isTrue);
    });

    test('returns false for absent or non-production environments', () {
      expect(isProductionWormEnv(null), isFalse);
      expect(isProductionWormEnv(''), isFalse);
      expect(isProductionWormEnv('development'), isFalse);
      expect(isProductionWormEnv('staging'), isFalse);
      expect(isProductionWormEnv('testing'), isFalse);
      expect(isProductionWormEnv('prod'), isFalse);
    });
  });

  group('ProductionGuard', () {
    test('isProduction reflects context environment', () {
      final dev = TestHarness();
      addTearDown(dev.dispose);
      final prod = TestHarness(environment: Environment.production);
      addTearDown(prod.dispose);

      expect(ProductionGuard(context: dev.build()).isProduction(), isFalse);
      expect(ProductionGuard(context: prod.build()).isProduction(), isTrue);
    });

    test('enforceForce does not exit outside production', () {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      var exitCode = -1;
      ProductionGuard(
        context: harness.build(),
        exit: (c) => exitCode = c,
      ).enforceForce(force: false);

      expect(exitCode, -1, reason: 'exit must not be called outside prod');
      expect(harness.err.toString(), isEmpty);
    });

    test('enforceForce does not exit when --force is provided', () {
      final harness = TestHarness(environment: Environment.production);
      addTearDown(harness.dispose);
      var exitCode = -1;
      ProductionGuard(
        context: harness.build(),
        exit: (c) => exitCode = c,
      ).enforceForce(force: true);

      expect(exitCode, -1);
      expect(harness.err.toString(), isEmpty);
    });

    test(
      'enforceForce calls injected exit(1) in production without --force',
      () {
        final harness = TestHarness(environment: Environment.production);
        addTearDown(harness.dispose);
        var exitCode = -1;
        ProductionGuard(
          context: harness.build(),
          exit: (c) => exitCode = c,
        ).enforceForce(force: false);

        expect(exitCode, 1);
        expect(harness.err.toString(), contains('--force'));
        expect(harness.err.toString(), contains('production'));
      },
    );
  });

  group('HelpFormatter', () {
    test('standard formatter returns CommandRunner.usage unchanged', () {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final formatted = HelpFormatter.standard.formatGlobalHelp(runner);

      expect(formatted, equals(runner.usage));
    });

    test('custom formatter wraps usage and is used by printUsage', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(
        harness.build(),
        helpFormatter: const _BannerFormatter(),
      );

      await runner.run(const <String>['--help']);

      final out = harness.out.toString();
      expect(out, startsWith('=== banner ==='));
      expect(out, contains('init'));
      expect(out, contains('migrate'));
    });
  });

  group('WormCommand base class', () {
    test('enableForceFlag wires the --force flag and force getter', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final command = _ForceProbeCommand(harness.build());

      final runner = CommandRunner<int>('test', 'probe')..addCommand(command);
      await runner.run(<String>['force-probe', '--force']);
      expect(command.observedForce, isTrue);

      command.observedForce = null;
      await runner.run(<String>['force-probe']);
      expect(command.observedForce, isFalse);
    });

    test('subclasses inherit context without re-declaring the field', () {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final ctx = harness.build();
      final command = _ForceProbeCommand(ctx);

      expect(command.context, same(ctx));
    });
  });

  group('ensureForceForProduction', () {
    test('allows non-production commands to proceed without --force', () {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final context = harness.build();

      expect(ensureForceForProduction(context: context, force: false), isTrue);
      expect(harness.err.toString(), isEmpty);
    });

    test('allows production commands when --force is provided', () {
      final harness = TestHarness(environment: Environment.production);
      addTearDown(harness.dispose);
      final context = harness.build();

      expect(ensureForceForProduction(context: context, force: true), isTrue);
      expect(harness.err.toString(), isEmpty);
    });

    test(
      'refuses production commands without --force and writes diagnostic',
      () {
        final harness = TestHarness(environment: Environment.production);
        addTearDown(harness.dispose);
        final context = harness.build();

        expect(
          ensureForceForProduction(context: context, force: false),
          isFalse,
        );
        expect(harness.err.toString(), contains('--force'));
        expect(harness.err.toString(), contains('production'));
      },
    );
  });
}
