import 'package:meta/meta.dart';
import 'package:signals/signals.dart';

/// Base of every Beak view model: owns its [Signal]s, exposes them as
/// [ReadonlySignal]s, and disposes them together.
///
/// View models never `try/catch` — repositories are the catch boundary;
/// a view model only turns intents into repository calls and state.
abstract base class BeakViewModel {
  final List<void Function()> _cleanups = [];
  bool _isDisposed = false;

  /// Whether [dispose] has run.
  bool get isDisposed => _isDisposed;

  /// Creates a signal owned by this view model, disposed with it.
  ///
  /// Expose it upward as a [ReadonlySignal] field so widgets can read and
  /// watch — but never write — the state.
  @protected
  Signal<T> ownedSignal<T>(T value) {
    final owned = signal<T>(value);
    _cleanups.add(owned.dispose);
    return owned;
  }

  /// Releases every owned signal; further use is a programming error.
  @mustCallSuper
  void dispose() {
    for (final cleanup in _cleanups) {
      cleanup();
    }
    _cleanups.clear();
    _isDisposed = true;
  }
}
