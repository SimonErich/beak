/// @CastAs(DurationCast) round-trips Duration ↔ ms integer
/// through DB; null/zero/max-value tested.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/cast/cast_manager.dart';
import 'package:worm/src/cast/casts/duration_cast.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';

/// Test model whose `sessionDuration` column is bound to
/// `DurationCast` via the generated-shape `castManager` override.
///
/// Reads `sessionDuration` from the underlying state map so that
/// `refresh()` round-trips through the cast — mimics what generated
/// code would emit (a getter delegating to the attribute store).
final class _Session extends Model {
  _Session({required this.sessionId, Duration? sessionDuration}) {
    setAttribute('session_duration', sessionDuration);
  }

  final int sessionId;

  Duration? get sessionDuration {
    final value = getAttribute('session_duration');
    return value is Duration ? value : null;
  }

  set sessionDuration(Duration? value) {
    setAttribute('session_duration', value);
  }

  @override
  Object get id => sessionId;

  @override
  String? get tableName => 'sessions';

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': sessionId,
    'session_duration': getAttribute('session_duration'),
  };

  @override
  bool get usesTimestamps => false;

  @override
  CastManager get castManager => CastManager(<String, DurationCast>{
    'session_duration': const DurationCast(field: 'session_duration'),
  });
}

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'sessions'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  group('DurationCast round-trip', () {
    test('null Duration round-trips as null', () async {
      final session = _Session(sessionId: 1);
      await session.save();
      final rows = await adapter.select(
        const QueryDescriptor(table: 'sessions'),
      );
      expect(rows.single['session_duration'], isNull);
      session.sessionDuration = null;
      await session.refresh();
      expect(session.sessionDuration, isNull);
    });

    test('Duration.zero encodes as 0 ms and decodes back to zero', () async {
      final session = _Session(sessionId: 2, sessionDuration: Duration.zero);
      await session.save();
      final rows = await adapter.select(
        const QueryDescriptor(table: 'sessions'),
      );
      expect(rows.single['session_duration'], 0);
      await session.refresh();
      expect(session.sessionDuration, Duration.zero);
    });

    test(
      'positive Duration encodes as milliseconds and decodes back',
      () async {
        const value = Duration(milliseconds: 5000);
        final session = _Session(sessionId: 3, sessionDuration: value);
        await session.save();
        final rows = await adapter.select(
          const QueryDescriptor(table: 'sessions'),
        );
        expect(rows.single['session_duration'], 5000);
        await session.refresh();
        expect(session.sessionDuration, value);
      },
    );

    test('max-value Duration round-trips losslessly', () async {
      const value = Duration(milliseconds: 9223372036854775000);
      final session = _Session(sessionId: 4, sessionDuration: value);
      await session.save();
      final rows = await adapter.select(
        const QueryDescriptor(table: 'sessions'),
      );
      expect(rows.single['session_duration'], value.inMilliseconds);
      await session.refresh();
      expect(session.sessionDuration, value);
    });
  });
}
