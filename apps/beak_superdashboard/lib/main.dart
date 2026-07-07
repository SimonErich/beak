import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';

import 'panel/config.dart';

export 'panel/config.dart' show buildSuperdashboardConfig;

/// The superdashboard demo app: one [BeakPanel] over the shared models,
/// reproducing a full admin theme entirely from seeded data.
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
