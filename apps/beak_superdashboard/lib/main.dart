import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';

/// Builds the superdashboard panel configuration.
///
/// This is the single declarative entry point of the demo. It starts empty
/// and is filled out across the build phases with the full Tocly-style
/// resource, page, dashboard, and app-module set — every screen driven from
/// seeded data, no per-page plumbing.
///
/// [apiBaseUrl] points the panel's HTTP data source at the running
/// superdashboard server binary (`bin/server.dart`); override it to target a
/// non-local backend.
BeakPanelConfig buildSuperdashboardConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Superdashboard',
  apiBaseUrl: apiBaseUrl,
  resources: const [],
);

/// The superdashboard demo app: one [BeakPanel] over the shared models.
final class SuperdashboardApp extends StatelessWidget {
  /// Creates the app; [dataSource] injects a fake in widget tests.
  const SuperdashboardApp({this.dataSource, super.key});

  /// Test seam replacing the HTTP-backed data source.
  final BeakDataSource? dataSource;

  @override
  Widget build(BuildContext context) =>
      BeakPanel(config: buildSuperdashboardConfig(), dataSource: dataSource);
}

/// Boots the Flutter superdashboard against the default local backend.
void main() => runApp(const SuperdashboardApp());
