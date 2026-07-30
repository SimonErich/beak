import 'package:shelf/shelf.dart';

import '../../auth/beak_auth_guard.dart';

const String _principalContextKey = 'beak.principal';

/// The principal the auth middleware resolved for [request], or `null` for
/// anonymous requests (or when no guard is installed).
BeakPrincipal? beakPrincipal(Request request) =>
    switch (request.context[_principalContextKey]) {
      final BeakPrincipal principal => principal,
      _ => null,
    };

/// Resolves the request's identity through [guard] and stores it in the
/// request context for handlers and policies; without a guard every
/// request stays anonymous.
///
/// Invalid credentials throw inside the guard and are mapped to 401 by the
/// error-mapping middleware.
// --8<-- [start:beakAuthMiddleware]
Middleware beakAuthMiddleware({BeakAuthGuard? guard}) =>
    (Handler inner) => (Request request) async {
      if (guard == null) {
        return inner(request);
      }
      final principal = await guard.authenticate(request);
      if (principal == null) {
        return inner(request);
      }
      return inner(request.change(context: {_principalContextKey: principal}));
    };

// --8<-- [end:beakAuthMiddleware]
