/// Base exception for all worm ORM errors.
library;

/// Abstract base class for all worm exceptions.
///
/// Every typed exception in the worm ORM transitively
/// extends this class. Provides a human-readable
/// [message] describing the error and an extensible
/// [context] map that subclasses expose so that
/// [toString] always carries the relevant fields
/// (table, model, migration, etc.) when set.
abstract class WormException implements Exception {
  /// Creates a [WormException] with the given
  /// [message].
  const WormException(this.message);

  /// Human-readable description of the error.
  final String message;

  /// Context fields surfaced by [toString].
  ///
  /// Override in concrete subclasses to expose typed
  /// fields (`table`, `model`, `migration`, …). Entries
  /// whose value is `null` are omitted from
  /// [toString] so optional fields do not appear when
  /// unset.
  Map<String, Object?> get context => const <String, Object?>{};

  @override
  String toString() {
    final typeName = _typeName;
    final entries = <String>[];
    context.forEach((key, value) {
      if (value == null) return;
      entries.add('$key: $value');
    });
    if (entries.isEmpty) return '$typeName: $message';
    return '$typeName: $message (${entries.join(', ')})';
  }

  String get _typeName => runtimeType.toString();
}
