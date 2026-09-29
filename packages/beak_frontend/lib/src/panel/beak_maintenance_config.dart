import 'package:meta/meta.dart';

/// Declarative maintenance / coming-soon configuration for a panel.
///
/// When set on `BeakPanelConfig.maintenance`, the router mounts
/// `/maintenance` and `/coming-soon`, each rendered with obers_ui's
/// `OiMaintenancePage` (with a live countdown when [estimatedReturn] or
/// [launchAt] is set).
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
}
