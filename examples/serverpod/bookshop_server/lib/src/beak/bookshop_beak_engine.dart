import 'package:beak_backend/beak_backend.dart';
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:bookshop_definitions/bookshop_definitions.dart';

// --8<-- [start:bookshopBeak]
/// The bookshop's Beak engine: one per process, shared by every request.
///
/// It serves Beak's stock API for the generated bookshop models on the
/// request's own Serverpod session, so every statement runs on Serverpod's
/// database with its transactions and logging.
final BeakServerpodEngine bookshopBeak = BeakServerpodEngine.admitted(
  models: bookshopModels,
  definitions: bookshopDefinitions,
  principal: BeakServerpodPrincipal.fromScopes,
  writes: BeakWriteBindings<BookshopWrite>(
    (binding) => switch (binding) {
      BookshopWrite.configuration => const BeakWriteHandler.stock(),
    },
  ),
);
// --8<-- [end:bookshopBeak]
