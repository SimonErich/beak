/// Exception for configuration errors.
library;

import 'worm_exception.dart';

/// Thrown when the ORM configuration is invalid
/// or incomplete.
class ConfigurationException extends WormException {
  /// Creates a [ConfigurationException].
  const ConfigurationException({required this.key, required String message})
    : super(message);

  /// The configuration key that is invalid or
  /// missing.
  final String key;

  @override
  Map<String, Object?> get context => <String, Object?>{'key': key};

  @override
  String toString() => 'ConfigurationException: $message (key: $key)';
}
