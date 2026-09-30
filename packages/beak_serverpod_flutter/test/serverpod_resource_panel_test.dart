import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';

/// Signed in with a fixed identity, so the panel opens its shell.
final class _SignedIn extends BeakAuthAdapter {
  final Signal<BeakAuthState> _state = signal(
    const BeakAuthAuthenticated(BeakAuthIdentity(id: 'staff')),
  );

  @override
  ReadonlySignal<BeakAuthState> get state => _state;

  @override
  Future<BeakResult<void>> login({
    required String email,
    required String password,
  }) async => const BeakOk(null);

  @override
  Future<BeakResult<void>> logout() async => const BeakOk(null);

  @override
  Future<BeakResult<void>> refresh() async => const BeakOk(null);
}

final class _Entry {
  const _Entry(this.id, this.title);

  final int id;
  final String title;
}

final class _EntryCodec extends ServerpodCodec<_Entry> {
  const _EntryCodec();

  @override
  BeakRecord encode(_Entry value) => BeakRecord(
    values: {
      'id': ServerpodCodecs.integer.encode(value.id),
      'title': ServerpodCodecs.string.encode(value.title),
    },
  );

  @override
  _Entry decode(BeakRecord record) => _Entry(
    ServerpodCodecs.integer.decode(record['id']),
    ServerpodCodecs.string.decode(record['title']),
  );
}

void main() {
  testWidgets('a ServerpodResource mounted as BeakResource.model lists the '
      'rows its own query returns', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const idColumn = BeakIntColumn(
      key: 'id',
      label: 'Id',
      visibleOn: {BeakContext.table, BeakContext.detail},
    );
    const titleColumn = BeakStringColumn(
      key: 'title',
      label: 'Title',
      visibleOn: {BeakContext.table, BeakContext.detail},
    );
    final specs = <BeakQuerySpec>[];
    final entries = ServerpodResource<_Entry, int, Never, Never>(
      model: const ServerpodModel(
        resource: 'entries',
        columns: [idColumn, titleColumn],
        primaryKey: idColumn,
        displayColumn: titleColumn,
      ),
      codec: const _EntryCodec(),
      idCodec: ServerpodCodecs.integer,
      identify: (entry) => entry.id,
      query: (spec) async {
        specs.add(spec);
        return const BeakPage(
          items: [_Entry(1, 'Moominsummer Madness'), _Entry(2, 'Finn Family')],
          total: 2,
          page: 1,
          perPage: 25,
        );
      },
      get: (id) async => null,
    );

    await tester.pumpWidget(
      BeakPanel(
        title: 'Bridge',
        resources: [BeakResource(model: entries, title: 'Entries')],
        auth: BeakAuthConfig(adapter: _SignedIn()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Moominsummer Madness'), findsOneWidget);
    expect(find.text('Finn Family'), findsOneWidget);
    expect(specs, isNotEmpty);
    expect(specs.first.table, 'entries');
    expect(tester.takeException(), isNull);
  });
}
