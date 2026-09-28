import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _name = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(key: 'title', label: 'Title'),
);
const _secret = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(
    key: 'password',
    label: 'Password',
    semantic: BeakSemantic.password(),
  ),
);
const _amount = BeakScalarField<int>(
  model: NoteModel(),
  column: BeakIntColumn(key: 'amount', label: 'Amount'),
);
const _labels = BeakToManyField(
  model: NoteModel(),
  relation: NoteRelations.labels,
  target: LabelModel(),
);
const _label = BeakScalarField<String>(
  model: LabelModel(),
  column: BeakStringColumn(key: 'name', label: 'Label'),
);

BeakRecordDocument _document() => BeakRecordDocument(
  title: BeakValueBinding.field(_name),
  subtitle: [
    BeakValueBinding.computed(
      dependencies: [_name],
      compute: (reader) => 'Persisted ${reader.read(_name)}',
    ),
  ],
  sections: [
    BeakDocumentSection(
      title: 'Details <safe>',
      fields: [
        BeakValueBinding.field(_amount.currency(minorUnits: true)),
        BeakValueBinding.field(_secret),
        BeakValueBinding.field(_name, label: 'Hidden', visibleIf: (_) => false),
      ],
    ),
    const BeakDocumentCollection(
      title: 'Labels',
      field: _labels,
      columns: [_label],
    ),
  ],
);

BeakRecord _record() => BeakRecord(
  values: BeakRecord.fromRow({
    'id': 'n1',
    'title': '<script>alert("title")</script>',
    'amount': 3140,
    'password': 'never-print-me',
  }).values,
  relations: {
    'labels': [
      BeakRecord.fromRow({'id': 'l1', 'name': 'Coffee & tea'}),
    ],
  },
);

void main() {
  test(
    'document escapes every text location and preserves exact field formatting',
    () {
      final document = _document().render(
        _record(),
        formatting: const BeakFormatPolicy(locale: 'de_DE', currency: 'EUR'),
      );
      expect(
        document.html,
        contains('&lt;script&gt;alert(&quot;title&quot;)&lt;&#47;script&gt;'),
      );
      expect(document.html, isNot(contains('<script>')));
      expect(document.html, contains('Details &lt;safe&gt;'));
      expect(document.html, contains('Coffee &amp; tea'));
      expect(document.html, contains('31,40'));
      expect(document.html, isNot(contains('3140')));
      expect(document.html, isNot(contains('never-print-me')));
      expect(document.html, isNot(contains('Hidden')));
      expect(document.html, contains('Content-Security-Policy'));
    },
  );

  test(
    'document loads persisted identity and collection dependencies in one authorized query',
    () async {
      final source = _SnapshotSource();
      final pending = _document().load(
        model: const NoteModel(),
        id: 'n1',
        source: source,
        formatting: const BeakFormatPolicy(),
      );
      expect(source.calls, hasLength(1));
      expect(source.calls.single.relationLoads.single.relationKey, 'labels');
      expect(source.calls.single.filter?.toJson().toString(), contains('n1'));
      source.response.complete(
        BeakPage(items: [_record()], total: 1, page: 1, perPage: 1),
      );
      final snapshot = await pending;
      expect(snapshot.title, _name.readFrom(_record()));
      expect(source.createCalls, isEmpty);
    },
  );

  test('empty authorized query cannot create a document', () async {
    final source = _SnapshotSource();
    final pending = _document().load(
      model: const NoteModel(),
      id: 'hidden',
      source: source,
      formatting: const BeakFormatPolicy(),
    );
    source.response.complete(
      const BeakPage(items: [], total: 0, page: 1, perPage: 1),
    );
    await expectLater(pending, throwsA(isA<BeakNotFoundException>()));
  });

  test('invalid related projection fails before fetching', () async {
    final source = _SnapshotSource();
    final document = BeakRecordDocument(
      title: BeakValueBinding.field(_name),
      sections: [
        const BeakDocumentCollection(
          title: 'Wrong',
          field: _labels,
          columns: [_name],
        ),
      ],
    );
    await expectLater(
      document.load(
        model: const NoteModel(),
        id: 'n1',
        source: source,
        formatting: const BeakFormatPolicy(),
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(source.calls, isEmpty);
  });

  for (final revoked in [false, true]) {
    testWidgets(
      revoked
          ? 'print cancels reserved window if permission is revoked during loading'
          : 'print reserves before fetching and uses persisted values once',
      (tester) async {
        final source = _SnapshotSource();
        final delivery = _Delivery();
        var allowed = true;
        final errors = <BeakException>[];
        final action = BeakRecordAction.document(
          key: 'print',
          label: 'Print note',
          document: _document(),
          beginDelivery: () {
            expect(source.calls, isEmpty);
            return delivery;
          },
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => BeakActionButton(
                action: action,
                record: BeakRecord.fromRow({
                  'id': 'n1',
                  'title': 'Unsaved draft',
                }),
                actionContext: BeakActionContext(
                  buildContext: context,
                  model: const NoteModel(),
                  dataSource: source,
                  router: GoRouter.of(context),
                  canExecute: (_) => allowed,
                  onError: errors.add,
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          OiApp.router(theme: OiThemeData.light(), routerConfig: router),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<OiButton>(find.byType(OiButton)).icon,
          OiIcons.printer,
        );
        await tester.tap(find.text('Print note'));
        await tester.pump();
        expect(source.calls, hasLength(1));
        expect(tester.widget<OiButton>(find.byType(OiButton)).onTap, isNull);
        if (revoked) allowed = false;
        source.response.complete(
          BeakPage(items: [_record()], total: 1, page: 1, perPage: 1),
        );
        await tester.pumpAndSettle();
        if (revoked) {
          expect(delivery.shown, isEmpty);
          expect(delivery.cancelled, isTrue);
          expect(errors.single, isA<BeakAuthorizationException>());
        } else {
          expect(delivery.shown.single.html, isNot(contains('Unsaved draft')));
          expect(delivery.shown.single.html, contains('Coffee &amp; tea'));
          expect(delivery.cancelled, isFalse);
        }
      },
    );
  }

  for (final disposed in [false, true]) {
    testWidgets(
      disposed
          ? 'leaving the page while loading cancels the reserved print window'
          : 'failed document loading cancels the reserved print window',
      (tester) async {
        final source = _SnapshotSource();
        final delivery = _Delivery();
        final errors = <BeakException>[];
        final action = BeakRecordAction.document(
          key: 'print',
          label: 'Print note',
          document: _document(),
          beginDelivery: () => delivery,
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => BeakActionButton(
                action: action,
                record: BeakRecord.fromRow({'id': 'n1'}),
                actionContext: BeakActionContext(
                  buildContext: context,
                  model: const NoteModel(),
                  dataSource: source,
                  router: GoRouter.of(context),
                  onError: errors.add,
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          OiApp.router(theme: OiThemeData.light(), routerConfig: router),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Print note'));
        await tester.pump();
        if (disposed) {
          await tester.pumpWidget(const SizedBox.shrink());
          source.response.complete(
            BeakPage(items: [_record()], total: 1, page: 1, perPage: 1),
          );
        } else {
          source.response.completeError(
            const BeakNotFoundException('The document record is unavailable.'),
          );
        }
        await tester.pumpAndSettle();
        expect(delivery.cancelled, isTrue);
        expect(delivery.shown, isEmpty);
        expect(tester.takeException(), isNull);
        if (disposed) {
          expect(errors, isEmpty);
        } else {
          expect(errors.single, isA<BeakNotFoundException>());
          expect(
            tester.widget<OiButton>(find.byType(OiButton)).onTap,
            isNotNull,
          );
        }
      },
    );
  }
}

final class _SnapshotSource extends FakeDataSource {
  final response = Completer<BeakPage<BeakRecord>>();
  final calls = <BeakQuerySpec>[];
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    calls.add(spec);
    return response.future;
  }
}

final class _Delivery implements BeakDocumentDelivery {
  final shown = <BeakDocumentSnapshot>[];
  bool cancelled = false;
  @override
  Future<void> show(BeakDocumentSnapshot document) async => shown.add(document);
  @override
  void cancel() => cancelled = true;
}
