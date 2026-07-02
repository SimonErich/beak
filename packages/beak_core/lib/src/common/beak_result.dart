import 'package:meta/meta.dart';

import 'beak_exception.dart';

/// The outcome of a fallible operation: either a [BeakOk] carrying a value
/// or a [BeakErr] carrying a [BeakException].
///
/// Use this for value-level composition where a failure should travel with
/// the data instead of unwinding the stack. Exceptions remain the mechanism
/// at layer boundaries (Shelf handlers, repositories) per the layering rule.
@immutable
sealed class BeakResult<T> {
  const BeakResult();

  /// Whether this result is a [BeakOk].
  bool get isOk;

  /// The success value; throws the wrapped [BeakException] on a [BeakErr].
  T get valueOrThrow;

  /// Reduces both cases into a single value of type [R].
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(BeakException error) onErr,
  });

  /// Transforms the success value with [transform], leaving errors untouched.
  BeakResult<R> map<R>(R Function(T value) transform);
}

/// The successful [BeakResult], carrying the produced [value].
final class BeakOk<T> extends BeakResult<T> {
  /// Wraps [value] as a successful result.
  const BeakOk(this.value);

  /// The value produced by the operation.
  final T value;

  @override
  bool get isOk => true;

  @override
  T get valueOrThrow => value;

  @override
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(BeakException error) onErr,
  }) => onOk(value);

  @override
  BeakResult<R> map<R>(R Function(T value) transform) =>
      BeakOk<R>(transform(value));
}

/// The failed [BeakResult], carrying the [error] that prevented a value.
final class BeakErr<T> extends BeakResult<T> {
  /// Wraps [error] as a failed result.
  const BeakErr(this.error);

  /// The failure that prevented a value from being produced.
  final BeakException error;

  @override
  bool get isOk => false;

  @override
  T get valueOrThrow => throw error;

  @override
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(BeakException error) onErr,
  }) => onErr(error);

  @override
  BeakResult<R> map<R>(R Function(T value) transform) => BeakErr<R>(error);
}
