import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

/// The authenticated identity and the host application's panel access decision.
class BeakAuthIdentity {
  /// Describes an existing identity without creating a second token store.
  const BeakAuthIdentity({
    required this.id,
    this.displayName,
    this.canAccessPanel = true,
  });

  /// Stable identifier supplied by the authentication backend.
  final Object id;

  /// Optional human-readable name used by the panel chrome.
  final String? displayName;

  /// Whether the domain's current permission rules allow panel access.
  final bool canAccessPanel;
}

/// A resolved session or its initialization state.
sealed class BeakAuthState {
  /// Creates an authentication state.
  const BeakAuthState();
}

/// The stored session and application permissions are being resolved.
final class BeakAuthLoading extends BeakAuthState {
  /// Creates a pending state.
  const BeakAuthLoading();
}

/// No device session remains.
final class BeakAuthGuest extends BeakAuthState {
  /// Creates a signed-out state.
  const BeakAuthGuest();
}

/// The backend identity and its current access decision have resolved.
final class BeakAuthAuthenticated extends BeakAuthState {
  /// Creates a resolved identity state.
  const BeakAuthAuthenticated(this.identity);

  /// Backend identity with the host's authorization decision.
  final BeakAuthIdentity identity;
}

/// Initialization failed; protected pages must remain inaccessible.
final class BeakAuthFailure extends BeakAuthState {
  /// Creates a failed resolution.
  const BeakAuthFailure(this.error);

  /// Typed failure, translated by Beak's auth presentation.
  final BeakException error;
}

/// Backend-neutral authentication and session authority used by Beak screens.
///
/// Implementations are the error boundary: operations return typed failures and
/// never expose transport exceptions to widgets. The adapter owns session state;
/// a host must not mirror its credentials into another Beak token store.
abstract class BeakAuthAdapter {
  /// Live state consumed by the router and authentication initialization gate.
  ReadonlySignal<BeakAuthState> get state;

  /// Signs in and resolves application permissions before reporting success.
  Future<BeakResult<void>> login({
    required String email,
    required String password,
  });

  /// Clears the device session even if remote revocation is unavailable.
  Future<BeakResult<void>> logout();

  /// Re-resolves permissions without unmounting an already ready screen.
  Future<BeakResult<void>> refresh();

  /// Optional factory for a new, independently owned registration flow.
  BeakEmailVerificationFlow Function()? get registration => null;

  /// Optional factory for a new, independently owned password recovery flow.
  BeakEmailVerificationFlow Function()? get recovery => null;
}

/// A backend email-code-password flow for registration or password recovery.
///
/// A new instance belongs to one mounted form. Request IDs and verified tokens
/// remain private to the backend adapter and are released by [dispose].
abstract interface class BeakEmailVerificationFlow {
  /// Sends an email verification code and starts or restarts this flow.
  Future<BeakResult<void>> start({required String email});

  /// Exchanges the code for permission to set a password.
  Future<BeakResult<void>> verify({required String code});

  /// Completes the flow with a password accepted by the backend's policy.
  Future<BeakResult<void>> complete({required String password});

  /// Releases transient request state when the form leaves the tree.
  void dispose();
}
