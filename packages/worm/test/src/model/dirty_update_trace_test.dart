/// Dirty-only UPDATE trace: `Model.save()` on an
/// attribute-seeded model with N dirty fields must emit
/// an [`UpdateDescriptor`] whose `values` map carries
/// exactly those N keys — not the full row. The
/// complementary fall-back path (model with an empty
/// `state.attributes`) still emits the full row.
///
/// Implementation that drives this lives in
/// `lib/src/model/active_record.dart::_updatePayload`.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/adapter_capabilities.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/aggregate_descriptor.dart';
import 'package:worm/src/query/delete_descriptor.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/update_descriptor.dart';
import 'package:worm/src/registry/worm.dart';

/// Test-local adapter that pipes every call straight to an
/// inner [`InMemoryAdapter`] except `update`, which it
/// captures verbatim before delegating. Defined inline in
/// this file rather than promoted to a shared helper,
/// keeping the capture surface scoped to the one test that
/// needs it.
final class CapturingAdapter extends DatabaseAdapter {
  CapturingAdapter(this._inner) : super(capabilities: _inner.capabilities);

  factory CapturingAdapter.fresh() => CapturingAdapter(InMemoryAdapter());

  final InMemoryAdapter _inner;

  /// Every [`UpdateDescriptor`] this adapter saw, in
  /// dispatch order.
  final List<UpdateDescriptor> capturedUpdates = <UpdateDescriptor>[];

  @override
  AdapterCapabilities get capabilities => _inner.capabilities;

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      _inner.select(d);

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) =>
      _inner.selectOne(d);

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) => _inner.insert(d);

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) =>
      _inner.insertMany(d);

  @override
  Future<int> update(UpdateDescriptor d) {
    capturedUpdates.add(d);
    return _inner.update(d);
  }

  @override
  Future<int> delete(DeleteDescriptor d) => _inner.delete(d);

  @override
  Future<int> count(AggregateDescriptor d) => _inner.count(d);

  @override
  Future<num?> sum(AggregateDescriptor d) => _inner.sum(d);

  @override
  Future<double?> avg(AggregateDescriptor d) => _inner.avg(d);

  @override
  Future<Object?> min(AggregateDescriptor d) => _inner.min(d);

  @override
  Future<Object?> max(AggregateDescriptor d) => _inner.max(d);

  @override
  Future<List<Map<String, Object?>>> rawQuery(String q, List<Object?> p) =>
      _inner.rawQuery(q, p);

  @override
  Future<int> rawExecute(String s, List<Object?> p) => _inner.rawExecute(s, p);

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      _inner.transaction(action);

  @override
  Future<void> executeSchema(SchemaDescriptor d) => _inner.executeSchema(d);

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      _inner.introspectSchema();

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) => _inner.stream(d);

  @override
  String compileToString(Object descriptor) =>
      _inner.compileToString(descriptor);
}

/// Model backed entirely by `state.attributes`. Save()
/// of a dirty instance hits the dirty-only payload branch
/// in `ActiveRecord._updatePayload`.
final class _AttrUser extends Model {
  _AttrUser();

  @override
  String get tableName => 'users';

  /// Timestamps off so the UPDATE column count is exactly
  /// the dirty-set size — no `updated_at` smuggling in.
  @override
  bool get usesTimestamps => false;

  @override
  Object get id => state.attributes['id'] ?? 0;

  @override
  Map<String, Object?> toRow() => <String, Object?>{...state.attributes};
}

/// Model that does NOT use `state.attributes` — its fields
/// are plain `final` storage and `toRow()` builds the row
/// directly. Save() of an instance with an empty
/// `state.attributes` (or empty dirty set) falls back to
/// the full-row UPDATE branch.
final class _ManualUser extends Model {
  _ManualUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  final int userId;
  String firstName;
  String lastName;
  String email;
  String role;

  @override
  String get tableName => 'manual_users';

  @override
  bool get usesTimestamps => false;

  @override
  Object get id => userId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': userId,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'role': role,
  };
}

Future<CapturingAdapter> _bootstrap() async {
  final adapter = CapturingAdapter.fresh();
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': adapter},
  );
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'manual_users'),
  );
  return adapter;
}

void main() {
  tearDown(() async {
    if (Worm.isInitialized) await Worm.reset();
  });

  group('Dirty-only UPDATE for attribute-seeded models', () {
    test('save() on a dirty model with exactly 3 modified fields emits an '
        'UpdateDescriptor.values map of size 3', () async {
      final adapter = await _bootstrap();
      final user = _AttrUser()
        // Seed the row, then persist as an INSERT — that clears
        // the dirty set so the next save() observes only the
        // newly-mutated fields.
        ..setAttribute('id', 1)
        ..setAttribute('first_name', 'Alice')
        ..setAttribute('last_name', 'Liddell')
        ..setAttribute('email', 'alice@example.com')
        ..setAttribute('role', 'user')
        ..setAttribute('login_count', 0);
      await user.save();
      expect(adapter.capturedUpdates, isEmpty, reason: 'INSERT path');

      // Mutate exactly three fields. Anything else stays clean.
      user
        ..setAttribute('first_name', 'Alicia')
        ..setAttribute('email', 'alicia@example.com')
        ..setAttribute('role', 'admin');
      expect(user.dirtyFields, <String>{'first_name', 'email', 'role'});

      await user.save();

      expect(adapter.capturedUpdates, hasLength(1));
      final captured = adapter.capturedUpdates.single;
      expect(
        captured.values,
        hasLength(3),
        reason: 'Exactly the three dirty columns, no full-row payload.',
      );
      expect(
        captured.values.keys,
        containsAll(<String>['first_name', 'email', 'role']),
      );
      expect(
        captured.values.keys,
        isNot(contains('id')),
        reason: 'Primary key is never part of an UPDATE SET clause.',
      );
      expect(
        captured.values.keys,
        isNot(contains('last_name')),
        reason: 'Unchanged column must not leak into the SET clause.',
      );
      expect(
        captured.values.keys,
        isNot(contains('login_count')),
        reason: 'Unchanged column must not leak into the SET clause.',
      );
    });

    test('the captured UpdateDescriptor.values key list equals the dirty set, '
        'value-for-value', () async {
      final adapter = await _bootstrap();
      final user = _AttrUser()
        ..setAttribute('id', 2)
        ..setAttribute('first_name', 'Bob')
        ..setAttribute('last_name', 'Builder')
        ..setAttribute('email', 'bob@example.com')
        ..setAttribute('role', 'user')
        ..setAttribute('login_count', 0);
      await user.save();

      user
        ..setAttribute('first_name', 'Robert')
        ..setAttribute('login_count', 7)
        ..setAttribute('role', 'admin');

      await user.save();

      final captured = adapter.capturedUpdates.single;
      expect(captured.values, hasLength(3));
      expect(captured.values['first_name'], 'Robert');
      expect(captured.values['login_count'], 7);
      expect(captured.values['role'], 'admin');
    });

    test(
      'a second save() after only one dirty mutation still emits exactly '
      'one column — the dirty set drives column count, not the schema',
      () async {
        final adapter = await _bootstrap();
        final user = _AttrUser()
          ..setAttribute('id', 3)
          ..setAttribute('first_name', 'Carol')
          ..setAttribute('last_name', 'Danvers')
          ..setAttribute('email', 'carol@example.com')
          ..setAttribute('role', 'user');
        await user.save();

        // Single mutation between the INSERT and this UPDATE — the
        // SET clause must list one column, not five.
        user.setAttribute('role', 'captain');
        await user.save();

        expect(adapter.capturedUpdates, hasLength(1));
        final captured = adapter.capturedUpdates.single;
        expect(captured.values, hasLength(1));
        expect(captured.values.keys.single, 'role');
        expect(captured.values['role'], 'captain');
      },
    );
  });

  group(
    'Fall-back: manual-construction models still get a full-row UPDATE',
    () {
      test('when state.attributes is empty, UpdateDescriptor.values contains '
          'every non-pk column from toRow()', () async {
        final adapter = await _bootstrap();
        // Seed the row through a raw INSERT so the in-memory store
        // has it; bypass save() so state.attributes stays empty.
        await adapter.insert(
          const InsertDescriptor(
            table: 'manual_users',
            values: <String, Object?>{
              'id': 10,
              'first_name': 'Dora',
              'last_name': 'Explorer',
              'email': 'dora@example.com',
              'role': 'user',
            },
          ),
        );

        final user =
            _ManualUser(
                userId: 10,
                firstName: 'Dora',
                lastName: 'Explorer',
                email: 'dora@example.com',
                role: 'user',
              )
              ..markPersisted()
              // Mutate via the plain field setters — state.attributes
              // / state.dirty stay untouched.
              ..role = 'admin';

        await user.save();

        expect(
          user.state.attributes,
          isEmpty,
          reason: 'Pre-condition of the fall-back branch.',
        );
        expect(adapter.capturedUpdates, hasLength(1));
        final captured = adapter.capturedUpdates.single;
        expect(
          captured.values.keys,
          containsAll(<String>['first_name', 'last_name', 'email', 'role']),
        );
        expect(
          captured.values.keys,
          isNot(contains('id')),
          reason: 'Primary key is stripped from full-row UPDATE payloads.',
        );
        expect(
          captured.values,
          hasLength(4),
          reason: '4 non-pk columns from toRow() — full-row UPDATE.',
        );
      });

      test(
        'manual-construction fall-back still strips the primary key',
        () async {
          final adapter = await _bootstrap();
          await adapter.insert(
            const InsertDescriptor(
              table: 'manual_users',
              values: <String, Object?>{
                'id': 11,
                'first_name': 'Erin',
                'last_name': 'Brockovich',
                'email': 'erin@example.com',
                'role': 'lawyer',
              },
            ),
          );

          final user = _ManualUser(
            userId: 11,
            firstName: 'Erin',
            lastName: 'Brockovich',
            email: 'erin@example.com',
            role: 'lawyer',
          )..markPersisted();
          await user.save();

          final captured = adapter.capturedUpdates.single;
          expect(captured.values.containsKey('id'), isFalse);
        },
      );
    },
  );
}
