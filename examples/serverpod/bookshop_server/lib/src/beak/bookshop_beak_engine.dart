import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:bookshop_beak/bookshop_beak.dart';

import 'bookshop_policy.dart';

/// The bookshop's Beak engine: one per process, shared by every request.
///
/// It serves Beak's stock API for the models in `bookshop_beak` on the
/// request's own Serverpod session, so every statement runs on Serverpod's
/// database with its transactions and logging.
final BeakServerpodEngine bookshopBeak = BeakServerpodEngine(
  registry: buildBeakRegistry(),
  policy: bookshopPolicy,
);
