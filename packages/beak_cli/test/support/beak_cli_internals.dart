/// Every `beak_cli` internal the suites exercise directly.
///
/// The package's public barrel exports only what a `bin/` entry point needs,
/// the runner and its seams. The suites assert on the emitters, the IR and
/// the scanner one by one, so they reach them here rather than by widening
/// the barrel again.
library;

export 'package:beak_cli/beak_cli.dart';
export 'package:beak_cli/src/agents/beak_agent_files.dart';
export 'package:beak_cli/src/agents/beak_project_kind.dart';
export 'package:beak_cli/src/agents/beak_skill_installer.dart';
export 'package:beak_cli/src/cli_runner.dart';
export 'package:beak_cli/src/commands/agents_command.dart';
export 'package:beak_cli/src/commands/create_command.dart';
export 'package:beak_cli/src/commands/dev_command.dart';
export 'package:beak_cli/src/commands/docs_command.dart';
export 'package:beak_cli/src/commands/doctor_command.dart';
export 'package:beak_cli/src/commands/eject_command.dart';
export 'package:beak_cli/src/commands/init_command.dart';
export 'package:beak_cli/src/commands/introspect_command.dart';
export 'package:beak_cli/src/commands/prepare_command.dart';
export 'package:beak_cli/src/field_spec.dart';
export 'package:beak_cli/src/introspect/beak_introspection_emitter.dart';
export 'package:beak_cli/src/introspect/beak_live_schema.dart';
export 'package:beak_cli/src/introspect/beak_schema_introspection.dart';
export 'package:beak_cli/src/introspect/postgres_introspector.dart';
export 'package:beak_cli/src/introspect/sqlite_introspector.dart';
export 'package:beak_cli/src/project/beak_authored_main.dart';
export 'package:beak_cli/src/project/beak_discovery.dart';
export 'package:beak_cli/src/project/beak_emitters.dart';
export 'package:beak_cli/src/project/beak_project_config.dart';
export 'package:beak_cli/src/schema/beak_drift_migration_emitter.dart';
export 'package:beak_cli/src/schema/beak_migration_emitter.dart';
export 'package:beak_cli/src/schema/beak_schema_drift.dart';
export 'package:beak_cli/src/schema/beak_schema_emitter.dart';
export 'package:beak_cli/src/schema/beak_schema_ir.dart';
export 'package:beak_cli/src/schema/beak_schema_reader.dart';
export 'package:beak_cli/src/templates.dart';
export 'package:beak_cli/src/version.dart';
