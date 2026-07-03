import 'dart:math';

final Random _defaultRandom = Random.secure();

/// Generates an RFC 4122 version-4 UUID (lower-case, dash-grouped).
///
/// The backend mints these for string-keyed models whose create payload
/// carries no primary key. [random] injects a deterministic source in tests.
String generateUuidV4({Random? random}) {
  final rng = random ?? _defaultRandom;
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = [
    for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
