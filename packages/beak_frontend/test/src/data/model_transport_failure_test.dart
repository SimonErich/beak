import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../support/panel_fixtures.dart';

/// A source whose every operation fails with [failure].
final class _Failing extends FakeDataSource {
  _Failing(this.failure);

  final Exception failure;

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async => throw failure;

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async =>
      throw failure;
}

void main() {
  ModelBeakDataSource routerOver(
    BeakDataSource source, {
    BeakException? Function(Exception, StackTrace)? mapException,
  }) {
    final router = ModelBeakDataSource(
      registry: BeakModelRegistry()..register(const NoteModel()),
      fallback: source,
      overrideBindings: true,
      mapException: mapException,
    );
    addTearDown(router.dispose);
    return router;
  }

  const spec = BeakQuerySpec(table: 'notes');

  group('a request that never reached the server', () {
    test('a refused connection is a transport failure, not a raw error', () {
      final router = routerOver(
        _Failing(http.ClientException('connect refused by 10.0.0.7:8080')),
      );
      expect(
        router.query(spec),
        throwsA(
          isA<BeakTransportException>().having(
            (error) => error.message,
            'message',
            isNot(contains('10.0.0.7')),
          ),
        ),
      );
    });

    test('a timeout is a transport failure', () {
      final router = routerOver(
        _Failing(TimeoutException('No reply within 30 seconds.')),
      );
      expect(router.query(spec), throwsA(isA<BeakTransportException>()));
    });

    test('a write that lost its connection is a transport failure', () {
      final router = routerOver(_Failing(http.ClientException('reset')));
      expect(
        router.update(
          'notes',
          'n1',
          const BeakRecord(values: {'title': BeakStringValue('x')}),
        ),
        throwsA(isA<BeakTransportException>()),
      );
    });

    test('the application mapper is asked first', () {
      final router = routerOver(
        _Failing(http.ClientException('reset')),
        mapException: (error, _) => error is http.ClientException
            ? const BeakAuthenticationException('Sign in again.')
            : null,
      );
      expect(router.query(spec), throwsA(isA<BeakAuthenticationException>()));
    });

    test('a programming error is still not a result', () {
      final router = routerOver(_Failing(const FormatException('bug')));
      expect(router.query(spec), throwsA(isA<FormatException>()));
    });

    test('a table stops loading and shows the failure', () async {
      final router = routerOver(_Failing(http.ClientException('reset')));
      final viewModel = BeakTableViewModel(const NoteModel(), router);
      addTearDown(viewModel.dispose);

      await viewModel.refresh();

      expect(viewModel.loading.value, isFalse);
      expect(viewModel.error.value, isA<BeakTransportException>());
    });
  });
}
