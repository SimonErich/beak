/// Observer marker type for model lifecycle hooks.
library;

/// Base type for model observers.
///
/// The full lifecycle hook machinery lands in a
/// later epic. This marker type exists so
/// `Worm.initialize` can accept observer
/// registrations that future epics wire through to
/// the event dispatcher.
abstract class Observer<T> {
  /// Creates an [Observer].
  const Observer();

  /// The model type this observer observes.
  Type get modelType => T;
}
