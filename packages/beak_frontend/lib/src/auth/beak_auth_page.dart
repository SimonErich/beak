import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../di/beak_locator.dart';
import '../localization/beak_localizations.dart';
import '../panel/beak_auth_config.dart';
import 'beak_auth_view_model.dart';
import 'beak_session_store.dart';

/// The configured workflow rendered by [BeakAuthPage].
enum BeakAuthMode {
  /// Email/password sign-in.
  login,

  /// Email-code-password registration.
  register,

  /// Email-code-password recovery.
  recover,
}

/// Beak-owned, localized authentication UI independent of its backend.
class BeakAuthPage extends HookWidget {
  /// Creates an auth page using [config]'s existing session authority.
  const BeakAuthPage({
    required this.title,
    required this.config,
    this.mode = BeakAuthMode.login,
    this.onSignedIn,
    this.onModeChanged,
    super.key,
  });

  /// Panel brand/title displayed above the form.
  final String title;

  /// Authentication capabilities and opt-ins.
  final BeakAuthConfig config;

  /// Workflow opened by the router.
  final BeakAuthMode mode;

  /// Called only after a successful, still-mounted operation.
  final VoidCallback? onSignedIn;

  /// Navigation intent; the owning router keeps the URL authoritative.
  final ValueChanged<BeakAuthMode>? onModeChanged;

  @override
  Widget build(BuildContext context) {
    final strings = BeakLocalizations.of(context);
    final adapter =
        config.adapter ?? beakDependencies(context)<BeakSessionStore>();
    final vm = useMemoized(
      () => BeakAuthViewModel(
        adapter: adapter,
        flow: switch (mode) {
          BeakAuthMode.login => null,
          BeakAuthMode.register when config.allowsRegistration =>
            adapter.registration?.call(),
          BeakAuthMode.recover when config.allowsRecovery =>
            adapter.recovery?.call(),
          _ => null,
        },
      ),
      [adapter, mode],
    );
    useEffect(() => vm.dispose, [vm]);
    final email = useTextEditingController();
    final code = useTextEditingController();
    final password = useTextEditingController();
    final confirmation = useTextEditingController();

    if (mode != BeakAuthMode.login && vm.flow == null) {
      return OiEmptyState.error(description: strings.unavailable);
    }

    Future<void> submit() async {
      bool complete = false;
      if (mode == BeakAuthMode.login) {
        complete = await vm.login(email: email.text, password: password.text);
      } else {
        switch (vm.step.value) {
          case BeakAuthStep.email:
            await vm.start(email.text);
          case BeakAuthStep.verify:
            await vm.verify(code.text);
          case BeakAuthStep.password:
            complete = await vm.complete(
              password.text,
              confirmation: confirmation.text,
            );
        }
      }
      if (complete && context.mounted) onSignedIn?.call();
    }

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(context.spacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: OiCard(
              child: Padding(
                padding: EdgeInsets.all(context.spacing.lg),
                child: Watch((context) {
                  final busy = vm.busy.value;
                  final step = vm.step.value;
                  final heading = switch (mode) {
                    BeakAuthMode.login => strings.authSignIn,
                    BeakAuthMode.register => strings.authRegister,
                    BeakAuthMode.recover => strings.authRecover,
                  };
                  final button = mode == BeakAuthMode.login
                      ? strings.authSignIn
                      : switch (step) {
                          BeakAuthStep.email => strings.authSendCode,
                          BeakAuthStep.verify => strings.authVerifyCode,
                          BeakAuthStep.password =>
                            mode == BeakAuthMode.register
                                ? strings.authRegister
                                : strings.authSavePassword,
                        };
                  final error = vm.error.value;
                  return OiColumn(
                    breakpoint: context.breakpoint,
                    gap: OiResponsive(context.spacing.md),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OiLabel.h3(title),
                      OiLabel.h2(heading),
                      if (mode == BeakAuthMode.login ||
                          step == BeakAuthStep.email)
                        OiTextInput(
                          label: strings.authEmail,
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !busy,
                        ),
                      if (mode != BeakAuthMode.login &&
                          step == BeakAuthStep.verify) ...[
                        OiLabel.body(strings.authCodeSent),
                        OiTextInput(
                          label: strings.authCode,
                          controller: code,
                          enabled: !busy,
                          onSubmitted: (_) => submit(),
                        ),
                        OiButton.ghost(
                          label: strings.authResendCode,
                          enabled: !busy,
                          onTap: () => vm.start(email.text),
                        ),
                      ],
                      if (mode == BeakAuthMode.login ||
                          step == BeakAuthStep.password)
                        OiTextInput.password(
                          label: strings.authPassword,
                          controller: password,
                          enabled: !busy,
                          onSubmitted: (_) => submit(),
                        ),
                      if (mode != BeakAuthMode.login &&
                          step == BeakAuthStep.password)
                        OiTextInput.password(
                          label: strings.authConfirmPassword,
                          controller: confirmation,
                          enabled: !busy,
                          onSubmitted: (_) => submit(),
                        ),
                      if (error != null)
                        OiBanner.error(
                          message: strings.authError(error),
                          dismissible: false,
                        ),
                      OiButton.primary(
                        label: button,
                        onTap: submit,
                        enabled: !busy,
                        loading: busy,
                        fullWidth: true,
                      ),
                      if (mode == BeakAuthMode.login && config.allowsRecovery)
                        OiButton.ghost(
                          label: strings.authForgotPassword,
                          enabled: !busy,
                          onTap: () =>
                              onModeChanged?.call(BeakAuthMode.recover),
                        ),
                      if (mode == BeakAuthMode.login &&
                          config.allowsRegistration)
                        OiButton.ghost(
                          label: strings.authRegister,
                          enabled: !busy,
                          onTap: () =>
                              onModeChanged?.call(BeakAuthMode.register),
                        ),
                      if (mode != BeakAuthMode.login)
                        OiButton.ghost(
                          label: strings.authBackToLogin,
                          enabled: !busy,
                          onTap: () => onModeChanged?.call(BeakAuthMode.login),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
