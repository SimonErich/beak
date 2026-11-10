import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gives every widget test a local settings store.
///
/// `BeakThemeController` restores the saved theme on construction; without a
/// plugin implementation that would fail (or wait forever) in a unit test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
