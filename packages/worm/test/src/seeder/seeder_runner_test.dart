import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/event/lifecycle_event.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/registry/worm.dart';
import 'package:worm/src/seeder/environment.dart';
import 'package:worm/src/seeder/seeder_base.dart';
import 'package:worm/src/seeder/seeder_record.dart';
import 'package:worm/src/seeder/seeder_record_store.dart';
import 'package:worm/src/seeder/seeder_runner.dart';

final class _DevOnlySeeder extends Seeder {
  const _DevOnlySeeder();
  @override
  String get name => 'dev';
  @override
  Environment get environment => Environment.development;
  @override
  Future<void> run(DatabaseAdapter adapter) async {}
}

final class _AlwaysSeeder extends Seeder {
  const _AlwaysSeeder();
  @override
  String get name => 'always';
  @override
  Future<void> run(DatabaseAdapter adapter) async {}
}

final class _CountingSeeder extends Seeder {
  _CountingSeeder(this.tag, this._log, {this.orderValue = 0});

  final String tag;
  final List<String> _log;
  final int orderValue;

  @override
  String get name => tag;

  @override
  int get order => orderValue;

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    _log.add(tag);
  }
}

/// Records whether lifecycle events were muted while it ran.
final class _MuteProbeSeeder extends Seeder {
  _MuteProbeSeeder({required this.muteEvents});

  @override
  final bool muteEvents;

  bool? observedMuted;

  @override
  String get name => 'mute-probe';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    observedMuted = Worm.isEventMuted(LifecycleEvent.beforeCreate);
  }
}

void main() {
  group('SeederRunner.run', () {
    test('runs only seeders applicable to the current environment', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      final runner = SeederRunner(
        adapter: adapter,
        seeders: const <Seeder>[_DevOnlySeeder(), _AlwaysSeeder()],
        environment: Environment.production,
      );
      final ran = await runner.run();
      expect(ran, ['always']);
    });

    test('runs all seeders when environment matches', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      final runner = SeederRunner(
        adapter: adapter,
        seeders: const <Seeder>[_DevOnlySeeder(), _AlwaysSeeder()],
        environment: Environment.development,
      );
      final ran = await runner.run();
      expect(ran, ['dev', 'always']);
    });

    test(
      'with store=null behaves like pre-WI (no tracking, no skip)',
      () async {
        final adapter = InMemoryAdapter();
        await adapter.connect();
        final log = <String>[];
        final runner = SeederRunner(
          adapter: adapter,
          seeders: <Seeder>[_CountingSeeder('a', log)],
          environment: Environment.development,
        );
        await runner.run();
        await runner.run();
        expect(log, <String>['a', 'a']);
      },
    );
  });

  group('SeederRunner ordering', () {
    test('sorts seeders by Seeder.order before running', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      final log = <String>[];
      final runner = SeederRunner(
        adapter: adapter,
        seeders: <Seeder>[
          _CountingSeeder('second', log, orderValue: 2),
          _CountingSeeder('first', log, orderValue: 1),
        ],
        environment: Environment.development,
      );
      final ran = await runner.run();
      expect(log, <String>['first', 'second']);
      expect(ran, <String>['first', 'second']);
    });

    test('ties preserve registration order (stable sort)', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      final log = <String>[];
      final runner = SeederRunner(
        adapter: adapter,
        seeders: <Seeder>[
          _CountingSeeder('a', log),
          _CountingSeeder('b', log),
          _CountingSeeder('c', log),
        ],
        environment: Environment.development,
      );
      await runner.run();
      expect(log, <String>['a', 'b', 'c']);
    });
  });

  group('SeederRunner with tracking store', () {
    test(
      'skips already-recorded seeders and inserts exactly one row',
      () async {
        final adapter = InMemoryAdapter();
        await adapter.connect();
        final log = <String>[];
        final store = SeederRecordStore(adapter);
        final runner = SeederRunner(
          adapter: adapter,
          seeders: <Seeder>[_CountingSeeder('user', log)],
          environment: Environment.development,
          store: store,
        );
        await runner.run();
        await runner.run();
        expect(log, <String>['user']);
        final rows = await adapter.select(
          const QueryDescriptor(table: SeederRecord.tableName),
        );
        expect(rows, hasLength(1));
        expect(rows.single[SeederRecord.columnName], 'user');
      },
    );

    test('records a row for each seeder that runs', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      final log = <String>[];
      final store = SeederRecordStore(adapter);
      final runner = SeederRunner(
        adapter: adapter,
        seeders: <Seeder>[_CountingSeeder('a', log), _CountingSeeder('b', log)],
        environment: Environment.development,
        store: store,
      );
      await runner.run();
      expect(log, <String>['a', 'b']);
      final names = (await store.all()).map((r) => r.name).toSet();
      expect(names, <String>{'a', 'b'});
    });
  });

  group('SeederRunner.runOne', () {
    test('runs the named seeder ignoring env filter', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      final runner = SeederRunner(
        adapter: adapter,
        seeders: const <Seeder>[_DevOnlySeeder()],
        environment: Environment.production,
      );
      await runner.runOne('dev');
    });

    test('throws when name is unknown', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      final runner = SeederRunner(
        adapter: adapter,
        seeders: const <Seeder>[_AlwaysSeeder()],
        environment: Environment.development,
      );
      await expectLater(
        () => runner.runOne('missing'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SeederRunner muteEvents', () {
    test('runs a muteEvents seeder inside a muted zone', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': adapter},
      );
      addTearDown(Worm.reset);

      final muting = _MuteProbeSeeder(muteEvents: true);
      final notMuting = _MuteProbeSeeder(muteEvents: false);

      await SeederRunner(
        adapter: adapter,
        seeders: <Seeder>[muting],
        environment: Environment.all,
      ).run();
      await SeederRunner(
        adapter: adapter,
        seeders: <Seeder>[notMuting],
        environment: Environment.all,
      ).run();

      expect(muting.observedMuted, isTrue);
      expect(notMuting.observedMuted, isFalse);
    });
  });
}
