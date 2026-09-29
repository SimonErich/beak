import 'package:beak_core/beak_core.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

// --8<-- [start:BeakDataChange]
/// Invalidated model tables after confirmed writes or a remote refresh tick.
final class BeakDataChange {
  /// Captures an immutable set of affected model tables.
  BeakDataChange(Iterable<String> tables) : tables = Set.unmodifiable(tables);

  /// Includes written tables and owners whose relationships reference them.
  final Set<String> tables;

  /// Whether a loaded surface for [table] should query again.
  bool affects(String table) => tables.contains(table);
}
// --8<-- [end:BeakDataChange]

/// Optional reactive capability supplied automatically by the panel's source.
abstract interface class BeakMutationSource {
  /// Emits after confirmed writes or an explicitly configured remote refresh.
  Stream<BeakDataChange> get changes;
}

// --8<-- [start:useBeakDataRevision]
/// Rebuilds a loaded surface after a relevant mutation without app wiring.
///
/// A null [table] observes all writes in this source. The subscription belongs
/// to the widget and is canceled when it unmounts or changes sources.
int useBeakDataRevision(BeakDataSource? source, {String? table}) {
  final revision = useState(0);
  useEffect(() {
    if (source case final BeakMutationSource observable) {
      final subscription = observable.changes.listen((change) {
        if (table == null || change.affects(table)) revision.value++;
      });
      return subscription.cancel;
    }
    return null;
  }, [source, table]);
  return revision.value;
}
// --8<-- [end:useBeakDataRevision]

/// Optional remote refresh policy shared by all mounted panel data consumers.
final class BeakRefreshPolicy {
  /// Invalidates loaded data periodically and/or after returning to foreground.
  const BeakRefreshPolicy({this.interval, this.onResume = true});

  /// Poll cadence; null relies on local writes and foreground resume only.
  final Duration? interval;

  /// Refreshes when the application returns from a background lifecycle state.
  final bool onResume;
}
