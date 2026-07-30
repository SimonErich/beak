import 'package:worm/src/adapter/adapter_capabilities.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/testing/adapter_contract.dart';

void main() {
  runAdapterContractTests(
    adapterFactory: InMemoryAdapter.new,
    capabilities: const AdapterCapabilities(
      supportsTransactions: true,
      supportsStreaming: true,
      supportsReturning: true,
      supportsAggregations: true,
      supportsSchemaIntrospection: true,
      supportsColumnAlterations: true,
      supportsExplain: true,
    ),
    name: 'InMemoryAdapter contract',
  );
}
