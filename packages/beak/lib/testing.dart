/// The testing toolkit: a complete in-memory data source, the executable
/// `BeakDataSource` contract, record factories, and the model-versus-migration
/// parity assertion.
///
/// ```dart
/// import 'package:beak/testing.dart';
///
/// final source = InMemoryBeakDataSource(registry: buildBeakRegistry())
///   ..seed(const ProductModel(), [beakFakeRecord(const ProductModel())]);
/// ```
library;

export 'package:beak_test/beak_test.dart';
