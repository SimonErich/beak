/// Bridge interface for typed observers.
library;

import '../model/model.dart';
import 'lifecycle_event.dart';

/// Type-erased dispatch entry point used by `EventDispatcher`.
///
/// Implementations route a [LifecycleEvent] / [Model] pair into
/// their own typed hooks. The `ModelObserver` mixin supplies the
/// canonical implementation; advanced consumers may implement this
/// interface directly to wire custom handlers (e.g. metrics,
/// audit pipelines) into the event stream.
abstract interface class LifecycleHandler {
  /// Dispatch a cancelable `before*` event.
  ///
  /// Returns `false` to cancel the surrounding operation. Handlers
  /// must skip events whose model is not the type they observe and
  /// return `true` in that case.
  Future<bool> dispatchBefore(LifecycleEvent event, Model model);

  /// Dispatch a non-cancelable `after*` event.
  ///
  /// Handlers must skip events whose model is not the type they
  /// observe.
  Future<void> dispatchAfter(LifecycleEvent event, Model model);
}
