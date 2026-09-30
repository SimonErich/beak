import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';

void main() {
  test('login forwards credentials, reports denial and allows retry', () async {
    final adapter = FakeAuthAdapter();
    final vm = BeakAuthViewModel(adapter: adapter);
    addTearDown(vm.dispose);
    adapter.loginResult = const BeakErr(BeakAuthorizationException('private'));
    expect(
      await vm.login(email: ' user@example.com ', password: 'secret'),
      false,
    );
    expect(adapter.email, 'user@example.com');
    expect(adapter.password, 'secret');
    expect(vm.error.value, isA<BeakAuthorizationException>());
    adapter.loginResult = const BeakOk(null);
    expect(await vm.login(email: 'user@example.com', password: 'secret'), true);
    expect(vm.error.value, isNull);
    expect(vm.busy.value, false);
  });

  test('login accepts a username that is not an email address', () async {
    final adapter = FakeAuthAdapter();
    final vm = BeakAuthViewModel(adapter: adapter);
    addTearDown(vm.dispose);

    expect(await vm.login(email: ' admin ', password: 'secret'), true);

    expect(adapter.email, 'admin');
    expect(vm.error.value, isNull);
  });

  test('login still requires both an identifier and a password', () async {
    final adapter = FakeAuthAdapter();
    final vm = BeakAuthViewModel(adapter: adapter);
    addTearDown(vm.dispose);

    expect(await vm.login(email: '  ', password: 'secret'), false);
    expect(await vm.login(email: 'admin', password: ''), false);

    expect(adapter.email, isNull);
    expect(vm.error.value, isA<BeakValidationException>());
  });

  test('registration and recovery still check the email address', () async {
    final vm = BeakAuthViewModel(
      adapter: FakeAuthAdapter(),
      flow: FakeEmailFlow(),
    );
    addTearDown(vm.dispose);

    await vm.start('not-an-email');

    expect(vm.step.value, BeakAuthStep.email);
    expect(vm.error.value, isA<BeakValidationException>());
  });

  test('verification advances only on success and supports retry', () async {
    final flow = FakeEmailFlow();
    final vm = BeakAuthViewModel(adapter: FakeAuthAdapter(), flow: flow);
    addTearDown(vm.dispose);
    await vm.start('person@example.com');
    expect(vm.step.value, BeakAuthStep.verify);
    flow.result = const BeakErr(BeakValidationException('invalid code'));
    await vm.verify('bad');
    expect(vm.step.value, BeakAuthStep.verify);
    flow.result = const BeakOk(null);
    await vm.verify('123456');
    expect(vm.step.value, BeakAuthStep.password);
    expect(await vm.complete('long-password'), true);
    expect(flow.calls, [
      'start:person@example.com',
      'verify:bad',
      'verify:123456',
      'complete:long-password',
    ]);
  });

  test('completion after disposal cannot publish or navigate', () async {
    final adapter = FakeAuthAdapter();
    final pending = Completer<BeakResult<void>>();
    adapter.pending = pending.future;
    final vm = BeakAuthViewModel(adapter: adapter);
    final login = vm.login(email: 'person@example.com', password: 'password');
    vm.dispose();
    pending.complete(const BeakOk(null));
    expect(await login, false);
  });
}

class FakeAuthAdapter extends BeakAuthAdapter {
  final _state = signal<BeakAuthState>(const BeakAuthGuest());
  BeakResult<void> loginResult = const BeakOk(null);
  Future<BeakResult<void>>? pending;
  String? email;
  String? password;
  @override
  ReadonlySignal<BeakAuthState> get state => _state;
  @override
  Future<BeakResult<void>> login({
    required String email,
    required String password,
  }) async {
    this.email = email;
    this.password = password;
    return pending ?? loginResult;
  }

  @override
  Future<BeakResult<void>> logout() async => const BeakOk(null);
  @override
  Future<BeakResult<void>> refresh() async => const BeakOk(null);
}

class FakeEmailFlow implements BeakEmailVerificationFlow {
  final calls = <String>[];
  BeakResult<void> result = const BeakOk(null);
  @override
  Future<BeakResult<void>> start({required String email}) async {
    calls.add('start:$email');
    return result;
  }

  @override
  Future<BeakResult<void>> verify({required String code}) async {
    calls.add('verify:$code');
    return result;
  }

  @override
  Future<BeakResult<void>> complete({required String password}) async {
    calls.add('complete:$password');
    return result;
  }

  @override
  void dispose() {}
}
