import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

/// Carries the record a screen is rendering down to the record-bound blocks
/// (`BeakFieldBlock`, `BeakFieldGroupBlock`, `BeakRelationBlock`), so a record
/// sheet can be a plain, `const` block tree while its field leaves still
/// resolve their values from the one loaded record.
///
/// No built-in page mounts this scope. A screen that shows a record with these
/// blocks (a `BeakCustomResourceScreen`, say) loads the record and wraps the
/// tree in a scope itself; the record-bound blocks read it with
/// [BeakRecordScope.of]. Reading a field block outside a scope renders nothing
/// rather than throwing, so a sheet that comes up blank is usually missing its
/// scope.
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
