/// Unit tests for [DatabaseSeeder].
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/seeder/database_seeder.dart';
import 'package:worm/src/seeder/seeder_base.dart';

final class _RecordingSeeder extends Seeder {
  _RecordingSeeder(this._tag, this._log);

  final String _tag;
  final List<String> _log;

  @override
  String get name => _tag;

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    _log.add(_tag);
  }
}

final class _ChildOrderSeeder extends DatabaseSeeder {
  _ChildOrderSeeder(this._children);

  final List<Seeder> _children;

  @override
  String get name => 'master';

  @override
  List<Seeder> get seeders => _children;
}

void main() {
  late InMemoryAdapter adapter;
  late List<String> log;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    log = <String>[];
  });

  test('run() invokes children in the order declared by seeders', () async {
    final master = _ChildOrderSeeder(<Seeder>[
      _RecordingSeeder('alpha', log),
      _RecordingSeeder('beta', log),
      _RecordingSeeder('gamma', log),
    ]);
    await master.run(adapter);
    expect(log, <String>['alpha', 'beta', 'gamma']);
  });

  test('run() preserves order even when a child re-runs', () async {
    final master = _ChildOrderSeeder(<Seeder>[
      _RecordingSeeder('one', log),
      _RecordingSeeder('two', log),
    ]);
    await master.run(adapter);
    await master.run(adapter);
    expect(log, <String>['one', 'two', 'one', 'two']);
  });

  test('an empty children list runs without error', () async {
    final master = _ChildOrderSeeder(const <Seeder>[]);
    await master.run(adapter);
    expect(log, isEmpty);
  });
}
