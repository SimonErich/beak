import 'dart:async';

import 'package:shelf/shelf.dart';

/// Inspects a request before it reaches any handler; throws a
/// `BeakException` (typically authorization) to deny it.
///
/// Phase 10 supplies the real guard; without one the slot passes through.
typedef BeakAuthGuard = FutureOr<void> Function(Request request);

/// Runs [guard] before the downstream handler; a thrown failure is mapped by
/// the error-mapping middleware.
Middleware beakAuthMiddleware({BeakAuthGuard? guard}) =>
    (Handler inner) => (Request request) async {
      if (guard != null) {
        await guard(request);
      }
      return inner(request);
    };
