/// Testing toolkit for Beak.
///
/// Four things, each replacing something projects had been hand-rolling:
///
/// - [InMemoryBeakDataSource] — a *complete* [BeakDataSource] over maps.
///   Every fake in this repository used to ignore the query spec, so a green
///   widget test proved nothing about filtering, sorting or paging.
/// - [BeakRecordingDataSource] — wraps any source and records every call, for
///   the tests that assert *how many* round trips a screen costs.
/// - `runBeakDataSourceContract` — an executable definition of done for the
///   nine-method interface, so a third-party adapter can prove it behaves.
/// - [beakFakeRecord] and `expectSchemaParity` — fixtures derived from column
///   metadata, and the model-vs-migration check both demo apps wrote twice.
library;

export 'src/beak_record_factory.dart';
export 'src/beak_recording_data_source.dart';
export 'src/beak_schema_parity.dart';
export 'src/data_source_contract.dart';
export 'src/in_memory_beak_data_source.dart';
