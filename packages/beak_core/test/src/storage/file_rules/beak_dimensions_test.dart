import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../../support/runtime_values.dart';

void main() {
  group('BeakDimensions', () {
    test('stores width and height in pixels', () {
      const dimensions = BeakDimensions(
        widthInPixels: 800,
        heightInPixels: 600,
      );
      expect(dimensions.widthInPixels, 800);
      expect(dimensions.heightInPixels, 600);
    });

    test('square uses one size for both sides', () {
      const square = BeakDimensions.square(64);
      expect(square.widthInPixels, 64);
      expect(square.heightInPixels, 64);
    });

    test('equal dimensions compare and hash equal', () {
      final rebuilt = BeakDimensions(
        widthInPixels: runtimeValue(800),
        heightInPixels: 600,
      );
      const dimensions = BeakDimensions(
        widthInPixels: 800,
        heightInPixels: 600,
      );
      expect(rebuilt, dimensions);
      expect(rebuilt.hashCode, dimensions.hashCode);
    });

    test('different dimensions are not equal', () {
      const dimensions = BeakDimensions(
        widthInPixels: 800,
        heightInPixels: 600,
      );
      expect(
        dimensions,
        isNot(const BeakDimensions(widthInPixels: 600, heightInPixels: 800)),
      );
      expect(dimensions == runtimeValue<Object>('800x600'), isFalse);
    });

    test('rejects non-positive sizes', () {
      expect(
        () =>
            BeakDimensions(widthInPixels: runtimeValue(0), heightInPixels: 600),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => BeakDimensions(
          widthInPixels: 800,
          heightInPixels: runtimeValue(-1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('prints its size for debugging', () {
      expect(
        const BeakDimensions(
          widthInPixels: 800,
          heightInPixels: 600,
        ).toString(),
        contains('800x600'),
      );
    });

    test('serializes to a JSON object with both pixel sizes', () {
      expect(
        const BeakDimensions(widthInPixels: 800, heightInPixels: 600).toJson(),
        {'widthInPixels': 800, 'heightInPixels': 600},
      );
    });

    test('round-trips through JSON', () {
      const dimensions = BeakDimensions(
        widthInPixels: 1920,
        heightInPixels: 1080,
      );
      expect(BeakDimensions.fromJson(dimensions.toJson()), dimensions);
    });

    test('fromJson requires both keys', () {
      expect(
        () => BeakDimensions.fromJson(const {'widthInPixels': 800}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakDimensions.fromJson(const {'heightInPixels': 600}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects non-integer sizes', () {
      expect(
        () => BeakDimensions.fromJson(const {
          'widthInPixels': 'wide',
          'heightInPixels': 600,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });
}
