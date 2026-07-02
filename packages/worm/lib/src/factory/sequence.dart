/// Sequence generator used by factories.
library;

/// A monotonic integer sequence used by factories.
///
/// Each call to [next] returns the next integer, starting
/// from the `start` value supplied at construction. Use
/// [reset] in tests to return to the initial value.
final class Sequence {
  /// Creates a [Sequence] starting at [start].
  Sequence({int start = 1}) : _start = start, _current = start;

  /// The configured starting value.
  int get start => _start;

  final int _start;
  int _current;

  /// Returns the next integer in the sequence.
  int next() {
    final value = _current;
    _current++;
    return value;
  }

  /// Resets the sequence to its initial value.
  void reset() {
    _current = _start;
  }

  /// Current value the next call to [next] will return.
  int get peek => _current;
}

/// Alias for [Sequence] — kept so AC and external docs that
/// reference `FactorySequence.next()` resolve to the actual
/// implementation class. Both names denote the same class.
typedef FactorySequence = Sequence;
