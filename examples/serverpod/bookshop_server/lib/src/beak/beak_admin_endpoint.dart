import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart';

import 'bookshop_beak_engine.dart';

/// The Beak admin tunnel: one method, gated by [BeakAdminGate] (a signed-in
/// user holding the `beak.admin` scope) before any Beak code runs.
class BeakAdminEndpoint extends Endpoint with BeakAdminGate {
  /// Runs one Beak request (envelope v1) and returns the response envelope.
  Future<String> dispatch(Session session, String request) =>
      bookshopBeak.dispatch(session, request);
}
