import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

/// Carries the record a detail layout is rendering down to the record-bound
/// blocks (`BeakFieldBlock`, `BeakFieldGroupBlock`, `BeakRelationBlock`), so a
/// resource's `detail` layout can be a plain, `const` block tree while its
/// field leaves still resolve their values from the one loaded record.
///
/// The show page wraps a resource's custom detail layout in this scope; the
/// record-bound blocks read it with [BeakRecordScope.of]. Reading a field
/// block outside a scope renders nothing rather than throwing, so the blocks
/// degrade gracefully if composed in the wrong place.
// --8<-- [start:BeakRecordScope]
class BeakRecordScope extends InheritedWidget {
  /// Provides [record] (described by [model]) to [child]'s subtree.
  const BeakRecordScope({
    required this.model,
    required this.record,
    required super.child,
    super.key,
  });

  /// The model describing [record]'s columns and relations.
  final BeakModel model;

  /// The record on display.
  final BeakRecord record;

  /// The nearest record scope above [context], or `null` when there is none.
  static BeakRecordScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeakRecordScope>();

  @override
  bool updateShouldNotify(BeakRecordScope oldWidget) =>
      oldWidget.record != record || oldWidget.model != model;
}
// --8<-- [end:BeakRecordScope]
