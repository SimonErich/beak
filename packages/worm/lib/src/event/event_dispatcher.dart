/// Lifecycle event dispatcher for models.
library;

import '../model/model.dart';
import '../registry/worm.dart';
import 'lifecycle_event.dart';
import 'lifecycle_handler.dart';

/// Dispatches lifecycle events to a model's own hooks and every
/// registered [LifecycleHandler].
///
/// Each `before*` event is invoked first on the model itself, then
/// on each handler in registration order. If any returns `false`
/// the dispatcher stops invoking remaining handlers and reports the
/// cancellation to its caller, which must skip the database call
/// and all subsequent hooks for that operation.
///
/// `after*` events are dispatched in order; if a handler throws, the
/// throw propagates and remaining handlers are skipped.
final class EventDispatcher {
  /// Creates an [EventDispatcher] that fans events out to
  /// [handlers] in registration order.
  const EventDispatcher(this.handlers);

  /// The handlers this dispatcher notifies.
  final List<LifecycleHandler> handlers;

  /// Dispatch a cancelable `before*` event.
  ///
  /// Returns `false` if the model hook or any handler returned
  /// `false`; returns `true` otherwise. Throws [ArgumentError] if
  /// [event] is not cancelable.
  Future<bool> dispatchBefore(LifecycleEvent event, Model model) async {
    if (!isCancelable(event)) {
      throw ArgumentError.value(
        event,
        'event',
        'dispatchBefore requires a cancelable event',
      );
    }
    // A muted before-hook cannot cancel — the operation proceeds.
    if (Worm.isEventMuted(event)) return true;
    final modelResult = await model.invokeHook(event);
    if (!modelResult) return false;
    for (final handler in handlers) {
      final ok = await handler.dispatchBefore(event, model);
      if (!ok) return false;
    }
    return true;
  }

  /// Dispatch a non-cancelable `after*` event.
  ///
  /// Throws [ArgumentError] if [event] is cancelable.
  Future<void> dispatchAfter(LifecycleEvent event, Model model) async {
    if (isCancelable(event)) {
      throw ArgumentError.value(
        event,
        'event',
        'dispatchAfter requires a non-cancelable event',
      );
    }
    if (Worm.isEventMuted(event)) return;
    await model.invokeAfterHook(event);
    for (final handler in handlers) {
      await handler.dispatchAfter(event, model);
    }
  }
}
