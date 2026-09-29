import 'dart:convert';

import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:bookshop_admin/src/bookshop_admin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';

import 'support/fake_bookshop_server.dart';

/// Signed in with the admin scope; login itself is covered in
/// `admin_login_test.dart` through the real ServerpodAuthAdapter.
final class _SignedInAdmin extends BeakAuthAdapter {
  final Signal<BeakAuthState> _state = signal(
    const BeakAuthAuthenticated(BeakAuthIdentity(id: 'admin')),
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

Future<FakeBookshopServer> _pumpAdmin(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final server = await FakeBookshopServer.seeded();
  await tester.pumpWidget(
    bookshopAdminPanel(dispatch: server.dispatch, auth: _SignedInAdmin()),
  );
  await tester.pumpAndSettle();
  return server;
}

Future<void> _openSection(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Books table loads through the tunnel with its author', (
    tester,
  ) async {
    final server = await _pumpAdmin(tester);
    await _openSection(tester, 'Books');
    expect(find.text('Comet in Moominland'), findsOneWidget);
    expect(find.text('A Wizard of Earthsea'), findsOneWidget);
    // BookModel.author.name: the relation came back eagerly loaded.
    expect(find.text('Ursula K. Le Guin'), findsWidgets);
    final query = server.requests.lastWhere(
      (request) => request.path == '/api/book/query',
    );
    final spec = BeakQuerySpec.fromJson(
      jsonDecode(query.body) as Map<String, Object?>,
    );
    expect(spec.relationLoads.map((load) => load.relationKey), ['author']);
    // The Serverpod client authenticates the call itself: the envelope inside
    // carries no credentials.
    expect(query.headers.keys, isNot(contains('authorization')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'BookModel.author.relationFilter() filters the table through the tunnel',
    (tester) async {
      final server = await _pumpAdmin(tester);
      await _openSection(tester, 'Books');
      await tester.tap(find.widgetWithText(OiFilterChip, 'Author'));
      await tester.pumpAndSettle();
      // The filter's combobox loads its options through the tunnel.
      await tester.tap(find.byType(OiComboBox<BeakRecord>));
      await tester.pumpAndSettle();
      expect(server.calls, contains('POST /api/author/query'));
      await tester.tap(find.text('Ursula K. Le Guin').first);
      await tester.pumpAndSettle();
      final query = server.requests.lastWhere(
        (request) => request.path == '/api/book/query',
      );
      expect((jsonDecode(query.body) as Map<String, Object?>)['filter'], {
        'type': 'relation',
        'relation': 'author',
        'filter': {
          'type': 'field',
          'column': 'id',
          'operator': 'eq',
          'value': 2,
        },
      });
      expect(find.text('A Wizard of Earthsea'), findsOneWidget);
      expect(find.text('Comet in Moominland'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the Books form (inputText, inputCombobox, inputSelect) creates a book',
    (tester) async {
      final server = await _pumpAdmin(tester);
      await _openSection(tester, 'Books');
      await tester.tap(find.text('Create').first);
      await tester.pumpAndSettle();
      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), 'Tales from Moominvalley');
      await tester.enterText(fields.at(1), '978-0-374-37369-7');
      await tester.enterText(fields.at(2), '1599');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Author').last);
      await tester.pumpAndSettle();
      // BookModel.author.inputCombobox() loads its options through the tunnel.
      expect(server.calls, contains('POST /api/author/query'));
      await tester.tap(find.text('Tove Jansson').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Format').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('hardcover').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      // Golden-path forms save through a graph commit, validated on the way
      // (POST /api/book/validate), and the table reloads.
      expect(server.calls, containsAllInOrder(['POST /api/commits']));
      expect(server.calls.last, 'POST /api/book/query');
      final rows = await tester.runAsync(() => server.rows('book'));
      expect(
        rows!.where((row) => row['title'] == 'Tales from Moominvalley').single,
        allOf(
          containsPair('isbn', '978-0-374-37369-7'),
          containsPair('authorId', 1),
          containsPair('format', 'hardcover'),
          containsPair('priceInCents', 1599),
          containsPair('stock', 0),
        ),
      );
      expect(find.text('Tales from Moominvalley'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the Authors table loads through the tunnel', (tester) async {
    final server = await _pumpAdmin(tester);
    await _openSection(tester, 'Authors');
    expect(find.text('Tove Jansson'), findsOneWidget);
    expect(find.text('Ursula K. Le Guin'), findsOneWidget);
    expect(server.calls, contains('POST /api/author/query'));
    expect(tester.takeException(), isNull);
  });
}
