/// Internal key/value map equality for beak_core's immutable value objects
/// (records and friends). Not exported by the barrel.
library;

/// Whether [a] and [b] hold the same keys mapped to equal values.
///
/// Values compare with `==` unless [valueEquals] overrides the comparison —
/// e.g. to compare list-valued maps element-wise.
bool mapEquals<K, V extends Object>(
  Map<K, V> a,
  Map<K, V> b, {
  bool Function(V left, V right)? valueEquals,
}) {
  if (a.length != b.length) {
    return false;
  }
  final bool Function(V left, V right) equals = valueEquals ?? _defaultEquals;
  for (final MapEntry(:key, :value) in a.entries) {
    final V? counterpart = b[key];
    if (counterpart == null || !equals(value, counterpart)) {
      return false;
    }
  }
  return true;
}

bool _defaultEquals(Object left, Object right) => left == right;
