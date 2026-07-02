/// Test support: passes values through a non-const path so tests can
/// exercise runtime constructor bodies, asserts, and `==` implementations
/// that const canonicalization would otherwise skip.
library;

/// Returns [value] unchanged via a runtime call, defeating const inference.
T runtimeValue<T>(T value) => value;
