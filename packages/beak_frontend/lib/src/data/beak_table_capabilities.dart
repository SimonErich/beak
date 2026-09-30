import 'package:beak_core/beak_core.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'beak_resource_repository.dart';

// --8<-- [start:useBeakTableCapabilities]
/// What the server lets the current account do with the records of [table],
/// so a screen can leave out the create button or the delete action it would
/// only refuse.
///
/// Until the answer arrives, and when the source cannot answer or fails to,
/// everything is allowed: the capabilities guide presentation and the server
/// rechecks its policy on every request. Pass [recordId] to ask about one
/// record, for a policy that decides per record.
BeakAccessCapabilities useBeakTableCapabilities(
  BeakDataSource source,
  String table, {
  Object? recordId,
}) {
  final capabilities = useState(const BeakAccessCapabilities());
  useEffect(() {
    var active = true;
    if (source case final BeakCapabilityDataSource capable) {
      BeakResourceRepository(
        source,
      ).run(() => capable.capabilities(table, id: recordId)).then((result) {
        if (!active) return;
        if (result case BeakOk(:final value)) capabilities.value = value;
      });
    }
    return () => active = false;
  }, [source, table, recordId]);
  return capabilities.value;
}
// --8<-- [end:useBeakTableCapabilities]
