import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import 'pages/chart_blocks.dart';
import 'pages/content_blocks.dart';
import 'pages/data_blocks.dart';
import 'pages/layout_blocks.dart';
import 'pages/map_blocks.dart';
import 'pages/module_blocks.dart';
import 'resources/habitats/habitat_resource.dart';
import 'resources/keepers/keeper_resource.dart';
import 'resources/specimens/specimen_resource.dart';
import 'resources/tasks/task_resource.dart';
import 'widgets/band_code_cell.dart';

/// Boots the panel.
void main() {
  registerAviaryRenderers();
  runApp(buildPanel());
}

/// The panel: four resources and one page per block category.
///
/// [dataSource] replaces the HTTP-backed source, so a widget test can pump this
/// exact panel against an in-memory one.
// --8<-- [start:buildPanel]
BeakPanel buildPanel({BeakDataSource? dataSource}) => BeakPanel(
  title: 'The Aviary',
  theme: OiThemeData.fromBrand(color: const Color(0xFF2F7D6B)),
  darkTheme: OiThemeData.fromBrand(
    color: const Color(0xFF7FC4B2),
    brightness: Brightness.dark,
  ),
  locale: const Locale('en'),
  formatting: const BeakFormatting(locale: 'en_GB', currency: 'EUR'),
  apiBaseUrl: const String.fromEnvironment(
    'BEAK_API_BASE_URL',
    defaultValue: 'http://localhost:8082',
  ),
  resources: [
    SpecimenResource(),
    HabitatResource(),
    KeeperResource(),
    TaskResource(),
  ],
  pages: [
    dataBlocksPage(),
    layoutBlocksPage(),
    contentBlocksPage(),
    plannerPage(),
    chartBlocksPage(),
    mapBlocksPage(),
    chatPage(),
    inboxPage(),
    filesPage(),
    mediaPage(),
    documentsPage(),
    faqPage(),
  ],
  dataSource: dataSource,
);
// --8<-- [end:buildPanel]
