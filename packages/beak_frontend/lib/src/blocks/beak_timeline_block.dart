part of 'beak_block.dart';

/// A data-bound vertical timeline — each row becomes an event. Renders onto
/// `OiTimeline`.
final class BeakTimelineBlock extends BeakBlock {
  /// Creates a timeline over [query].
  const BeakTimelineBlock({
    required this.query,
    required this.titleField,
    required this.timeField,
    super.span,
  });

  /// The query producing one row per event.
  final BeakQuerySpec query;

  /// The column holding each event's title.
  final BeakColumn titleField;

  /// The column holding each event's timestamp.
  final BeakColumn timeField;
}
