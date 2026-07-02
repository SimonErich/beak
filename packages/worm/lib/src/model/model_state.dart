/// Mutable per-model state container.
library;

/// Mutable holder for one Model's tracked state.
///
/// Holds the live attribute map, the original snapshot used for
/// dirty tracking, the set of mutated keys, the persisted flag,
/// the `withoutTimestamps` flag, and any pending `afterCommit`
/// callbacks. Owned exclusively by the Model instance it
/// belongs to — direct mutation from outside the model is not
/// supported.
final class ModelState {
  /// Creates an empty [ModelState].
  ModelState();

  /// Live attribute values keyed by column name.
  final Map<String, Object?> attributes = <String, Object?>{};

  /// Snapshot of attribute values at the last persisted state.
  final Map<String, Object?> original = <String, Object?>{};

  /// Set of attribute keys mutated since the last sync.
  final Set<String> dirty = <String>{};

  /// Whether the model has been persisted at least once.
  bool exists = false;

  /// Whether `withoutTimestamps` is currently active.
  bool withoutTimestamps = false;

  /// Pending callbacks queued via `afterCommit`.
  final List<void Function()> afterCommitCallbacks = <void Function()>[];

  /// Replace [original] with a copy of [attributes] and clear
  /// [dirty]. Called after every successful save.
  void syncOriginal() {
    original
      ..clear()
      ..addAll(attributes);
    dirty.clear();
  }

  /// Apply [value] for [name] and update dirty tracking.
  ///
  /// Equal-value writes still mark the key dirty when the key
  /// was previously absent, so attribute initialisation
  /// participates in the dirty set as expected.
  void setAttribute(String name, Object? value) {
    final hadKey = attributes.containsKey(name);
    final previous = attributes[name];
    attributes[name] = value;
    if (!hadKey || previous != value) {
      dirty.add(name);
    }
  }

  /// Seed an attribute without marking it dirty.
  ///
  /// Used by generated hydrators to load row values into the
  /// model. After all attributes are seeded the hydrator must
  /// call [syncOriginal] and set [exists] to `true`.
  void seedAttribute(String name, Object? value) {
    attributes[name] = value;
  }
}
