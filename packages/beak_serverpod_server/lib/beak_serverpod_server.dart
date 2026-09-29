/// Beak inside a Serverpod 4 server.
///
/// - [BeakServerpodEngine]: Beak's stock Shelf pipeline run in memory behind
///   one endpoint method (envelope v1), with the principal taken from the
///   Serverpod session and [BeakAdminGate] in front.
/// - [ServerpodSessionAdapter]: a worm adapter over the request Session's
///   own pool and transactions, so Beak's `WormDataSource` and graph commits
///   run on Serverpod's database with nothing extra to deploy.
/// - [BeakServerpod]: the zone that carries the Session into Beak, plus the
///   `sessionOf`/`transactionOf` hand-off for typed ORM writes inside a Beak
///   transaction.
/// - [beakServerpodFrameworkTables]: Beak's graph-commit receipts on the
///   tool-owned Serverpod model.
library;

export 'src/beak_admin_gate.dart';
export 'src/beak_serverpod.dart';
export 'src/beak_serverpod_engine.dart';
export 'src/beak_serverpod_framework_tables.dart';
export 'src/beak_tunnel_path.dart';
export 'src/serverpod_database_bridge.dart';
export 'src/serverpod_session_adapter.dart';
