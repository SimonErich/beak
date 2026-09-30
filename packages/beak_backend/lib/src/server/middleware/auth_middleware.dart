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

/// The paths of the health probes, relative to the root the API is mounted at.
///
/// A platform's probe carries whatever credentials it carries (none, or a
/// header meant for another service), so [beakAuthMiddleware] never asks the
/// guard about these paths.
const Set<String> beakProbePaths = {'healthz', 'readyz'};

/// The sign-in path. The credentials are in the body, so an `Authorization`
/// header a client still holds from an expired session is not asked about
/// here: it would answer 401 to the very request that replaces it.
const String _loginPath = 'api/auth/login';

/// Resolves the request's identity through [guard] and stores it in the
/// request context for handlers and policies; without a guard every
/// request stays anonymous.
///
/// Invalid credentials throw inside the guard and are mapped to 401 by the
/// error-mapping middleware. The [beakProbePaths] are the exception: they
/// stay anonymous, so an `Authorization` header a load balancer adds cannot
/// take a healthy server out of rotation. So is `/api/auth/login`, which
/// carries its credentials in the body.
// --8<-- [start:beakAuthMiddleware]
Middleware beakAuthMiddleware({BeakAuthGuard? guard}) =>
    (Handler inner) => (Request request) async {
      final String path = request.url.path;
      if (guard == null ||
          beakProbePaths.contains(path) ||
          path == _loginPath) {
        return inner(request);
      }
      final principal = await guard.authenticate(request);
      if (principal == null) {
        return inner(request);
      }
      return inner(request.change(context: {_principalContextKey: principal}));
    };

// --8<-- [end:beakAuthMiddleware]
