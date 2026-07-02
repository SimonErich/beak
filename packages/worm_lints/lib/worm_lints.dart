/// Custom lint plugin entry point.
///
/// The `custom_lint` runner discovers this file via the
/// `worm_lints` package dependency and invokes [createPlugin]
/// to obtain the [PluginBase] instance that registers every
/// rule shipped by this package.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/no_ticket_reference_rule.dart';

export 'src/no_ticket_reference_rule.dart' show NoTicketReferenceRule;

/// Plugin entry point called by the `custom_lint` runner.
PluginBase createPlugin() => _WormLintsPlugin();

class _WormLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => <LintRule>[
    NoTicketReferenceRule(),
  ];
}
