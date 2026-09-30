import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:worm/testing/adapter_contract.dart';

import '../test_tools/serverpod_test_tools.dart';
import 'support/zone_bound_adapter.dart';

/// Worm's own adapter contract, run on Serverpod's database through the
/// session adapter: once with real transactions, and once inside
/// serverpod_test's per-test rollback (where every adapter transaction is a
/// savepoint, the shape most app test suites run Beak in).
void main() {
  withServerpod(
    'worm contract, committed transactions',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, endpoints) {
      runAdapterContractTests(
        name: 'ServerpodSessionAdapter contract (committed)',
        capabilities: contractCapabilities,
        adapterFactory: () =>
            ZoneBoundAdapter(sessionBuilder.build(), ServerpodSessionAdapter()),
      );
    },
  );

  withServerpod('worm contract, inside the test rollback', (
    sessionBuilder,
    endpoints,
  ) {
    runAdapterContractTests(
      name: 'ServerpodSessionAdapter contract (rolled back)',
      capabilities: contractCapabilities,
      adapterFactory: () =>
          ZoneBoundAdapter(sessionBuilder.build(), ServerpodSessionAdapter()),
    );
  });
}
