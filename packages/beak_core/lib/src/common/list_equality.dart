/// Internal element-wise list equality for beak_core's immutable value
/// objects (filters, query specs, pages). Not exported by the barrel.
library;

/// Whether [a] and [b] have equal lengths and pairwise-equal elements.
bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
