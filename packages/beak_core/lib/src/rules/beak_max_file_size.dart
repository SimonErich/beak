part of 'beak_rule.dart';

/// Caps an upload's size (validated against the size in bytes as an [int])
/// at [maxSizeInBytes].
final class BeakMaxFileSize extends BeakRule {
  /// Creates a rule rejecting uploads larger than [maxSizeInBytes].
  const BeakMaxFileSize(this.maxSizeInBytes);

  /// Highest accepted upload size in bytes.
  final int maxSizeInBytes;

  @override
  String get id => 'max_file_size';

  @override
  String? validate(Object? value) => switch (value) {
    final int sizeInBytes when sizeInBytes > maxSizeInBytes =>
      'File must be at most $maxSizeInBytes bytes.',
    _ => null,
  };
}
