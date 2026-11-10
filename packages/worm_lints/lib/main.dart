/// Analyzer plugin entry point.
///
/// The analysis server finds this file through the `plugins:` entry of an
/// `analysis_options.yaml` that names `worm_lints`, and reads [plugin] to
/// register every rule this package ships.
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/no_ticket_reference_rule.dart';

/// The plugin the analysis server loads.
final WormLintsPlugin plugin = WormLintsPlugin();

/// Registers the worm lint rules with the analysis server.
class WormLintsPlugin extends Plugin {
  @override
  String get name => 'worm_lints';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(NoTicketReferenceRule());
  }
}
