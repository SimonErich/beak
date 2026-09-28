import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';

import '../auth/beak_auth_view_model_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;
  late ReferenceCache cache;

  BeakRecord note(String id, String title) =>
      BeakRecord.fromRow({'id': id, 'title': title});

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {'n1': note('n1', 'One'), 'n2': note('n2', 'Two')},
        'labels': {
          'l1': BeakRecord.fromRow(const {'id': 'l1', 'name': 'hot'}),
        },
      },
    );
    final registry = BeakModelRegistry()
      ..register(const NoteModel())
      ..register(const LabelModel());
    cache = ReferenceCache(dataSource, registry);
  });

  test(
    'panel identity changes clear cached and in-flight references',
    () async {
      final auth = _CacheAuth();
      final source = _ChangingPrincipalSource();
      registerBeakDependencies(
        config: BeakPanelConfig(
          title: 'Admin',
          resources: const [BeakResource(model: NoteModel())],
          auth: BeakAuthConfig(adapter: auth),
        ),
        dataSource: source,
      );
      addTearDown(beakLocator.reset);
      final references = beakLocator<ReferenceCache>();
      auth.snapshot.value = const BeakAuthAuthenticated(
        BeakAuthIdentity(id: 'first'),
      );
      expect(
        (await references.resolve('notes', 'n1'))['title']?.raw,
        'First account',
      );
      source.delayNext = true;
      final old = references.resolve('notes', 'n2');
      final cancelled = expectLater(
        old,
        throwsA(isA<BeakAuthenticationException>()),
      );
      await Future<void>.delayed(Duration.zero);
      source.title = 'Second account';
      auth.snapshot.value = const BeakAuthAuthenticated(
        BeakAuthIdentity(id: 'second'),
      );
      await cancelled;
      source.pending.complete([
        BeakRecord.fromRow({'id': 'n2', 'title': 'First account secret'}),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        (await references.resolve('notes', 'n1'))['title']?.raw,
        'Second account',
      );
      expect(
        (await references.resolve('notes', 'n2'))['title']?.raw,
        'Second account',
      );
      expect(source.calls, 4);
      auth.snapshot.value = const BeakAuthGuest();
      source.title = 'Guest';
      expect((await references.resolve('notes', 'n1'))['title']?.raw, 'Guest');
    },
  );

  test(
    'identity change cancels requests still queued in the batch window',
    () async {
      final pending = cache.resolve('notes', 'n1');
      final cancelled = expectLater(
        pending,
        throwsA(isA<BeakAuthenticationException>()),
      );
      cache.invalidateAll();
      await cancelled;
      expect(dataSource.batchGetCalls, isEmpty);
      expect((await cache.resolve('notes', 'n1'))['title']?.raw, 'One');
    },
  );

  test('same-frame resolves coalesce into one batchGet', () async {
    final results = await Future.wait<BeakRecord>([
      cache.resolve('notes', 'n1'),
      cache.resolve('notes', 'n2'),
      cache.resolve('notes', 'n1'),
    ]);

    expect(dataSource.batchGetCalls, hasLength(1));
    expect(dataSource.batchGetCalls.single.$2, unorderedEquals(['n1', 'n2']));
    expect(results[0]['title'], const BeakStringValue('One'));
    expect(results[1]['title'], const BeakStringValue('Two'));
    expect(results[2], same(results[0]));
  });

  test('different tables batch separately', () async {
    await Future.wait<BeakRecord>([
      cache.resolve('notes', 'n1'),
      cache.resolve('labels', 'l1'),
    ]);
    expect(dataSource.batchGetCalls, hasLength(2));
  });

  test('cache hits never refetch', () async {
    await cache.resolve('notes', 'n1');
    await cache.resolve('notes', 'n1');
    expect(dataSource.batchGetCalls, hasLength(1));
  });

  test('invalidate forces the next resolve to refetch', () async {
    await cache.resolve('notes', 'n1');
    cache.invalidate('notes', 'n1');
    await cache.resolve('notes', 'n1');
    expect(dataSource.batchGetCalls, hasLength(2));
  });

  test('invalidateTable drops every cached record of the table', () async {
    await Future.wait<BeakRecord>([
      cache.resolve('notes', 'n1'),
      cache.resolve('notes', 'n2'),
    ]);
    cache.invalidateTable('notes');
    await cache.resolve('notes', 'n2');
    expect(dataSource.batchGetCalls, hasLength(2));
  });

  test('a missing id fails with a typed not-found', () {
    expect(
      () => cache.resolve('notes', 'ghost'),
      throwsA(isA<BeakNotFoundException>()),
    );
  });

  test('a batch failure propagates to every waiting resolve', () async {
    final failing = _FailingDataSource();
    final registry = BeakModelRegistry()..register(const NoteModel());
    final failingCache = ReferenceCache(failing, registry);

    final futures = [
      failingCache.resolve('notes', 'n1'),
      failingCache.resolve('notes', 'n2'),
    ];
    for (final future in futures) {
      await expectLater(future, throwsA(isA<BeakStorageException>()));
    }
  });
}

/// A data source whose batch fetch always fails.
final class _FailingDataSource extends FakeDataSource {
  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async {
    throw const BeakStorageException('backend unreachable');
  }
}

final class _CacheAuth extends FakeAuthAdapter {
  final snapshot = signal<BeakAuthState>(const BeakAuthGuest());
  @override
  ReadonlySignal<BeakAuthState> get state => snapshot;
}

final class _ChangingPrincipalSource extends FakeDataSource {
  String title = 'First account';
  bool delayNext = false;
  int calls = 0;
  final pending = Completer<List<BeakRecord>>();
  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async {
    calls++;
    if (delayNext) {
      delayNext = false;
      return pending.future;
    }
    return [
      for (final id in ids) BeakRecord.fromRow({'id': id, 'title': title}),
    ];
  }
}
