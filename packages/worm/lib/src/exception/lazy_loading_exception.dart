/// Exception for forbidden lazy relation loads.
library;

import 'model_exception.dart';

/// Thrown in strict mode when code accesses an
/// unloaded relation that would trigger a lazy
/// load.
///
/// Differs from `RelationNotLoadedException`: that
/// exception signals an accidental access on a
/// relation that was never eagerly loaded;
/// [LazyLoadingException] signals a deliberate
/// policy violation — the project forbids any lazy
/// load and the offending site must declare its
/// relation in `with` / `withRelation`.
class LazyLoadingException extends ModelException {
  /// Creates a [LazyLoadingException].
  const LazyLoadingException({
    required this.modelName,
    required this.relationName,
    required String message,
  }) : super(message);

  /// The model owning the relation.
  final String modelName;

  /// The relation that would have been
  /// lazy-loaded.
  final String relationName;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'modelName': modelName,
    'relation': relationName,
  };

  @override
  String toString() =>
      'LazyLoadingException: $message '
      '(modelName: $modelName, relation: $relationName)';
}
