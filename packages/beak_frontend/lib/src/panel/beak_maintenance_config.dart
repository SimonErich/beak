import 'package:meta/meta.dart';

/// One of the two pages a [BeakMaintenanceConfig] can send visitors to.
enum BeakMaintenancePage {
  /// `/maintenance`: the panel is temporarily unavailable.
  maintenance,

  /// `/coming-soon`: the panel has not launched yet.
  comingSoon,
}

/// Declarative maintenance / coming-soon configuration for a panel.
///
/// When set on `BeakPanelConfig.maintenance`, the router mounts
/// `/maintenance` and `/coming-soon`, each rendered with obers_ui's
/// `OiMaintenancePage` (with a live countdown when [estimatedReturn] or
/// [launchAt] is set). Set [redirectTo] to send every visitor to one of them.
/// The pages are presentation only: the API keeps answering.
@immutable
final class BeakMaintenanceConfig {
  /// Creates a maintenance configuration.
  // --8<-- [start:BeakMaintenanceConfig]
  const BeakMaintenanceConfig({
    this.maintenanceTitle = 'Under maintenance',
    this.maintenanceDescription,
    this.estimatedReturn,
    this.comingSoonTitle = 'Coming soon',
    this.comingSoonDescription,
    this.launchAt,
    this.redirectTo,
  });
  // --8<-- [end:BeakMaintenanceConfig]

  /// Heading of the `/maintenance` screen.
  final String maintenanceTitle;

  /// Supporting copy of the `/maintenance` screen.
  final String? maintenanceDescription;

  /// When service is expected back; drives the maintenance countdown.
  final DateTime? estimatedReturn;

  /// Heading of the `/coming-soon` screen.
  final String comingSoonTitle;

  /// Supporting copy of the `/coming-soon` screen.
  final String? comingSoonDescription;

  /// Launch moment; drives the coming-soon countdown.
  final DateTime? launchAt;

  /// The page every other route redirects to, or `null` to only mount the
  /// pages and let a link, a script or a proxy send people there.
  ///
  /// The other page stays reachable, so a launch page can be previewed during
  /// a maintenance window. Signed-out visitors are redirected too, ahead of
  /// the sign-in page.
  final BeakMaintenancePage? redirectTo;
}
