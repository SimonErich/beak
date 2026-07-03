import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';

/// A minimal view model exercising the base class contract.
final class _CounterViewModel extends BeakViewModel {
  _CounterViewModel() {
    _count = ownedSignal(0);
  }

  late final Signal<int> _count;

  /// The current count, read-only for widgets.
  ReadonlySignal<int> get count => _count;

  /// Increments the count.
  void increment() => _count.value += 1;
}

void main() {
  test('owned signals expose readonly state that widgets can watch', () {
    final viewModel = _CounterViewModel();
    expect(viewModel.count.value, 0);

    viewModel.increment();
    expect(viewModel.count.value, 1);
  });

  test('dispose releases owned signals and flags the view model', () {
    final viewModel = _CounterViewModel();
    expect(viewModel.isDisposed, isFalse);

    viewModel.dispose();
    expect(viewModel.isDisposed, isTrue);
    expect(viewModel.count.disposed, isTrue);
  });
}
