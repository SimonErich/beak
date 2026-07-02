/// Build-runner entry point for `worm` model code generation.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/worm_table_generator.dart';

export 'src/worm_table_generator.dart';

/// Builder factory referenced by `build.yaml`.
///
/// Produces a `SharedPartBuilder` that runs the
/// [WormTableGenerator] over every model annotated with
/// `@Table`.
Builder wormBuilder(BuilderOptions options) =>
    SharedPartBuilder(<Generator>[WormTableGenerator()], 'worm');
