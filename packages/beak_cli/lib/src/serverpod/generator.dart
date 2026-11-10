import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../cli_runner.dart';
import '../labels/project_label_loader.dart';
import '../project/beak_project_config.dart';
import '../schema/beak_schema_emitter.dart';
import '../version.dart';
import 'database_definition.dart';
import 'definition_set_builder.dart';
import 'definition_libraries.dart';
import 'definition_reader.dart';
import 'generate_issue.dart';
import 'generate_sync.dart';
import 'handler_emitter.dart';
import 'serverpod_ir.dart';
import 'spy_reader.dart';
import 'definition_model.dart';
import 'generate_settings.dart';

export 'generate_sync.dart' show beakGeneratedHeader;

part 'generator_handlers.dart';
part 'generator_helpers.dart';
part 'generator_run.dart';

/// What one `beak generate` run did.
final class BeakGenerateResult {
  /// Creates a result.
  const BeakGenerateResult({
    this.written = const [],
    this.unchanged = const [],
    this.removed = const [],
    this.problems = const [],
    this.warnings = const [],
  });

  /// Generated files whose contents changed.
  final List<String> written;

  /// Generated files already up to date.
  final List<String> unchanged;

  /// Generated files nothing produces any more.
  final List<String> removed;

  /// Why `--check` failed, or an empty list when the output is current.
  final List<String> problems;

  /// What is worth fixing but does not fail the run, such as a shown field
  /// without a label in some language.
  final List<String> warnings;

  /// Whether the output is current (a check) or was made current (a run).
  bool get isSuccess => problems.isEmpty;

  /// The process exit code.
  int get exitCode => isSuccess ? 0 : 1;
}
