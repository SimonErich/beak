/// A place in the panel a user can be sent to: a `BeakScreen` or a
/// `BeakResource`.
///
/// Used where the panel needs one typed reference to either, such as
/// `BeakPanelConfig.home`, so a host never spells a route string.
abstract interface class BeakDestination {
  /// The router location this destination is served at: a screen's path or a
  /// resource's list route.
  String get location;
}
