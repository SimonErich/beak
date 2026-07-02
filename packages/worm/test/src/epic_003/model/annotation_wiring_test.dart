/// Runtime tests verifying the hooks consumed by the generator's
/// `@Hidden`, `@Computed`, `@CastAs`, `@Appended`, `@Fillable`, and
/// `@Guarded` emissions.
///
/// The fixtures hand-write the overrides the generator emits in
/// production so the test exercises the runtime contracts in
/// isolation from the codegen pipeline.
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// Mimics `@Hidden`, `@Computed`, `@Appended`, `@Fillable`, and
/// `@Guarded` on a single model.
final class _AnnotatedUser extends Model {
  _AnnotatedUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.password,
  });

  final int userId;
  String firstName;
  String lastName;
  String password;

  /// Stand-in for an `@Computed`-annotated getter.
  String get fullName => '$firstName $lastName';

  @override
  Object get id => userId;

  @override
  String? get tableName => 'users';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': userId,
    'first_name': firstName,
    'last_name': lastName,
    'password': password,
  };

  @override
  Set<String> get hiddenFromSerialization => const <String>{'password'};

  @override
  Map<String, Object?> get computedAttributes => <String, Object?>{
    'fullName': fullName,
    'displayName': '@$firstName',
  };

  @override
  List<String> get fillable => const <String>['first_name', 'last_name'];

  @override
  List<String> get guarded => const <String>['password'];

  @override
  bool get strictMassAssignment => true;
}

/// Mimics `@CastAs(DurationCast)` on a `sessionDuration` column.
final class _AnnotatedSession extends Model {
  _AnnotatedSession({required this.sessionId, Duration? sessionDuration}) {
    if (sessionDuration != null) {
      setAttribute('session_duration', sessionDuration);
    }
  }

  final int sessionId;

  Duration? get sessionDuration {
    final raw = getAttribute('session_duration');
    return raw is Duration ? raw : null;
  }

  @override
  Object get id => sessionId;

  @override
  String? get tableName => 'sessions';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': sessionId,
    'session_duration': getAttribute('session_duration'),
  };

  @override
  CastManager get castManager => CastManager(<String, AttributeCast>{
    'session_duration': const DurationCast(field: 'session_duration'),
  });
}

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'users'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'sessions'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  group('@Hidden removes the column from toMap', () {
    test('toMap omits the hidden key', () {
      final user = _AnnotatedUser(
        userId: 1,
        firstName: 'Ada',
        lastName: 'Lovelace',
        password: 'hunter2',
      );
      final map = user.toMap();
      expect(map.containsKey('password'), isFalse);
      expect(map['first_name'], 'Ada');
    });

    test('toJson omits the hidden key and the secret value', () {
      final user = _AnnotatedUser(
        userId: 1,
        firstName: 'Ada',
        lastName: 'Lovelace',
        password: 'hunter2',
      );
      expect(user.toJson(), isNot(contains('hunter2')));
      expect(user.toJson(), isNot(contains('password')));
    });
  });

  group('@Computed appears in toMap, not in INSERT', () {
    test('toMap contains the computed key', () {
      final user = _AnnotatedUser(
        userId: 1,
        firstName: 'Ada',
        lastName: 'Lovelace',
        password: 'hunter2',
      );
      expect(user.toMap()['fullName'], 'Ada Lovelace');
      expect(user.toMap()['displayName'], '@Ada');
    });

    test('persisted row does NOT contain the computed key', () async {
      final user = _AnnotatedUser(
        userId: 1,
        firstName: 'Ada',
        lastName: 'Lovelace',
        password: 'hunter2',
      );
      await user.save();
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      final row = rows.single;
      expect(row.containsKey('fullName'), isFalse);
      expect(row.containsKey('displayName'), isFalse);
      expect(
        row.keys,
        containsAll(<String>['id', 'first_name', 'last_name', 'password']),
      );
      // toRow exposes 'password' — only the serialization layer hides
      // it. The INSERT payload still carries the column.
      expect(row['password'], 'hunter2');
    });
  });

  group('@CastAs round-trips Duration ↔ ms integer', () {
    test(
      'save encodes Duration(milliseconds: 5000) as 5000 in the DB row',
      () async {
        final session = _AnnotatedSession(
          sessionId: 1,
          sessionDuration: const Duration(milliseconds: 5000),
        );
        await session.save();
        final rows = await adapter.select(
          const QueryDescriptor(table: 'sessions'),
        );
        expect(rows.single['session_duration'], 5000);
      },
    );

    test(
      'refresh decodes the raw integer back into a Duration, not an int',
      () async {
        final session = _AnnotatedSession(
          sessionId: 2,
          sessionDuration: const Duration(milliseconds: 5000),
        );
        await session.save();

        await session.refresh();

        final raw = session.getAttribute('session_duration');
        expect(raw, isA<Duration>());
        expect(raw, const Duration(milliseconds: 5000));
        expect(session.sessionDuration, const Duration(milliseconds: 5000));
      },
    );
  });

  group('@Fillable/@Guarded enforce mass assignment in strict mode', () {
    test('fillable keys are accepted', () {
      final user =
          _AnnotatedUser(userId: 3, firstName: '', lastName: '', password: '')
            ..fill(<String, Object?>{
              'first_name': 'Margaret',
              'last_name': 'Hamilton',
            });
      expect(user.getAttribute('first_name'), 'Margaret');
      expect(user.getAttribute('last_name'), 'Hamilton');
    });

    test('fill({\'password\': \'x\'}) throws MassAssignmentException with '
        'exception.field == "password"', () {
      final user = _AnnotatedUser(
        userId: 4,
        firstName: '',
        lastName: '',
        password: '',
      );
      try {
        user.fill(<String, Object?>{'password': 'x'});
        fail('Expected MassAssignmentException');
      } on MassAssignmentException catch (e) {
        expect(e.field, 'password');
        expect(e.fields, <String>['password']);
      }
    });

    test('multiple offending keys are all reported on a single throw', () {
      final user = _AnnotatedUser(
        userId: 5,
        firstName: '',
        lastName: '',
        password: '',
      );
      try {
        user.fill(<String, Object?>{
          'first_name': 'ok',
          'password': 'bad',
          'admin': true,
        });
        fail('Expected MassAssignmentException');
      } on MassAssignmentException catch (e) {
        expect(e.fields, containsAll(<String>['password', 'admin']));
      }
    });
  });
}
