import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:bookshop_definitions/bookshop_definitions.dart';

import 'book_admin_handler.dart';
import 'generated/bookshop_handlers.dart';

// --8<-- [start:bookshopBeak]
/// The bookshop's Beak engine: one per process, shared by every request.
///
/// It serves Beak's stock API for the bookshop's definition classes on the
/// request's own Serverpod session, so every statement runs on Serverpod's
/// database with its transactions and logging. Book runs its restock command
/// through the app's typed handler; Author is saved the stock way.
final BeakServerpodEngine bookshopBeak = BeakServerpodEngine.admitted(
  models: bookshopModels,
  handlers: const BookshopHandlers(book: BookAdminHandler()),
  principal: BeakServerpodPrincipal.fromScopes,
);
// --8<-- [end:bookshopBeak]
