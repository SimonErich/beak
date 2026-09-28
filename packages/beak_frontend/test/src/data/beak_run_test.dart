import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'custom typed operations return their result without a data source',
    () async {
      var calls = 0;
      final result = await beakRun(() async {
        calls++;
        return (id: 42, label: 'Loaded');
      });
      expect(result.valueOrThrow, (id: 42, label: 'Loaded'));
      expect(calls, 1);
    },
  );

  test(
    'synchronous and asynchronous Beak failures share the catch boundary',
    () async {
      const error = BeakValidationException('Safe domain message');
      for (final operation in <Future<int> Function()>[
        () => throw error,
        () async => throw error,
      ]) {
        final result = await beakRun(operation);
        expect(
          result,
          isA<BeakErr<int>>().having(
            (result) => result.error,
            'failure',
            same(error),
          ),
        );
      }
    },
  );

  test('maps host exceptions with their original stack', () async {
    final failure = Exception('transport detail');
    final stack = StackTrace.fromString('original transport stack');
    const mapped = BeakAuthorizationException('Safe domain message');
    var mapperCalls = 0;
    final result = await beakRun<int>(
      () async => Error.throwWithStackTrace(failure, stack),
      mapException: (exception, trace) {
        mapperCalls++;
        expect(exception, same(failure));
        expect(trace.toString(), stack.toString());
        return mapped;
      },
    );
    expect(
      result,
      isA<BeakErr<int>>().having(
        (result) => result.error,
        'mapped failure',
        same(mapped),
      ),
    );
    expect(mapperCalls, 1);
  });

  test('known Beak exceptions bypass the host mapper', () async {
    const failure = BeakValidationException('Safe domain message');
    final result = await beakRun<int>(
      () async => throw failure,
      mapException: (_, _) => fail('Known Beak failures must not be remapped.'),
    );
    expect(
      result,
      isA<BeakErr<int>>().having(
        (result) => result.error,
        'original failure',
        same(failure),
      ),
    );
  });

  test(
    'absent and declining mappers retain the original exception stack',
    () async {
      final failure = Exception('unmapped transport detail');
      final stack = StackTrace.fromString('original unmapped stack');
      for (final mapper in <BeakException? Function(Exception, StackTrace)?>[
        null,
        (_, _) => null,
      ]) {
        try {
          await beakRun<int>(
            () async => Error.throwWithStackTrace(failure, stack),
            mapException: mapper,
          );
          fail('The unmapped exception must propagate.');
        } on Exception catch (exception, trace) {
          expect(exception, same(failure));
          expect(trace.toString(), stack.toString());
        }
      }
    },
  );

  test('programming errors bypass even an installed mapper', () async {
    final failure = StateError('programming error');
    await expectLater(
      beakRun<int>(
        () async => throw failure,
        mapException: (_, _) => fail('Programming errors must not be mapped.'),
      ),
      throwsA(same(failure)),
    );
  });

  test('a failure inside the mapper propagates unchanged', () async {
    final mapperFailure = StateError('mapper bug');
    await expectLater(
      beakRun<int>(
        () async => throw Exception('transport detail'),
        mapException: (_, _) => throw mapperFailure,
      ),
      throwsA(same(mapperFailure)),
    );
  });

  test(
    'unmapped exceptions and programming errors retain their identity',
    () async {
      for (final failure in [
        Exception('transport'),
        StateError('programming error'),
      ]) {
        await expectLater(
          beakRun<int>(() async => throw failure),
          throwsA(same(failure)),
        );
      }
    },
  );
}
