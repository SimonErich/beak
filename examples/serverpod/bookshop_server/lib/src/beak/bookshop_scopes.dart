import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart';

/// The scopes of the bookshop admin, kept in one place like Serverpod's
/// `Scope.admin`.
///
/// `beak.admin` only opens the Beak tunnel. What an admin may then do is
/// decided by the policy, and the policy reads the other scopes.
abstract final class BookshopScopes {
  /// Opens the Beak tunnel (`beak.admin`); the gate on `BeakAdminEndpoint`.
  static const Scope admin = BeakScopes.admin;

  /// May read and write authors and books in the admin.
  static const Scope staff = Scope('bookshop.staff');
}
