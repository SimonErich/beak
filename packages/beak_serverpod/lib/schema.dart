/// Annotations for Serverpod-backed definition classes, read by
/// `beak generate`.
///
/// One import gives a definitions package `@Resource`, `@Column`, the
/// relationship annotations and `@ServerpodModel`:
///
/// ```dart
/// import 'package:beak_core/beak_core.dart';
/// import 'package:beak_serverpod/schema.dart';
/// ```
library;

export 'package:beak_core/schema.dart';

export 'src/schema_annotations.dart';
