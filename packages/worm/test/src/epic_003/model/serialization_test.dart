/// Verifies that [Model] is a [Serializable]: implements the
/// interface members [Serializable.serializationId],
/// [Serializable.serializationType], and [Serializable.describe],
/// while keeping [Model.toMap] / [Model.toJson] aligned with the
/// data [Model.toRow] already produces.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// Minimal model with two columns, a hidden field, and a computed
/// attribute — exercises every channel that feeds [Model.describe].
final class _Profile extends Model {
  _Profile({
    required this.profileId,
    required this.name,
    required this.passwordHash,
  });

  final int profileId;
  final String name;
  final String passwordHash;

  @override
  Object get id => profileId;

  @override
  String? get tableName => 'profiles';

  @override
  bool get usesTimestamps => false;

  @override
  Set<String> get hiddenFromSerialization => const <String>{'password_hash'};

  @override
  Map<String, Object?> get computedAttributes => <String, Object?>{
    'display_name': 'Mx. $name',
  };

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': profileId,
    'name': name,
    'password_hash': passwordHash,
  };
}

/// Model that customizes serialization by overriding [describe]
/// alone — exists so the test suite can guarantee that [Model.toMap]
/// flows through [describe] (the documented customization point)
/// instead of reading the underlying channels directly.
final class _DescribeOverride extends Model {
  _DescribeOverride({required this.recordId});

  final int recordId;

  @override
  Object get id => recordId;

  @override
  String? get tableName => 'describe_overrides';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': recordId,
    'secret': 'do-not-leak',
  };

  @override
  SerializationDescriptor describe() => SerializationDescriptor(
    fields: <String, Object?>{'id': recordId, 'shape': 'override'},
    hidden: const <String>{'shape'},
    appended: const <String, Object?>{'computed': true},
  );
}

/// Model with no hidden / computed attributes — for the baseline
/// describe() equality assertion.
final class _PlainRecord extends Model {
  _PlainRecord({required this.recordId, required this.label});

  final int recordId;
  final String label;

  @override
  Object get id => recordId;

  @override
  String? get tableName => 'plain_records';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': recordId,
    'label': label,
  };
}

void main() {
  group('Model implements Serializable', () {
    test('is Serializable at runtime', () {
      final Model model = _PlainRecord(recordId: 1, label: 'x');
      expect(model, isA<Serializable>());
    });

    test('serializationId is "\$id"', () {
      final model = _PlainRecord(recordId: 42, label: 'x');
      expect(model.serializationId, '42');
      expect(model.serializationId, '${model.id}');
    });

    test('serializationType is runtimeType.toString()', () {
      final model = _PlainRecord(recordId: 1, label: 'x');
      expect(model.serializationType, '_PlainRecord');
      expect(model.serializationType, '${model.runtimeType}');
    });
  });

  group('Model.toMap', () {
    test('returns a Map containing every key from toRow', () {
      final model = _PlainRecord(recordId: 1, label: 'x');
      final map = model.toMap();
      for (final key in model.toRow().keys) {
        expect(map.containsKey(key), isTrue, reason: 'expected key "$key"');
      }
      expect(map['id'], 1);
      expect(map['label'], 'x');
    });

    test(
      'drops hiddenFromSerialization keys and appends computedAttributes',
      () {
        final profile = _Profile(
          profileId: 1,
          name: 'Sky',
          passwordHash: 'secret',
        );
        final map = profile.toMap();
        expect(map.containsKey('password_hash'), isFalse);
        expect(map['display_name'], 'Mx. Sky');
        expect(map['name'], 'Sky');
      },
    );
  });

  group('Model.toJson', () {
    test('returns a valid JSON string parseable by jsonDecode', () {
      final model = _PlainRecord(recordId: 1, label: 'x');
      final json = model.toJson();
      final decoded = jsonDecode(json);
      expect(decoded, isA<Map<String, Object?>>());
      expect(decoded, model.toMap());
    });
  });

  group('Model.toMap routes through describe()', () {
    test('honors describe().fields instead of reading toRow() directly', () {
      final model = _DescribeOverride(recordId: 9);
      final map = model.toMap();
      // describe() reports fields = {id, shape}; toRow() reports
      // {id, secret}. If toMap read toRow directly, "secret" would
      // leak into the output. Routing through describe() filters it.
      expect(map.containsKey('secret'), isFalse);
    });

    test('honors describe().hidden override', () {
      final model = _DescribeOverride(recordId: 9);
      // 'shape' is in fields but listed in describe().hidden — it
      // must be stripped from the final map.
      expect(model.toMap().containsKey('shape'), isFalse);
    });

    test('honors describe().appended override', () {
      final model = _DescribeOverride(recordId: 9);
      expect(model.toMap()['computed'], isTrue);
    });

    test('toJson reflects describe() override after jsonDecode round-trip', () {
      final model = _DescribeOverride(recordId: 9);
      final decoded = jsonDecode(model.toJson());
      expect(decoded, model.toMap());
    });
  });

  group('Model.describe', () {
    test('returns a SerializationDescriptor with fields == toRow()', () {
      final model = _PlainRecord(recordId: 7, label: 'row');
      final descriptor = model.describe();
      expect(descriptor, isA<SerializationDescriptor>());
      expect(descriptor.fields, model.toRow());
    });

    test('exposes hiddenFromSerialization through descriptor.hidden', () {
      final profile = _Profile(profileId: 1, name: 'Sky', passwordHash: 's');
      expect(profile.describe().hidden, profile.hiddenFromSerialization);
    });

    test('exposes computedAttributes through descriptor.appended', () {
      final profile = _Profile(profileId: 1, name: 'Sky', passwordHash: 's');
      expect(profile.describe().appended, profile.computedAttributes);
    });
  });
}
