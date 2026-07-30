import 'package:beak/server.dart';

import 'models/order.dart';
import 'models/user.dart';
import 'seeders/store_seeder.dart';

/// Builds the store's server on top of everything Beak resolved.
///
/// [defaults] already carries the database connection, the model registry and
/// the upload driver; this adds the two things a real store needs and Beak
/// cannot guess: who may log in, and which rows each of them sees.
// --8<-- [start:beakServer]
BeakServer beakServer(BeakServerDefaults defaults) {
  final String secret =
      defaults.environment['AUTH_SECRET'] ?? 'store-dev-secret';
  final store = InMemoryTokenSessionStore();
  return defaults.build(
    policy: const StorePolicy(),
    authSessions: BeakAuthSessions(
      store: store,
      secret: secret,
      users: [
        BeakUserAccount(
          username: 'ada@example.com',
          passwordHash: hashBeakPassword('espresso', secret: secret),
          principal: const BeakPrincipal(
            id: StoreSeedIds.userAda,
            roles: {'staff'},
          ),
        ),
        BeakUserAccount(
          username: 'linus@example.com',
          passwordHash: hashBeakPassword('grinder', secret: secret),
          principal: const BeakPrincipal(
            id: StoreSeedIds.userLinus,
            roles: {'customer'},
          ),
        ),
      ],
    ),
    authGuard: TokenSessionAuthGuard(store),
  );
}
// --8<-- [end:beakServer]

/// Who may do what, and to which rows.
///
/// Three rules, all enforced in the API rather than in the panel, so a client
/// that skips the panel does not skip them:
///
/// - the catalog is public; orders and customers need an account;
/// - a signed-in customer sees only their own orders, and nothing of the user
///   table but their own row;
/// - only staff may delete anything.
///
/// The difference between the first two is deliberate. Refusing to answer is
/// a 403 ([canView]); answering with the rows that are theirs is a scope
/// ([scopeFor]) — the request succeeds and the rest simply is not there.
// --8<-- [start:StorePolicy]
final class StorePolicy extends BeakAllowAllPolicy implements BeakRowPolicy {
  /// Creates the policy.
  const StorePolicy();

  /// Tables that need an account, whoever it belongs to.
  static const Set<String> _private = {'orders', 'users'};

  @override
  bool canView(BeakPrincipal? principal, String table) =>
      principal != null || !_private.contains(table);

  @override
  bool canDelete(BeakPrincipal? principal, String table, Object id) =>
      principal?.hasRole('staff') ?? false;

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, String table) {
    // Staff see everything; an anonymous caller never gets this far on a
    // private table, because [canView] already refused.
    if (principal == null || principal.hasRole('staff')) {
      return null;
    }
    final String ownerId = principal.id;
    return switch (table) {
      'orders' => BeakFieldFilter(
        column: OrderColumns.customerId,
        operator: BeakOperator.eq,
        value: BeakValue.of(ownerId),
      ),
      'users' => BeakFieldFilter(
        column: UserColumns.id,
        operator: BeakOperator.eq,
        value: BeakValue.of(ownerId),
      ),
      _ => null,
    };
  }
}

// --8<-- [end:StorePolicy]
