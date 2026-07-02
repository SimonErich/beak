import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/seeder/database_seeder.dart';
import 'package:worm/src/seeder/environment.dart';
import 'package:worm/src/seeder/seeder_base.dart';
import 'package:worm/src/seeder/seeder_record.dart';
import 'package:worm/src/seeder/seeder_record_store.dart';
import 'package:worm/src/seeder/seeder_runner.dart';

final List<String> _runOrder = <String>[];

final class _RecordingSeeder extends Seeder {
  const _RecordingSeeder(this._name);
  final String _name;
  @override
  String get name => _name;
  @override
  Future<void> run(DatabaseAdapter adapter) async {
    _runOrder.add(_name);
  }
}

final class _ComposedDatabaseSeeder extends DatabaseSeeder {
  const _ComposedDatabaseSeeder();
  @override
  String get name => 'composed';
  @override
  List<Seeder> get seeders => const <Seeder>[
    _RecordingSeeder('alpha'),
    _RecordingSeeder('beta'),
    _RecordingSeeder('gamma'),
  ];
}

Future<InMemoryAdapter> _adapter() async {
  final a = InMemoryAdapter();
  await a.connect();
  return a;
}

void main() {
  setUp(_runOrder.clear);

  group('SeederRunner tracking', () {
    test('records one row per seeder and skips on the second '
        'invocation', () async {
      final adapter = await _adapter();
      final store = SeederRecordStore(adapter);
      await store.ensureTable();
      final runner = SeederRunner(
        adapter: adapter,
        seeders: const <Seeder>[_RecordingSeeder('once')],
        environment: Environment.development,
        store: store,
      );
      final first = await runner.run();
      final second = await runner.run();
      expect(first, <String>['once']);
      expect(second, isEmpty);
      final tracking = await adapter.select(
        const QueryDescriptor(table: SeederRecord.tableName),
      );
      expect(tracking, hasLength(1));
      expect(tracking.single['name'], 'once');
    });
  });

  group('DatabaseSeeder', () {
    test('runs child seeders in declared order', () async {
      final adapter = await _adapter();
      const seeder = _ComposedDatabaseSeeder();
      await seeder.run(adapter);
      expect(_runOrder, <String>['alpha', 'beta', 'gamma']);
    });
  });
}
