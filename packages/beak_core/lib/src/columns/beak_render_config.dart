import 'package:meta/meta.dart';

import '../context/beak_context.dart';
import '../context/beak_render_intent.dart';

/// The per-context render intents of a column: which [BeakRenderIntent] the
/// column resolves to in a table cell, a form input, a detail entry, and a
/// filter control.
///
/// This is the "define once, render everywhere" pivot: a [BeakColumn]
/// declares one config, and `beak_frontend` maps each intent to the matching
/// obers_ui widget per surface. Use [BeakRenderConfig.uniform] when every
/// surface renders the same way, or the default constructor to differ by
/// surface (as [BeakDateTimeColumn] does — a relative timestamp in tables but
/// an absolute picker in forms):
///
/// ```dart
/// // Same widget everywhere.
/// const config = BeakRenderConfig.uniform(BeakRenderIntent.text);
///
/// // A picker in forms, a thumbnail in tables.
/// const imageConfig = BeakRenderConfig(
///   table: BeakRenderIntent.thumbnail,
///   form: BeakRenderIntent.image,
///   detail: BeakRenderIntent.image,
///   filter: BeakRenderIntent.custom,
/// );
/// ```
@immutable
final class BeakRenderConfig {
  /// Creates a config with an explicit intent per context.
  const BeakRenderConfig({
    required this.table,
    required this.form,
    required this.detail,
    required this.filter,
  });

  /// Creates a config that renders with the same [intent] in every context.
  const BeakRenderConfig.uniform(BeakRenderIntent intent)
    : this(table: intent, form: intent, detail: intent, filter: intent);

  /// Intent used inside table cells.
  final BeakRenderIntent table;

  /// Intent used inside form inputs.
  final BeakRenderIntent form;

  /// Intent used inside detail views.
  final BeakRenderIntent detail;

  /// Intent used inside filter controls.
  final BeakRenderIntent filter;

  /// The intent this config resolves to for [context].
  BeakRenderIntent intentFor(BeakContext context) => switch (context) {
    BeakContext.table => table,
    BeakContext.form => form,
    BeakContext.detail => detail,
    BeakContext.filter => filter,
  };
}
