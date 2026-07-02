/// Exception for factory misuse.
library;

import 'worm_exception.dart';

/// Thrown when a model factory is asked to do
/// something that violates its definition.
///
/// The most common cause is requesting a named
/// state that the factory has not declared via
/// `defineState`.
class FactoryException extends WormException {
  /// Creates a [FactoryException].
  const FactoryException({required this.factoryState, required String message})
    : super(message);

  /// The state identifier the caller requested, or
  /// empty when the failure is unrelated to a
  /// specific state.
  final String factoryState;

  @override
  Map<String, Object?> get context => <String, Object?>{
    if (factoryState.isNotEmpty) 'state': factoryState,
  };

  @override
  String toString() {
    if (factoryState.isEmpty) return 'FactoryException: $message';
    return 'FactoryException: $message (state: $factoryState)';
  }
}
