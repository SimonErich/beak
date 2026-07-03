import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  const hit = BeakSearchHit(
    table: 'products',
    id: 7,
    displayLabel: 'Laser Pointer',
    matchedColumnKey: 'name',
  );

  group('JSON round-trip', () {
    test('serializes every key', () {
      expect(hit.toJson(), {
        'table': 'products',
        'id': 7,
        'displayLabel': 'Laser Pointer',
        'matchedColumnKey': 'name',
      });
    });

    test('decode(encode(hit)) is deep-equal for int and string ids', () {
      expect(BeakSearchHit.fromJson(hit.toJson()), hit);
      const stringId = BeakSearchHit(
        table: 'notes',
        id: 'n1',
        displayLabel: 'Note',
        matchedColumnKey: 'title',
      );
      expect(BeakSearchHit.fromJson(stringId.toJson()), stringId);
      expect(
        BeakSearchHit.fromJson(stringId.toJson()).hashCode,
        stringId.hashCode,
      );
    });

    test('fromJson rejects a non-int non-string id', () {
      final json = hit.toJson()..['id'] = true;
      expect(
        () => BeakSearchHit.fromJson(json),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects a missing key', () {
      final json = hit.toJson()..remove('displayLabel');
      expect(
        () => BeakSearchHit.fromJson(json),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('equality', () {
    test('equal parts compare and hash equal', () {
      expect(
        runtimeValue(hit),
        const BeakSearchHit(
          table: 'products',
          id: 7,
          displayLabel: 'Laser Pointer',
          matchedColumnKey: 'name',
        ),
      );
    });

    test('any differing part breaks equality', () {
      expect(
        runtimeValue(hit),
        isNot(
          const BeakSearchHit(
            table: 'products',
            id: 8,
            displayLabel: 'Laser Pointer',
            matchedColumnKey: 'name',
          ),
        ),
      );
    });
  });

  test('toString names the table, id and label', () {
    expect(hit.toString(), contains('products'));
    expect(hit.toString(), contains('Laser Pointer'));
  });
}
