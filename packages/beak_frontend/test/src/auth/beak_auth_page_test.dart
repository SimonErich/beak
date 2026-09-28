import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import 'beak_auth_view_model_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    String locale = 'en',
  }) async {
    await tester.pumpWidget(
      OiApp(
        locale: Locale(locale),
        supportedLocales: BeakLocalizations.supportedLocales,
        localizationsDelegates: const [BeakLocalizations.delegate],
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'login owns typed submission, hides disabled links and safe errors',
    (tester) async {
      final adapter = FakeAuthAdapter();
      adapter.loginResult = const BeakErr(
        BeakAuthorizationException('internal detail'),
      );
      var signedIn = false;
      await pump(
        tester,
        BeakAuthPage(
          title: 'Example',
          config: BeakAuthConfig(adapter: adapter),
          onSignedIn: () => signedIn = true,
        ),
      );
      expect(find.text('Create account'), findsNothing);
      expect(find.text('Forgot password?'), findsNothing);
      await tester.enterText(
        find.byType(EditableText).first,
        ' person@example.com ',
      );
      await tester.enterText(find.byType(EditableText).last, 'password');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(
        find.text('This account cannot access this panel.'),
        findsOneWidget,
      );
      expect(find.text('internal detail'), findsNothing);
      expect(signedIn, false);
      adapter.loginResult = const BeakOk(null);
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(adapter.email, 'person@example.com');
      expect(signedIn, true);
    },
  );

  testWidgets('German recovery executes code and new-password steps', (
    tester,
  ) async {
    final adapter = _FlowAdapter();
    var done = false;
    await pump(
      tester,
      BeakAuthPage(
        title: 'Example',
        config: BeakAuthConfig(adapter: adapter, recover: true),
        mode: BeakAuthMode.recover,
        onSignedIn: () => done = true,
      ),
      locale: 'de',
    );
    await tester.enterText(find.byType(EditableText), 'person@example.com');
    await tester.tap(find.text('Code senden'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '123456');
    await tester.tap(find.text('Code bestätigen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'new-password');
    await tester.enterText(find.byType(EditableText).last, 'new-password');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pumpAndSettle();
    expect(adapter.flow.calls, [
      'start:person@example.com',
      'verify:123456',
      'complete:new-password',
    ]);
    expect(done, true);
  });
}

class _FlowAdapter extends FakeAuthAdapter {
  final flow = FakeEmailFlow();
  @override
  BeakEmailVerificationFlow Function()? get recovery =>
      () => flow;
}
