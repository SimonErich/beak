import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(model: _Basket(), column: _Basket.title);
const _name = BeakScalarField<String>(model: _Item(), column: _Item.name);
const _quantity = BeakScalarField<int>(model: _Line(), column: _Line.quantity);
const _choice = BeakToOneField(
  model: _Basket(),
  relation: _Basket.choice,
  target: _Item(),
);
const _selection = BeakToOneField(
  model: _Line(),
  relation: _Line.item,
  target: _Item(),
);
const _lines = BeakToManyField(
  model: _Basket(),
  relation: _Basket.lines,
  target: _Line(),
);
final _template = BeakRecordTemplate.fields(title: _name, avatar: true);
final _available = BeakRecord.fromRow({'id': 'coffee', 'name': 'Coffee'});
final _blocked = BeakRecord.fromRow({'id': 'sold', 'name': 'Sold out'});

FakeDataSource _source() => FakeDataSource(
  models: const [_Basket(), _Line(), _Item()],
  records: {
    'catalog': {'coffee': _available, 'sold': _blocked},
  },
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 1440,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(OiApp(theme: OiThemeData.light(), home: child));
  await tester.pumpAndSettle();
}

void main() {
  for (final sample in [
    ('none', const _Basket()),
    ('unavailable', const _ActionBasket()),
    ('available', const _PlaceBasket()),
  ]) {
    testWidgets('final wizard footer omits empty command spacing ${sample.$1}', (
      tester,
    ) async {
      final hasCommand = sample.$1 == 'available';
      final model = sample.$2;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: model,
          dataSource: FakeDataSource(
            models: [model, const _Item(), const _Line()],
          ),
          navigation: BeakWizardNavigation.rail,
          steps: const [BeakWizardStep(title: 'Review', children: [])],
        ),
      );
      final finish = find.widgetWithText(OiButton, 'Finish');
      expect(finish, findsOneWidget);
      final layout = tester.widget<OiWizardLayout>(find.byType(OiWizardLayout));
      final footer = find.byWidget(layout.footer!);
      final footerHeight = tester.getSize(footer).height;
      final buttonHeight = tester.getSize(finish).height;
      if (hasCommand) {
        final command = find.widgetWithText(OiButton, 'Place');
        expect(command, findsOneWidget);
        expect(
          tester.getTopLeft(finish).dy - tester.getBottomLeft(command).dy,
          closeTo(12, .01),
        );
        expect(
          footerHeight,
          closeTo(tester.getSize(command).height + 12 + buttonHeight, .01),
        );
      } else {
        expect(find.widgetWithText(OiButton, 'Place'), findsNothing);
        expect(find.widgetWithText(OiButton, 'Pin'), findsNothing);
        expect(find.widgetWithText(OiButton, 'Archive'), findsNothing);
        expect(
          footerHeight,
          closeTo(buttonHeight, .01),
          reason:
              'An unavailable command must not reserve an invisible row or gap.',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final totalRole in [false, true]) {
    testWidgets(
      'summary value alignment and caption spacing preserve defaults $totalRole',
      (tester) async {
        await _pump(
          tester,
          BeakConfiguredForm(
            model: const _Basket(),
            dataSource: _source(),
            layout: BeakFormLayout(
              children: [
                BeakFormSummary(
                  gap: 8,
                  lines: [
                    BeakSummaryLine(
                      label: 'Grand total',
                      value: (_) => '41.31',
                      subtitle: (_, _) => 'Included tax',
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                      ),
                      subtitleStyle: const TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                      valueStyle: const TextStyle(
                        fontSize: 22,
                        height: 28 / 22,
                      ),
                      valueAlignment: totalRole
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      subtitleGap: totalRole ? 0 : 2,
                      afterSpacing: totalRole ? 4 : 0,
                    ),
                    BeakSummaryLine(
                      label: 'Remaining budget',
                      value: (_) => '15.29',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        final title = tester.getRect(find.text('Grand total'));
        final value = tester.getRect(find.text('41.31'));
        final caption = tester.getRect(find.text('Included tax'));
        final next = tester.getRect(find.text('Remaining budget'));
        expect(value.top - title.top, totalRole ? 8 : 0);
        expect(caption.top - title.bottom, totalRole ? 0 : 2);
        expect(next.top - caption.bottom, totalRole ? 12 : 8);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'added compact row marker follows pending rows in persisted edits',
    (tester) async {
      final source = _source();
      await source.create(
        'baskets',
        BeakRecord.fromRow({'id': 'existing', 'title': 'Saved'}),
      );
      late BeakFormSession session;
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          recordId: 'existing',
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            showChangeIndicators: true,
            children: [
              _lines.tableForm(
                presentation: BeakRelationTablePresentation.rows,
                showColumnHeadings: false,
                rowTemplate: BeakRecordTemplate(
                  title: BeakValueBinding<String>.computed(
                    dependencies: [_quantity],
                    compute: (_) => 'New line',
                  ),
                ),
                children: [_quantity.inputNumber()],
              ),
            ],
          ),
        ),
      );
      final row = session.root.addRow(_lines)..set(_quantity, 1);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Added item, not saved'), findsOneWidget);
      session.root.removeRow(row);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Added item, not saved'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'owner-scoped catalog tabs release only their own filter and preserve order',
    (tester) async {
      late BeakFormSession session;
      final source = _source();
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              _title.input(visibleIf: (_) => false),
              _lines.tableForm(
                children: const [],
                catalog: BeakRelationCatalog(
                  selection: _selection,
                  template: BeakRecordTemplate.fields(title: _name),
                  groupBy: _name,
                  quantity: _quantity,
                  presentation: BeakCatalogPresentation.rows,
                  maxOptions: 20,
                  dependencies: [_title],
                  groupOrder: (_) => ['Sold out', 'Coffee'],
                  notice: BeakFormNotice(
                    plain: true,
                    message: (_) => 'Availability follows your selection.',
                  ),
                  footer: 'Choose All to browse the full eligible catalog.',
                  tabs: [
                    BeakCatalogFilter(
                      label: 'Scoped',
                      filterBuilder: (state) =>
                          _name.eq(state.read(_title) ?? 'Coffee'),
                    ),
                    const BeakCatalogFilter(label: 'All'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Sold out'), findsNothing);
      session.root.set(_title, 'Sold out');
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsNothing);
      expect(find.text('Sold out'), findsOneWidget);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Sold out'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Sold out')).dy,
        lessThan(tester.getTopLeft(find.text('Coffee')).dy),
      );
      expect(find.text('Availability follows your selection.'), findsOneWidget);
      expect(
        find.text('Choose All to browse the full eligible catalog.'),
        findsOneWidget,
      );
      expect(source.createCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'populated placeholder and section guidance follow the live draft',
    (tester) async {
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              _title.inputText(label: 'Name'),
              BeakSection(
                title: 'Preview',
                trailing: BeakValueBinding.field(_title),
                children: [
                  BeakFormPlaceholder(
                    label: 'Not saved yet',
                    height: 90,
                    template: BeakRecordTemplate(
                      title: BeakValueBinding<String>.computed(
                        dependencies: [_title],
                        compute: (row) =>
                            'Create ${row.read(_title) ?? 'a basket'}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'Lunch');
      await tester.pumpAndSettle();
      expect(find.text('Create Lunch'), findsOneWidget);
      expect(find.text('Lunch'), findsNWidgets(2));
      expect(session.root.read(_title), 'Lunch');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('plain inline text retains focus and controller while typing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const lines = BeakToManyField(
      model: _Basket(),
      relation: _Basket.lines,
      target: _ValidatedLine(),
    );
    const note = BeakScalarField<String>(
      model: _ValidatedLine(),
      column: _ValidatedLine.name,
    );
    late BeakFormSession session;
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _CheckingSource(),
        onSession: (value) => session = value,
        layout: BeakFormLayout(
          children: [
            lines.tableForm(
              children: [
                BeakCard(
                  title: 'Preparation note',
                  presentation: BeakCardPresentation.plain,
                  collapsible: true,
                  initiallyExpanded: false,
                  children: [note.inputText(label: 'Note')],
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final row = session.root.addRow(lines);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preparation note'));
    await tester.pumpAndSettle();
    final editorFinder = find.byType(EditableText);
    await tester.showKeyboard(editorFinder);
    final editor = tester.widget<EditableText>(editorFinder);
    final controller = editor.controller;
    final focus = editor.focusNode;
    final semanticId = tester.getSemantics(editorFinder).id;
    final semanticParent = tester.getSemantics(editorFinder).parent?.id;
    List<int> siblingIds() {
      final ids = <int>[];
      tester.getSemantics(editorFinder).parent!.visitChildren((node) {
        ids.add(node.id);
        return true;
      });
      return ids;
    }

    final semanticSiblings = siblingIds();
    const text = 'No extra salt';
    for (var length = 1; length <= text.length; length++) {
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text.substring(0, length),
          selection: TextSelection.collapsed(offset: length),
        ),
      );
      await tester.pump();
      expect(tester.getSemantics(editorFinder).id, semanticId);
      expect(tester.getSemantics(editorFinder).parent?.id, semanticParent);
      expect(siblingIds(), semanticSiblings);
      await tester.pump(const Duration(milliseconds: 60));
      final current = tester.widget<EditableText>(editorFinder);
      expect(current.controller, same(controller));
      expect(current.focusNode, same(focus));
      expect(focus.hasFocus, isTrue);
      expect(controller.text, text.substring(0, length));
      expect(row.read(note), text.substring(0, length));
    }
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(row.read(note), text);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'async catalog refresh retains variant and expanded staged options',
    (tester) async {
      final source = _CatalogWaitSource();
      const group = BeakScalarField<String>(
        model: _Item(),
        column: _Item.group,
      );
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              _title.input(),
              _lines.tableForm(
                children: const [],
                advancedPresentation: BeakAdvancedPresentation.inline,
                advancedForm: BeakFormLayout(
                  children: [_quantity.inputNumber()],
                ),
                catalog: BeakRelationCatalog(
                  presentation: BeakCatalogPresentation.rows,
                  selection: _selection,
                  groupBy: group,
                  variantLabel: _name,
                  quantity: _quantity,
                  template: BeakRecordTemplate.fields(title: group),
                  options: (state) => _selection.options(
                    filter: state.read(_title) == null
                        ? null
                        : group.eq(state.read(_title)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      Finder button(String name) => find.byWidgetPredicate(
        (widget) => widget is OiButton && widget.semanticLabel == name,
      );
      tester.widget<OiSelect<Object>>(find.byType(OiSelect<Object>)).onChanged!(
        'large',
      );
      await tester.pumpAndSettle();
      await tester.tap(button('Increase drink, Large'));
      await tester.pumpAndSettle();
      await tester.tap(button('Options'));
      await tester.pumpAndSettle();
      final row = session.root.rows(_lines).single;
      row.set(_quantity, 7);
      await tester.pumpAndSettle();
      expect(find.text('Quantity'), findsOneWidget);
      source.pause = true;
      session.root.set(_title, 'drink');
      await tester.pump();
      expect(source.pending, isNotNull);
      expect(
        find.text('Quantity'),
        findsNothing,
        reason: 'Pending results are not interactive',
      );
      await source.release();
      await tester.pumpAndSettle();
      expect(
        tester.widget<OiSelect<Object>>(find.byType(OiSelect<Object>)).value,
        'large',
      );
      expect(
        find.text('Quantity'),
        findsOneWidget,
        reason: 'The same row stays expanded after a real refresh',
      );
      expect(row.read(_quantity), 7);
      expect(row.read(_selection)?['id']?.raw, 'large');
      expect(source.createCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog quantity actions distinguish equally named variants', (
    tester,
  ) async {
    final source = FakeDataSource(
      models: const [_Basket(), _Line(), _Item()],
      records: {
        'catalog': {
          'coffee': BeakRecord.fromRow({
            'id': 'coffee',
            'name': 'Regular',
            'group': 'Coffee',
          }),
          'tea': BeakRecord.fromRow({
            'id': 'tea',
            'name': 'Regular',
            'group': 'Tea',
          }),
        },
      },
    );
    const group = BeakScalarField<String>(model: _Item(), column: _Item.group);
    late BeakFormSession session;
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: source,
        onSession: (value) => session = value,
        layout: BeakFormLayout(
          children: [
            _lines.tableForm(
              children: const [],
              catalog: BeakRelationCatalog(
                presentation: BeakCatalogPresentation.rows,
                selection: _selection,
                template: BeakRecordTemplate.fields(title: group),
                variantLabel: _name,
                quantity: _quantity,
              ),
            ),
          ],
        ),
      ),
    );
    Finder button(String label) => find.byWidgetPredicate(
      (widget) => widget is OiButton && widget.semanticLabel == label,
    );
    await tester.tap(button('Increase Coffee, Regular'));
    await tester.pumpAndSettle();
    await tester.tap(button('Increase Tea, Regular'));
    await tester.pumpAndSettle();
    await tester.tap(button('Increase Coffee, Regular'));
    await tester.pumpAndSettle();
    final quantities = {
      for (final row in session.root.rows(_lines))
        (row.read(_selection)?['id']?.raw): row.read(_quantity),
    };
    expect(quantities, {'coffee': 2, 'tea': 1});
    expect(button('Decrease Coffee, Regular'), findsOneWidget);
    expect(button('Decrease Tea, Regular'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain relation cards keep their indicator within row height', (
    tester,
  ) async {
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _source(),
        layout: BeakFormLayout(
          children: [
            _choice.inputCards(
              options: (_) => _choice.options(filter: _name.eq('Coffee')),
            ),
          ],
        ),
      ),
      width: 800,
    );
    expect(find.text('Coffee'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact row widths preserve editor space without duplicate labels',
    (tester) async {
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              _lines.tableForm(
                presentation: BeakRelationTablePresentation.rows,
                columnWidths: const [90, 80],
                advancedPresentation: BeakAdvancedPresentation.inline,
                identityChildren: [
                  _selection.inputCombobox(
                    label: 'Size',
                    template: BeakRecordTemplate(
                      title: BeakValueBinding<String>.computed(
                        dependencies: const [_name],
                        compute: (row) => 'Cup of ${row.read(_name)}',
                      ),
                    ),
                  ),
                ],
                children: [
                  _quantity.inputQuantity(),
                  BeakCalculated(
                    label: 'Total',
                    value: (state) => state.read(_quantity),
                    subtitle: (_, format) => '${format.currency(4.5)} each',
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ],
          ),
        ),
        width: 720,
      );
      final row = session.root.addRow(_lines);
      row.select(_selection, _available);
      await tester.pumpAndSettle();
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('Size'), findsNothing);
      expect(find.text('Cup of Coffee'), findsOneWidget);
      expect(find.textContaining('each'), findsOneWidget);
      final combo = find.byType(OiComboBox<BeakRecord>);
      expect(combo, findsOneWidget);
      expect(tester.getSize(combo).width, 140);
      expect(tester.widget<OiComboBox<BeakRecord>>(combo).label, 'Size');
      expect(
        tester.getSize(find.byType(OiQuantitySelector)).width,
        lessThanOrEqualTo(90),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('checkbox catalogs keep retired selections visible for removal', (
    tester,
  ) async {
    final source = _source();
    source.store.seed(const _Basket(), [
      BeakRecord.fromRow({'id': 'b1', 'title': 'Saved'}),
    ]);
    source.store.seed(const _Line(), [
      BeakRecord.fromRow({
        'id': 'l1',
        'basket_id': 'b1',
        'item_id': 'sold',
        'quantity': 1,
      }),
    ]);
    late BeakFormSession session;
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: source,
        recordId: 'b1',
        onSession: (value) => session = value,
        layout: BeakFormLayout(
          children: [
            _lines.tableForm(
              children: const [],
              removeBehavior: BeakRemoveBehavior.deleteOwned,
              catalog: BeakRelationCatalog(
                presentation: BeakCatalogPresentation.checkboxes,
                selection: _selection,
                template: _template,
                maxOptions: 20,
                options: (_) => _selection.options(filter: _name.eq('Coffee')),
                disabledReason: (record, _) =>
                    record['id']?.raw == 'sold' ? 'Unavailable' : null,
              ),
            ),
          ],
        ),
      ),
    );
    final saved = session.root.rows(_lines).single;
    expect(find.text('Sold out'), findsOneWidget);
    await tester.tap(find.text('Sold out'));
    await tester.pumpAndSettle();
    expect(saved.removed, isTrue);
    expect(session.root.rows(_lines), isEmpty);
    expect(source.deleteCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'checkbox catalogs stage unique owned rows and respect availability',
    (tester) async {
      final source = _source();
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              _lines.tableForm(
                children: const [],
                removeBehavior: BeakRemoveBehavior.deleteOwned,
                catalog: BeakRelationCatalog(
                  presentation: BeakCatalogPresentation.checkboxes,
                  selection: _selection,
                  template: _template,
                  maxOptions: 20,
                  disabledReason: (record, _) =>
                      record['id']?.raw == 'sold' ? 'Unavailable' : null,
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(EditableText), findsNothing);
      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();
      final row = session.root.rows(_lines).single;
      expect(row.read(_selection)?['id']?.raw, 'coffee');
      expect(
        find.text('Coffee'),
        findsOneWidget,
        reason:
            'Selected rows are represented by the checkbox, without duplicate editors',
      );
      final sold = tester
          .widgetList<OiCheckbox>(find.byType(OiCheckbox))
          .firstWhere((checkbox) => checkbox.semanticLabel == 'Sold out');
      expect(sold.enabled, isFalse);
      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();
      expect(session.root.rows(_lines), isEmpty);
      expect(source.createCalls, isEmpty);
      expect(source.deleteCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inline row options preserve staged edits and reveal validation',
    (tester) async {
      final source = _source();
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              _lines.tableForm(
                children: const [],
                presentation: BeakRelationTablePresentation.rows,
                advancedPresentation: BeakAdvancedPresentation.inline,
                advancedContentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                advancedForm: BeakFormLayout(
                  children: [
                    _quantity.inputNumber(validate: const [BeakMin(1)]),
                  ],
                ),
                catalog: BeakRelationCatalog(
                  presentation: BeakCatalogPresentation.rows,
                  selection: _selection,
                  quantity: _quantity,
                  template: _template,
                ),
              ),
            ],
          ),
        ),
      );
      Finder button(String label) => find.byWidgetPredicate(
        (widget) => widget is OiButton && widget.semanticLabel == label,
      );
      await tester.tap(button('Increase Coffee'));
      await tester.pumpAndSettle();
      final closedHeight = tester.getTopLeft(find.text('Sold out')).dy;
      final hidden = find.byWidgetPredicate(
        (widget) => widget is Offstage && widget.offstage,
        skipOffstage: false,
      );
      expect(hidden, findsOneWidget);
      final host = find
          .ancestor(of: hidden, matching: find.byType(Padding))
          .first;
      expect(
        tester.getSize(host).height,
        0,
        reason: 'A closed advanced form contributes no hidden spacing',
      );
      await tester.tap(button('Options'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Sold out')).dy,
        greaterThan(closedHeight),
      );
      final surface = find
          .ancestor(of: find.text('Quantity'), matching: find.byType(OiSurface))
          .first;
      expect(
        tester.getTopLeft(find.text('Quantity')).dy -
            tester.getTopLeft(surface).dy,
        10,
      );
      expect(
        tester.getTopLeft(find.text('Quantity')).dx -
            tester.getTopLeft(surface).dx,
        12,
      );
      expect(find.byType(OiDialog), findsNothing);
      await tester.enterText(find.byType(EditableText).last, '7');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final row = session.root.rows(_lines).single;
      expect(row.read(_quantity), 7);
      await tester.tap(button('Options'));
      await tester.pumpAndSettle();
      expect(find.text('Quantity'), findsNothing);
      expect(tester.getTopLeft(find.text('Sold out')).dy, closedHeight);
      await tester.tap(button('Options'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        '7',
      );
      await tester.tap(button('Options'));
      await tester.pumpAndSettle();
      row.set(_quantity, 0);
      expect(await row.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Quantity'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Sold out')).dy,
        greaterThan(closedHeight),
        reason: 'Validation errors reveal the complete advanced surface',
      );
      expect(source.createCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'code lookup retains scope, rejects ambiguity, and ignores stale replies',
    (tester) async {
      final source = _CodeLookupSource();
      late BeakFormSession session;
      final input = _choice.inputCode(
        codeField: _name,
        options: (state) => BeakOptionQuery(
          model: const _Item(),
          query: BeakQuerySpec(
            table: 'catalog',
            filter: _name.eq(state.read(_title) ?? 'Coffee'),
            // Code lookup must check the first two matches, even if an option
            // source normally requests a single result on a later page.
            pagination: const BeakPagination(page: 3, perPage: 1),
          ),
        ),
      );
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          layout: BeakFormLayout(children: [_title.inputText(), input]),
          onSession: (value) => session = value,
        ),
      );
      await tester.enterText(find.byType(EditableText).last, 'Coffee');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(source.pending, isNotNull);
      expect(
        tester
            .widget<OiButton>(
              find.byWidgetPredicate(
                (widget) => widget is OiButton && widget.label == 'Apply',
              ),
            )
            .loading,
        isTrue,
      );
      session.root.set(_title, 'Sold out');
      await source.resolve();
      await tester.pumpAndSettle();
      expect(session.root.read(_choice), isNull);
      expect(
        find.text('No available record matches this code.'),
        findsOneWidget,
      );
      expect(
        source.queryCalls.last.pagination,
        const BeakPagination(perPage: 2),
      );
      // The same exact code is now out of scope despite existing in the table.
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await source.resolve();
      await tester.pumpAndSettle();
      expect(session.root.read(_choice), isNull);
      // Two records sharing a code are never silently reduced to the first one.
      session.root.set(_title, 'Coffee');
      source.store.seed(const _Item(), [
        _available,
        BeakRecord.fromRow({'id': 'duplicate', 'name': 'Coffee'}),
      ]);
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await source.resolve();
      await tester.pumpAndSettle();
      expect(
        find.text('This code matches more than one record.'),
        findsOneWidget,
      );
      expect(session.root.read(_choice), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'code lookup applies an exact eligible relation and removes locally',
    (tester) async {
      final source = _source();
      late BeakFormSession session;
      final input = _choice.inputCode(
        codeField: _name,
        label: 'Product code',
        selectionSummary: BeakCalculated(
          value: (state) =>
              state.read(_choice) == null ? 'Unapplied' : 'Applied preview',
        ),
        placeholder: 'Enter a code',
        normalizeCode: (value) =>
            '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}',
        disabledReason: (record, _) =>
            record['id']?.raw == 'sold' ? 'Unavailable' : null,
        template: _template,
      );
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          layout: BeakFormLayout(children: [input]),
          onSession: (value) => session = value,
        ),
      );
      await tester.enterText(find.byType(EditableText), 'cof');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(session.root.read(_choice), isNull);
      expect(
        find.text('No available record matches this code.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(EditableText), ' sold out ');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsOneWidget);
      expect(session.root.read(_choice), isNull);
      await tester.enterText(find.byType(EditableText), ' coffee ');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(session.root.read(_choice)?['id']?.raw, 'coffee');
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Applied preview'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Applied preview'), findsNothing);
      expect(session.root.read(_choice), isNull);
      expect(source.createCalls, isEmpty);
      expect(source.updateCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calculated requirements react without producing model changes', (
    tester,
  ) async {
    late BeakFormSession session;
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _source(),
        layout: BeakFormLayout(
          children: [
            _title.inputText(),
            BeakCalculated(
              dependencies: [_title],
              presentation: BeakCalculatedPresentation.checkbox,
              labelBuilder: (state) =>
                  'Required for ${state.read(_title) ?? 'this basket'}',
              value: (state) => state.read(_title) == 'Approved',
              description: (_) => 'Managed by the policy.',
            ),
          ],
        ),
        onSession: (value) => session = value,
      ),
    );
    expect(tester.widget<OiCheckbox>(find.byType(OiCheckbox)).value, isFalse);
    await tester.enterText(find.byType(EditableText), 'Approved');
    await tester.pumpAndSettle();
    final checkbox = tester.widget<OiCheckbox>(find.byType(OiCheckbox));
    expect(checkbox.value, isTrue);
    expect(checkbox.enabled, isFalse);
    expect(find.text('Required for Approved'), findsOneWidget);
    expect(session.root.read(_title), 'Approved');
    expect(
      session.root.snapshot.values.keys,
      isNot(contains('Required for Approved')),
    );
  });

  testWidgets('compact relation cards wrap and bind typed capacity progress', (
    tester,
  ) async {
    late BeakFormSession session;
    final input = _choice.inputCards(
      compact: true,
      minCardWidth: 130,
      template: BeakRecordTemplate(
        title: BeakValueBinding.field(_name),
        progress: BeakValueBinding<num>.computed(
          dependencies: [_name],
          compute: (row) => row.read(_name) == 'Coffee' ? .4 : 0,
        ),
        progressHeight: 8,
        progressStriped: true,
      ),
      disabledReason: (row, _) => row['id']?.raw == 'sold' ? 'Full' : null,
    );
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _source(),
        layout: BeakFormLayout(children: [input]),
        onSession: (value) => session = value,
      ),
      width: 360,
    );
    final bars = tester
        .widgetList<OiCapacityIndicator>(find.byType(OiCapacityIndicator))
        .toList();
    expect(bars.map((bar) => bar.value), containsAll([.4, 0]));
    expect(
      bars.every((bar) => bar.height == 8 && bar.stripedRemainder),
      isTrue,
    );
    expect(input.template!.fields, contains(_name));
    expect(
      tester
          .widget<OiRadioTile<Object>>(
            find.byKey(const ValueKey('choice:coffee')),
          )
          .indicator,
      OiRadioTileIndicator.none,
    );
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    expect(session.root.read(_choice)?['id']?.raw, 'coffee');
    await tester.tap(find.text('Sold out'));
    expect(session.root.read(_choice)?['id']?.raw, 'coffee');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rich relation card padding preserves defaults and declared insets',
    (tester) async {
      double? defaultHeight;
      for (final inset in [null, 17.0]) {
        await _pump(
          tester,
          BeakConfiguredForm(
            key: ValueKey(inset),
            model: const _Basket(),
            dataSource: _source(),
            layout: BeakFormLayout(
              children: [
                _choice.inputCards(
                  cardPadding: inset == null ? null : EdgeInsets.all(inset),
                  template: BeakRecordTemplate(
                    title: BeakValueBinding.field(_name),
                    textGap: 2,
                    subtitle: [
                      BeakValueBinding<String>.computed(
                        dependencies: const [],
                        compute: (_) => 'Available choice',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        final card = find.byKey(const ValueKey('choice:coffee'));
        expect(
          tester.widget<OiRadioTile<Object>>(card).contentPadding,
          EdgeInsets.all(inset ?? 16),
        );
        final height = tester.getSize(card).height;
        if (inset == null) {
          defaultHeight = height;
        } else {
          expect(height - defaultHeight!, 2);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('choice cards respect inline metadata declared by the template', (
    tester,
  ) async {
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _source(),
        layout: BeakFormLayout(
          children: [
            _choice.inputCards(
              minCardWidth: 400,
              template: BeakRecordTemplate(
                title: BeakValueBinding.field(_name),
                inlineSubtitle: true,
                subtitle: [
                  BeakValueBinding<String>.computed(
                    dependencies: const [],
                    compute: (_) => 'Employee',
                  ),
                  BeakValueBinding<String>.computed(
                    dependencies: const [],
                    compute: (_) => 'Default',
                    badge: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final employee = tester.getCenter(find.text('Employee').first);
    final badge = tester.getCenter(find.text('Default').first);
    expect(badge.dx, greaterThan(employee.dx));
    expect(badge.dy, closeTo(employee.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection summaries hydrate without an editable table', (
    tester,
  ) async {
    final source = _source();
    source.store.seed(const _Basket(), [
      BeakRecord.fromRow({'id': 'b1', 'title': 'Friday'}),
    ]);
    source.store.seed(const _Line(), [
      BeakRecord.fromRow({'id': 'l1', 'basket_id': 'b1', 'quantity': 3}),
    ]);
    late BeakFormSession session;
    await _pump(
      tester,
      BeakFormattingScope(
        formatting: const BeakFormatting(locale: 'en_US', currency: 'EUR'),
        child: BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          recordId: 'b1',
          mode: BeakFormMode.read,
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              BeakFormSummary(
                source: _lines,
                lines: [
                  BeakSummaryLine(
                    label: 'Items',
                    dependencies: [_quantity],
                    labelBuilder: (row, _) => '${row.read(_quantity)} items',
                    value: (row) =>
                        BeakDecimal((row.read(_quantity) ?? 0) * 450, scale: 2),
                    format: BeakValueFormat.currency,
                    subtitle: (_, format) =>
                        'Unit price ${format.currency(4.5)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      width: 360,
    );
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('€13.50'), findsOneWidget);
    expect(find.text('Unit price €4.50'), findsOneWidget);
    expect(session.root.rows(_lines), hasLength(1));
    expect(
      () => session.root.addRow(_lines),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(session.root.isDirty, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'summary and editor share staged rows regardless of placement order',
    (tester) async {
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              BeakFormSummary(
                source: _lines,
                lines: [
                  BeakSummaryLine(
                    label: 'Draft quantity',
                    value: (row) => row.read(_quantity),
                    visibleIf: (row) => (row.read(_quantity) ?? 0) > 1,
                    valueStyle: const TextStyle(fontSize: 24),
                    dividerBefore: true,
                  ),
                ],
              ),
              _lines.tableForm(children: [_quantity.inputNumber()]),
            ],
          ),
        ),
      );
      final row = session.root.addRow(
        _lines,
        values: BeakRecord.fromRow({'quantity': 1}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Draft quantity'), findsNothing);
      row.set(_quantity, 4);
      await tester.pumpAndSettle();
      expect(find.text('Draft quantity'), findsOneWidget);
      expect(session.root.rows(_lines).single, same(row));
      expect(find.byType(OiKeyValue), findsOneWidget);
      session.root.removeRow(row);
      await tester.pumpAndSettle();
      expect(find.text('Draft quantity'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [1440.0, 560.0]) {
    testWidgets(
      'review sections edit the shared wizard draft at width $width',
      (tester) async {
        late BeakFormSession session;
        await _pump(
          tester,
          BeakConfiguredForm(
            model: const _Basket(),
            dataSource: _source(),
            navigation: BeakWizardNavigation.rail,
            header: BeakFormWidget(
              visibleIf: (state) => state.stepIndex == 1,
              builder: (_, _) => const Text('Review milestone'),
            ),
            steps: [
              BeakWizardStep(title: 'Basics', children: [_title.input()]),
              BeakWizardStep(
                title: 'Review',
                children: [
                  BeakReviewSection(
                    title: 'Basket details',
                    stepIndex: 0,
                    children: [
                      BeakFormTemplate(
                        template: BeakRecordTemplate.fields(title: _title),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            onSession: (value) => session = value,
          ),
          width: width,
        );
        expect(await session.goToStep(1), isFalse);
        await tester.pumpAndSettle();
        expect(session.currentStep, 0);
        expect(find.text('Review milestone'), findsNothing);
        await tester.enterText(find.byType(EditableText), 'Friday delivery');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(session.currentStep, 1);
        expect(BeakFormReader(session.root).stepIndex, 1);
        expect(find.text('Review milestone'), findsOneWidget);
        expect(find.byType(EditableText), findsNothing);
        final heading = tester.getTopLeft(find.text('Basket details'));
        final content = tester.getTopLeft(find.text('Friday delivery'));
        if (width > 600) {
          expect(content.dx - heading.dx, closeTo(184, 1));
        } else {
          expect(content.dx, closeTo(heading.dx, 1));
          expect(content.dy, greaterThan(heading.dy));
        }
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(session.currentStep, 0);
        expect(find.text('Review milestone'), findsNothing);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Friday delivery',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'rail navigation validates forward jumps and keeps a live shared summary',
    (tester) async {
      final source = _source();
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          navigation: BeakWizardNavigation.rail,
          header: BeakFormWidget(
            builder: (_, _) => const OiLabel.h2('New basket'),
          ),
          aside: BeakFormTemplate(
            template: BeakRecordTemplate.fields(title: _title),
          ),
          footer: BeakFormWidget(
            builder: (_, _) => const OiLabel.caption('Nothing saved yet'),
          ),
          steps: [
            BeakWizardStep(title: 'Basics', children: [_title.input()]),
            const BeakWizardStep(title: 'Review', children: []),
          ],
          onSession: (value) => session = value,
        ),
      );
      final layout = tester.widget<OiWizardLayout>(find.byType(OiWizardLayout));
      final continueButton = find.widgetWithText(OiButton, 'Continue');
      final mainCard = find
          .ancestor(of: continueButton, matching: find.byType(OiSurface))
          .first;
      expect(
        tester.getBottomRight(mainCard).dx -
            tester.getBottomRight(continueButton).dx,
        closeTo(32, 1.1),
      );
      layout.onStepTap!(1);
      await tester.pumpAndSettle();
      expect(
        tester.widget<OiWizardLayout>(find.byType(OiWizardLayout)).currentStep,
        0,
      );
      expect(find.text('This field is required.'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Friday delivery');
      await tester.pumpAndSettle();
      expect(find.text('Friday delivery'), findsWidgets);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<OiWizardLayout>(find.byType(OiWizardLayout)).currentStep,
        1,
      );
      expect(session.root.read(_title), 'Friday delivery');
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(source.createCalls, isEmpty);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Friday delivery',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wizard aside footer stays pinned and saves through the shared draft',
    (tester) async {
      final source = _source();
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          navigation: BeakWizardNavigation.rail,
          steps: const [BeakWizardStep(title: 'Review', children: [])],
          aside: BeakFormWidget(
            builder: (_, _) =>
                const SizedBox(height: 1200, child: Text('Long summary')),
          ),
          asideFooter: BeakFormLayout(
            children: [
              _title.inputText(label: 'Final reference'),
              BeakCalculated(
                label: 'Live total',
                value: (state) => state.read(_title)?.length ?? 0,
              ),
            ],
          ),
          onSession: (value) => session = value,
        ),
      );
      final reference = find.text('Final reference');
      final before = tester.getTopLeft(reference);
      final summaryScroll = find
          .ancestor(
            of: find.text('Long summary'),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      await tester.drag(summaryScroll, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(reference), before);
      expect(before.dy, greaterThan(700));
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsOneWidget);
      expect(source.createCalls, isEmpty);
      await tester.enterText(find.byType(EditableText), 'ABCD');
      await tester.pumpAndSettle();
      expect(session.root.read(_title), 'ABCD');
      expect(find.text('Live total: 4'), findsOneWidget);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(source.createCalls.single.$2['title']?.raw, 'ABCD');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact aside footer and summary keep observing the shared draft',
    (tester) async {
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          navigation: BeakWizardNavigation.rail,
          steps: const [BeakWizardStep(title: 'Review', children: [])],
          aside: BeakCalculated(
            label: 'Live total',
            value: (state) => state.read(_title)?.length ?? 0,
          ),
          asideFooter: BeakFormLayout(
            children: [_title.inputText(label: 'Final reference')],
          ),
          onSession: (value) => session = value,
        ),
        width: 375,
      );
      expect(find.text('Final reference'), findsNothing);
      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'ABCD');
      await tester.pumpAndSettle();
      expect(session.root.read(_title), 'ABCD');
      expect(find.text('Live total: 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final gap in [16.0, 8.0]) {
    testWidgets('titled form cards separate their content by $gap', (
      tester,
    ) async {
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          mode: BeakFormMode.read,
          layout: BeakFormLayout(
            children: [
              BeakCard(
                title: 'Card heading',
                headerGap: gap,
                padding: const EdgeInsets.all(20),
                children: [BeakCalculated(value: (_) => 'Card content')],
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getRect(find.text('Card content')).top -
            tester.getRect(find.text('Card heading')).bottom,
        gap,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final presentation in BeakCardPresentation.values) {
    testWidgets(
      'collapsed ${presentation.name} cards retain drafts and reveal validation errors',
      (tester) async {
        final source = _source();
        await _pump(
          tester,
          BeakConfiguredForm(
            model: const _Basket(),
            dataSource: source,
            layout: BeakFormLayout(
              children: [
                BeakCard(
                  title: 'Advanced',
                  presentation: presentation,
                  collapsible: true,
                  initiallyExpanded: false,
                  children: [_title.inputText()],
                ),
              ],
            ),
          ),
        );
        expect(find.byType(EditableText).hitTestable(), findsNothing);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.byType(EditableText).hitTestable(), findsOneWidget);
        expect(
          find.text('This field is required.').hitTestable(),
          findsOneWidget,
        );
        await tester.enterText(find.byType(EditableText), 'Retained');
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is OiTappable &&
                widget.semanticLabel == 'Collapse Advanced',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EditableText).hitTestable(), findsNothing);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(source.createCalls.single.$2['title']?.raw, 'Retained');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('compact wizard presents summary through an accessible sheet', (
    tester,
  ) async {
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _source(),
        navigation: BeakWizardNavigation.rail,
        aside: BeakFormWidget(
          builder: (_, _) => const OiLabel.body('Shared summary'),
        ),
        steps: [
          BeakWizardStep(title: 'Basics', children: [_title.input()]),
        ],
      ),
      width: 375,
    );
    expect(find.text('Shared summary'), findsNothing);
    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();
    expect(find.text('Shared summary'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'card choice creation stays beside its heading above the choices',
    (tester) async {
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          layout: BeakFormLayout(
            children: [
              _choice.inputCards(
                template: _template,
                label: 'Profile',
                exclusive: false,
                createLabel: 'Add profile',
              ),
            ],
          ),
        ),
      );
      expect(find.text('Add profile'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Add profile')).dy,
        lessThan(tester.getTopLeft(find.text('Coffee')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Add profile')).dx,
        greaterThan(tester.getTopLeft(find.text('Profile')).dx),
      );
      await tester.tap(find.text('Add profile'));
      await tester.pumpAndSettle();
      expect(find.byType(OiDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rich options disable unavailable choices and inline search uses one draft',
    (tester) async {
      final source = _source();
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          layout: BeakFormLayout(
            children: [
              _choice.inputSearch(
                template: _template,
                disabledReason: (record, _) =>
                    _name.readFrom(record) == 'Sold out'
                    ? 'No remaining capacity'
                    : null,
              ),
            ],
          ),
          onSession: (value) => session = value,
        ),
      );
      final unavailable = tester.widget<OiRadioTile<Object>>(
        find.byKey(const ValueKey('choice:sold')),
      );
      expect(unavailable.enabled, isFalse);
      expect(find.text('No remaining capacity'), findsOneWidget);
      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();
      expect(session.root.read(_choice)?['id']?.raw, 'coffee');
      expect(source.createCalls, isEmpty);
      await tester.enterText(find.byType(EditableText), 'Sold');
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsNothing);
      expect(source.queryCalls.last.search?.term, 'Sold');
      expect(session.root.read(_choice)?['id']?.raw, 'coffee');
    },
  );

  testWidgets(
    'catalog adds and removes owned rows locally with quantity defaults',
    (tester) async {
      final source = _source();
      late BeakFormSession session;
      final table = _lines.tableForm(
        label: 'Order items',
        catalog: BeakRelationCatalog(
          selection: _selection,
          template: _template,
          disabledReason: (record, _) =>
              _name.readFrom(record) == 'Sold out' ? 'Unavailable' : null,
        ),
        children: [_quantity.inputNumber()],
      );
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          layout: BeakFormLayout(children: [table]),
          onSession: (value) => session = value,
        ),
      );
      final add = tester
          .widgetList<OiButton>(find.byType(OiButton))
          .firstWhere((button) => button.semanticLabel == 'Add Coffee');
      add.onTap!();
      await tester.pumpAndSettle();
      final row = session.root.rows(_lines).single;
      expect(row.read(_selection)?['id']?.raw, 'coffee');
      expect(row.read(_quantity), 1);
      expect(source.createCalls, isEmpty);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(session.root.rows(_lines), isEmpty);
      expect(source.deleteCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'disabled option validation cannot be bypassed by a programmatic selection',
    () async {
      final input = _choice.inputCards(disabledReason: (_, _) => 'Unavailable');
      final session = BeakFormSession(
        model: const _Basket(),
        dataSource: _source(),
        layout: BeakFormLayout(children: [input]),
      );
      addTearDown(session.dispose);
      await session.load();
      session.root.select(_choice, _available);
      expect(await session.root.validate(), false);
      expect(session.root.errors[_choice.key], ['Unavailable']);
    },
  );

  test(
    'region template dependencies eager-load existing relationships',
    () async {
      final source = _source();
      source.store.seed(const _Basket(), [
        BeakRecord.fromRow({'id': 'b1', 'choice_id': 'coffee'}),
      ]);
      final template = BeakRecordTemplate(
        title: BeakValueBinding<String>.computed(
          dependencies: [_choice],
          compute: (reader) => reader.read(_choice)?['name']?.raw as String?,
        ),
      );
      final session = BeakFormSession(
        model: const _Basket(),
        dataSource: source,
        recordId: 'b1',
        layout: const BeakFormLayout(children: []),
        regions: [BeakFormTemplate(template: template)],
      );
      addTearDown(session.dispose);
      await session.load();
      expect(session.initialized, true);
      expect(session.root.read(_choice)?['name']?.raw, 'Coffee');
      expect(
        source.queryCalls
            .where((query) => query.table == 'baskets')
            .single
            .relationLoads
            .single
            .relationKey,
        'choice',
      );
    },
  );
  test(
    'picker hydration and search retain nested dependencies from summary regions',
    () async {
      const nested = BeakToManyField(
        model: _Basket(),
        relation: _Item.stockLines,
        target: _Line(),
        path: [_Basket.choice],
      );
      final source = _source();
      source.store.seed(const _Basket(), [
        BeakRecord.fromRow({'id': 'b1', 'choice_id': 'coffee'}),
      ]);
      source.store.seed(const _Line(), [
        BeakRecord.fromRow({'id': 'stock', 'item_id': 'coffee', 'quantity': 4}),
      ]);
      final input = _choice.inputCombobox();
      final session = BeakFormSession(
        model: const _Basket(),
        dataSource: source,
        recordId: 'b1',
        layout: BeakFormLayout(children: [input]),
        regions: [
          BeakFormSummary(
            lines: [
              BeakSummaryLine(
                label: 'Stock',
                value: (state) => state.read(nested)?.length,
                dependencies: [nested],
              ),
            ],
          ),
        ],
      );
      addTearDown(session.dispose);
      await session.load();
      expect(session.error.value, isNull);
      expect(session.root.read(nested)?.single['quantity']?.raw, 4);
      final options = await session.root.search(input, 'Coffee');
      expect(
        options.single.relations['stockLines']?.single['quantity']?.raw,
        4,
      );
      session.root.select(_choice, options.single);
      expect(session.root.read(nested)?.single['quantity']?.raw, 4);
    },
  );

  testWidgets(
    'adding an advanced row opens its complete form and cancel restores the graph',
    (tester) async {
      late BeakFormSession session;
      final source = _source();
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          layout: BeakFormLayout(
            children: [
              _lines.tableForm(
                showHeading: false,
                children: [_quantity.inputNumber()],
                advancedForm: BeakFormLayout(
                  children: [
                    _selection.inputCards(
                      template: _template,
                      validate: const [BeakRequired()],
                    ),
                  ],
                ),
              ),
            ],
          ),
          onSession: (value) => session = value,
        ),
      );
      await tester.tap(find.text('Add Lines'));
      await tester.pumpAndSettle();
      expect(find.byType(OiDialog), findsOneWidget);
      expect(find.text('Quantity'), findsWidgets);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.byType(OiDialog), findsOneWidget);
      expect(find.text('This field is required.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.root.rows(_lines), isEmpty);
      await tester.tap(find.text('Add Lines'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.byType(OiDialog), findsNothing);
      expect(
        session.root.rows(_lines).single.read(_selection)?['id']?.raw,
        'coffee',
      );
      expect(source.createCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [720.0, 390.0]) {
    testWidgets(
      'compact catalog rows preserve variants, extras and local facets at $width',
      (tester) async {
        final source = FakeDataSource(
          models: const [_Basket(), _Line(), _Item()],
          records: {
            'catalog': {
              'small': BeakRecord.fromRow({
                'id': 'small',
                'name': 'Coffee small',
                'group': 'coffee',
                'price': 300,
              }),
              'large': BeakRecord.fromRow({
                'id': 'large',
                'name': 'Coffee large',
                'group': 'coffee',
                'price': 450,
              }),
              for (final name in ['Cake', 'Soup', 'Salad', 'Water'])
                name: BeakRecord.fromRow({
                  'id': name,
                  'name': name,
                  'group': name,
                  'price': 700,
                }),
            },
          },
        );
        late BeakFormSession session;
        final table = _lines.tableForm(
          showHeading: false,
          children: const [],
          advancedForm: BeakFormLayout(children: [_quantity.inputNumber()]),
          catalog: BeakRelationCatalog(
            presentation: BeakCatalogPresentation.rows,
            compactToolbar: true,
            columnLabels: (
              item: 'Item',
              variant: 'Size and price',
              quantity: 'Quantity',
            ),
            tabs: const [
              BeakCatalogFilter(label: 'All'),
              BeakCatalogFilter(label: 'Featured'),
            ],
            selection: _selection,
            template: _template,
            quantity: _quantity,
            groupBy: const BeakScalarField<String>(
              model: _Item(),
              column: _Item.group,
            ),
            variantLabel: _name,
            price: const BeakScalarField<int>(
              model: _Item(),
              column: _Item.price,
            ).currency(minorUnits: true),
            maxOptions: 20,
            filters: [
              BeakCatalogFilter(
                label: 'Without cake',
                dependencies: [_name],
                matches: (record) => _name.readFrom(record) != 'Cake',
              ),
            ],
          ),
        );
        await _pump(
          tester,
          BeakConfiguredForm(
            model: const _Basket(),
            dataSource: source,
            layout: BeakFormLayout(children: [table]),
            onSession: (value) => session = value,
          ),
          width: width,
        );
        Finder button(String label) => find.byWidgetPredicate(
          (widget) => widget is OiButton && widget.semanticLabel == label,
        );
        if (width >= 600) {
          expect(
            tester.getBottomLeft(button('Increase Water')).dy -
                tester.getTopLeft(button('Increase Coffee small')).dy,
            lessThan(450),
            reason: 'Five catalog rows fit without tall individual cards',
          );
        }
        final selector = tester.widget<OiSelect<Object>>(
          find.byType(OiSelect<Object>),
        );
        expect(selector.options.first.label, contains('3.00'));
        expect(selector.options.last.label, contains('4.50'));
        await tester.ensureVisible(button('Increase Coffee small'));
        await tester.tap(button('Increase Coffee small'));
        await tester.pumpAndSettle();
        await tester.tap(button('Increase Coffee small'));
        await tester.pumpAndSettle();
        expect(session.root.rows(_lines).single.read(_quantity), 2);
        await tester.tap(button('Options'));
        await tester.pumpAndSettle();
        final row = session.root.rows(_lines).single;
        row.set(_quantity, 9);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(
          row.read(_quantity),
          2,
          reason: 'Cancelling advanced options restores the shared checkpoint',
        );
        tester
            .widget<OiSelect<Object>>(find.byType(OiSelect<Object>))
            .onChanged!('large');
        await tester.pumpAndSettle();
        await tester.tap(button('Increase Coffee large'));
        await tester.pumpAndSettle();
        expect(session.root.rows(_lines).map((row) => row.read(_quantity)), [
          2,
          1,
        ]);
        final queryCount = source.queryCalls.length;
        await tester.tap(find.text('Without cake'));
        await tester.pumpAndSettle();
        expect(button('Increase Cake'), findsNothing);
        expect(
          source.queryCalls.length,
          queryCount,
          reason: 'Local facets reuse the complete bounded result',
        );
        expect(session.root.rows(_lines), hasLength(2));
        expect(source.createCalls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('local catalog facets require a complete bounded population', () {
    final table = _lines.tableForm(
      children: const [],
      catalog: BeakRelationCatalog(
        selection: _selection,
        template: _template,
        filters: [BeakCatalogFilter(label: 'Local', matches: (_) => true)],
      ),
    );
    final session = BeakFormSession(
      model: const _Basket(),
      dataSource: _source(),
      layout: BeakFormLayout(children: [table]),
    );
    addTearDown(session.dispose);
    expect(
      () => session.root.catalogQuery(table, ''),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  testWidgets('grouped catalog variants retain independent staged quantities', (
    tester,
  ) async {
    final source = FakeDataSource(
      models: const [_Basket(), _Line(), _Item()],
      records: {
        'catalog': {
          'small': BeakRecord.fromRow({
            'id': 'small',
            'name': 'Small',
            'group': 'dish',
          }),
          'large': BeakRecord.fromRow({
            'id': 'large',
            'name': 'Large',
            'group': 'dish',
          }),
        },
      },
    );
    late BeakFormSession session;
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: source,
        layout: BeakFormLayout(
          children: [
            _lines.tableForm(
              children: const [],
              catalog: BeakRelationCatalog(
                selection: _selection,
                template: _template,
                quantity: _quantity,
                groupBy: const BeakScalarField<String>(
                  model: _Item(),
                  column: _Item.group,
                ),
                variantLabel: _name,
              ),
            ),
          ],
        ),
        onSession: (value) => session = value,
      ),
    );
    Finder button(String label) => find.byWidgetPredicate(
      (widget) => widget is OiButton && widget.semanticLabel == label,
    );
    await tester.tap(button('Increase Small'));
    await tester.pumpAndSettle();
    await tester.tap(button('Increase Small'));
    await tester.pumpAndSettle();
    expect(session.root.rows(_lines).single.read(_quantity), 2);
    tester.widget<OiSelect<Object>>(find.byType(OiSelect<Object>)).onChanged!(
      'large',
    );
    await tester.pumpAndSettle();
    await tester.tap(button('Increase Large'));
    await tester.pumpAndSettle();
    expect(session.root.rows(_lines).map((row) => row.read(_quantity)), [2, 1]);
    await tester.tap(button('Decrease Large'));
    await tester.pumpAndSettle();
    expect(session.root.rows(_lines), hasLength(1));
    tester.widget<OiSelect<Object>>(find.byType(OiSelect<Object>)).onChanged!(
      'small',
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(source.createCalls, isEmpty);
    expect(source.deleteCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'named primary action appears only at final step and commits the graph',
    (tester) async {
      final source = _CommandSource();
      BeakRecord? saved;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _PlaceBasket(),
          dataSource: source,
          navigation: BeakWizardNavigation.rail,
          submitAction: 'place',
          submitLabel: 'Place order',
          steps: [
            BeakWizardStep(title: 'Basics', children: [_title.input()]),
            const BeakWizardStep(title: 'Review', children: []),
          ],
          onSaved: (record) => saved = record,
        ),
      );
      expect(find.text('Place order'), findsNothing);
      expect(find.text('Place'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'Confirmed basket');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Place order'), findsOneWidget);
      expect(find.text('Place'), findsNothing);
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      expect(source.plan?.action, 'place');
      expect(
        source.plan?.operations.single.values['title']?.raw,
        'Confirmed basket',
      );
      expect(saved, isNotNull);
      expect(source.createCalls, isEmpty);
    },
  );

  testWidgets('summary notice and capacity observe the same live input', (
    tester,
  ) async {
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Line(),
        dataSource: _source(),
        layout: BeakFormLayout(
          children: [
            _quantity.inputNumber(),
            BeakFormSummary(
              lines: [
                BeakSummaryLine(
                  label: 'Selected quantity',
                  value: (state) => state.read(_quantity),
                ),
              ],
            ),
            BeakFormNotice(
              message: (_) => 'Large amount',
              tone: BeakColor.warning,
              visibleIf: (state) => (state.read(_quantity) ?? 0) >= 9,
            ),
            BeakFormCapacity(
              label: 'Capacity',
              value: (state) => state.read(_quantity),
              max: (_) => 10,
            ),
          ],
        ),
      ),
    );
    expect(find.text('Large amount'), findsNothing);
    await tester.enterText(find.byType(EditableText), '9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Large amount'), findsOneWidget);
    final capacity = tester.widget<OiCapacityIndicator>(
      find.byType(OiCapacityIndicator),
    );
    expect(capacity.value, 9);
    expect(capacity.max, 10);
    expect(find.text('Selected quantity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'review collection reuses its editable graph and saves each row once',
    (tester) async {
      final source = _source();
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          steps: [
            BeakWizardStep(
              title: 'Edit items',
              children: [
                _title.input(),
                _lines.tableForm(
                  children: [
                    _quantity.inputNumber(),
                    _selection.inputCombobox(),
                  ],
                ),
              ],
            ),
            BeakWizardStep(
              title: 'Review items',
              children: [
                _lines.tableForm(
                  readOnly: true,
                  minRows: 99,
                  children: [_quantity.inputNumber()],
                ),
              ],
            ),
          ],
          onSession: (value) => session = value,
        ),
      );
      session.root.set(_title, 'Draft order');
      final row = session.root.addRow(_lines);
      row.select(_selection, _available);
      row.set(_quantity, 2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(session.root.rows(_lines), [row]);
      expect(await session.validateStep(1), isTrue);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(
        source.createCalls.where((call) => call.$1 == 'lines'),
        hasLength(1),
      );
      expect(
        source.createCalls.where((call) => call.$1 == 'baskets'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('metric strips share draft values and wrap on compact screens', (
    tester,
  ) async {
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _source(),
        layout: BeakFormLayout(
          children: [
            _title.input(),
            BeakFormMetrics(
              metrics: [
                BeakFormMetric(
                  label: 'Basket name',
                  value: (state) => state.read(_title),
                ),
                BeakFormMetric(
                  label: 'Name length',
                  description: 'Updates while typing',
                  value: (state) => state.read(_title)?.length ?? 0,
                  dependencies: [_title],
                  format: BeakValueFormat.number,
                ),
              ],
            ),
          ],
        ),
      ),
      width: 375,
    );
    await tester.enterText(find.byType(EditableText), 'Dinner');
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsNWidgets(2));
    expect(find.text('6'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Name length')).dy,
      greaterThan(tester.getTopLeft(find.text('Basket name')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('workflow header saves a local draft and guards closing', (
    tester,
  ) async {
    final store = BeakMemoryDraftStore();
    final drafts = BeakFormDrafts(store: store, key: 'new', context: 'demo');
    var closed = false;
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _source(),
        drafts: drafts,
        header: const BeakFormHeader(title: 'New basket'),
        layout: BeakFormLayout(children: [_title.input()]),
        onClose: () => closed = true,
      ),
    );
    await tester.enterText(find.byType(EditableText), 'Local only');
    await tester.tap(find.text('Save as draft'));
    await tester.pumpAndSettle();
    expect(await store.read(drafts.storageKey('baskets', null)), isNotNull);
    final close = find.byWidgetPredicate(
      (widget) => widget is OiButton && widget.semanticLabel == 'Close',
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('Leave this form?'), findsWidgets);
    expect(closed, false);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(closed, false);
    await tester.tap(close);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(closed, true);
  });
  test(
    'suggested foreign keys hydrate the latest record and ignore stale replies',
    () async {
      final source = _DeferredSelectionSource();
      final session = BeakFormSession(
        model: const _SuggestedBasket(),
        dataSource: source,
        layout: BeakFormLayout(
          children: [
            _title.input(),
            _choice.inputCombobox(validate: const [BeakRequired()]),
          ],
        ),
      );
      addTearDown(session.dispose);
      await session.load();
      session.root.set(_title, 'coffee');
      await Future<void>.delayed(Duration.zero);
      expect(source.pending.keys, contains('coffee'));
      session.root.set(_title, 'sold');
      await Future<void>.delayed(Duration.zero);
      expect(source.pending.keys, contains('sold'));
      final validation = session.validate();
      await source.resolve('sold');
      expect(await validation, isTrue);
      expect(session.root.read(_choice)?['id']?.raw, 'sold');
      await source.resolve('coffee');
      await Future<void>.delayed(Duration.zero);
      expect(session.root.read(_choice)?['id']?.raw, 'sold');
    },
  );

  testWidgets('compact commands use their menu without a page frame', (
    tester,
  ) async {
    final source = FakeDataSource(
      models: const [_ActionBasket(), _Item(), _Line()],
      records: {
        'baskets': {
          'b1': BeakRecord.fromRow({'id': 'b1', 'title': 'Original'}),
        },
      },
    );
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _ActionBasket(),
        dataSource: source,
        recordId: 'b1',
        mode: BeakFormMode.read,
        compactActions: true,
        layout: BeakFormLayout(children: [_title.input()]),
      ),
    );
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Pin'), findsNothing);
    final more = find.byWidgetPredicate(
      (widget) => widget is OiButton && widget.semanticLabel == 'More actions',
    );
    expect(more, findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Pin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'page frame shares controls and cancel reloads the persisted record',
    (tester) async {
      late BeakFormSession session;
      final source = FakeDataSource(
        models: const [_ActionBasket(), _Item(), _Line()],
        records: {
          'baskets': {
            'b1': BeakRecord.fromRow({'id': 'b1', 'title': 'Original'}),
          },
        },
      );
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _ActionBasket(),
          dataSource: source,
          recordId: 'b1',
          showActionsWhileEditing: false,
          outlinedCancel: true,
          submitIcon: OiIcons.check,
          mode: BeakFormMode.read,
          layout: BeakFormLayout(
            children: [
              _title.input(),
              const BeakFormActions(names: ['pin']),
            ],
          ),
          onSession: (value) => session = value,
          frameBuilder: (_, _, _, actions, child) => Column(
            children: [
              actions,
              Expanded(child: child),
            ],
          ),
        ),
      );
      expect(find.widgetWithText(OiButton, 'Edit'), findsOneWidget);
      expect(find.text('Pin'), findsOneWidget);
      await tester.tap(find.text('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Pin'), findsOneWidget);
      await tester.tap(find.text('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OiButton, 'Save'), findsOneWidget);
      expect(
        tester.widget<OiButton>(find.widgetWithText(OiButton, 'Save')).icon,
        OiIcons.check,
      );
      expect(
        tester
            .widget<OiButton>(find.widgetWithText(OiButton, 'Cancel'))
            .variant,
        OiButtonVariant.outline,
      );
      expect(find.text('More actions'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'Changed');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(session.root.read(_title), 'Original');
      expect(find.byType(EditableText), findsNothing);
      expect(find.widgetWithText(OiButton, 'Edit'), findsOneWidget);
      expect(find.text('More actions'), findsOneWidget);
      expect(source.updateCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching record identity observes the new session loading signals',
    (tester) async {
      final source = FakeDataSource(
        models: const [_Basket(), _Item(), _Line()],
        records: {
          'baskets': {
            'b1': BeakRecord.fromRow({'id': 'b1', 'title': 'First basket'}),
            'b2': BeakRecord.fromRow({'id': 'b2', 'title': 'Second basket'}),
          },
        },
      );
      final identity = ValueNotifier('b1');
      addTearDown(identity.dispose);
      final layout = BeakFormLayout(children: [_title.input()]);
      await _pump(
        tester,
        ValueListenableBuilder(
          valueListenable: identity,
          builder: (_, id, _) => BeakConfiguredForm(
            model: const _Basket(),
            dataSource: source,
            layout: layout,
            recordId: id,
            mode: BeakFormMode.read,
          ),
        ),
      );
      expect(find.text('First basket'), findsOneWidget);
      identity.value = 'b2';
      await tester.pumpAndSettle();
      expect(find.text('Second basket'), findsOneWidget);
      expect(find.text('First basket'), findsNothing);
      expect(find.text('Loading…'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dense identity-only rows have no empty grid or phantom gap', (
    tester,
  ) async {
    late BeakFormSession session;
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: FakeDataSource(
          models: const [_Basket(), _Line(), _Item()],
          records: {
            'baskets': {
              'basket': BeakRecord.fromRow({'id': 'basket'}),
            },
            'lines': {
              for (var i = 0; i < 3; i++)
                'line-$i': BeakRecord.fromRow({
                  'id': 'line-$i',
                  'basket_id': 'basket',
                  'quantity': 1,
                }),
            },
          },
        ),
        recordId: 'basket',
        mode: BeakFormMode.read,
        layout: BeakFormLayout(
          children: [
            _lines.tableForm(
              presentation: BeakRelationTablePresentation.rows,
              showHeading: false,
              rowPadding: const EdgeInsets.symmetric(vertical: 4),
              showRowDividers: false,
              readOnly: true,
              children: const [],
            ),
          ],
        ),
        onSession: (value) => session = value,
      ),
      width: 480,
    );
    expect(session.root.rows(_lines), hasLength(3));
    for (final row in session.root.rows(_lines)) {
      final container = find.byKey(ValueKey(row.localId));
      expect(
        find.descendant(of: container, matching: find.byType(OiGrid)),
        findsNothing,
      );
      expect(
        tester.getSize(container).height,
        closeTo(tester.getSize(find.text(row.id.toString())).height + 8, 0.1),
      );
      expect(
        tester.widget<Container>(container).decoration,
        const BoxDecoration(),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact rows preserve columns and disclose only present read details',
    (tester) async {
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          mode: BeakFormMode.read,
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              _lines.tableForm(
                presentation: BeakRelationTablePresentation.rows,
                showHeading: false,
                showColumnHeadings: false,
                rowMinHeight: 60,
                minRowWidth: 360,
                rowPadding: const EdgeInsets.symmetric(vertical: 4),
                identityControlHeight: 28,
                columnWidths: const [80],
                rowTemplate: BeakRecordTemplate(
                  textGap: 0,
                  title: BeakValueBinding<String>.computed(
                    dependencies: [_quantity],
                    compute: (row) => 'Line ${row.read(_quantity)}',
                  ),
                ),
                identityChildren: [_selection.inputCombobox(label: 'Size')],
                children: [
                  BeakCalculated(
                    label: 'Line total',
                    textAlign: TextAlign.end,
                    format: BeakValueFormat.currency,
                    value: (row) => (row.read(_quantity) ?? 0) * 10,
                  ),
                ],
                advancedPresentation: BeakAdvancedPresentation.inline,
                advancedReadVisibleIf: (row) => (row.read(_quantity) ?? 0) > 1,
                advancedForm: BeakFormLayout(
                  children: [_quantity.inputNumber(label: 'Advanced quantity')],
                ),
              ),
            ],
          ),
        ),
        width: 480,
      );
      final first = session.root.addRow(_lines)..set(_quantity, 1);
      final second = session.root.addRow(_lines)..set(_quantity, 2);
      first.select(_selection, _available);
      second.select(_selection, _available);
      await tester.pumpAndSettle();
      final firstRow = find.byKey(ValueKey(first.localId));
      final secondRow = find.byKey(ValueKey(second.localId));
      expect(tester.getSize(firstRow).height, 60);
      expect(tester.getSize(secondRow).height, 60);
      expect(find.text('Line total'), findsNothing);
      Finder options(Finder row) => find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is OiButton &&
              (widget.semanticLabel?.startsWith('Options for ') ?? false),
        ),
      );
      expect(options(firstRow), findsNothing);
      expect(options(secondRow), findsOneWidget);
      expect(
        tester.getRect(find.text(r'$10.00')).right,
        tester.getRect(find.text(r'$20.00')).right,
      );
      await tester.tap(options(secondRow), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.text('Advanced quantity'), findsOneWidget);
      await tester.tap(find.text('Edit'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(options(firstRow), findsOneWidget);
      final compactInput = find.descendant(
        of: firstRow,
        matching: find.byType(OiComboBox<BeakRecord>),
      );
      expect(tester.getSize(compactInput.first).height, 28);
      expect(session.root.rows(_lines).length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact rows reuse the graph and remove locally without card wrappers',
    (tester) async {
      late BeakFormSession session;
      final source = _source();
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          layout: BeakFormLayout(
            children: [
              _lines.tableForm(
                presentation: BeakRelationTablePresentation.rows,
                identityFlex: 4,
                children: [_quantity.inputNumber()],
                advancedForm: BeakFormLayout(
                  children: [_selection.inputCombobox()],
                ),
              ),
            ],
          ),
          onSession: (value) => session = value,
        ),
        width: 800,
      );
      final row = session.root.addRow(_lines);
      row.select(_selection, _available);
      await tester.pumpAndSettle();
      final compactRow = find.byKey(ValueKey(row.localId));
      expect(compactRow, findsOneWidget);
      expect(
        find.descendant(of: compactRow, matching: find.byType(OiCard)),
        findsNothing,
      );
      expect(tester.getSize(compactRow).height, lessThan(115));
      expect(
        tester
            .getSize(
              find.descendant(
                of: compactRow,
                matching: find.byType(OiNumberInput),
              ),
            )
            .width,
        lessThan(170),
      );
      final remove = find.byWidgetPredicate(
        (widget) =>
            widget is OiButton &&
            (widget.semanticLabel?.startsWith('Remove ') ?? false),
      );
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(session.root.rows(_lines), isEmpty);
      expect(source.deleteCalls, isEmpty);
      expect(source.createCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed draft storage offers discard and never claims it is saved',
    (tester) async {
      var closed = false;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          drafts: const BeakFormDrafts(
            store: _FailingDraftStore(),
            key: 'new',
            context: 'demo',
          ),
          header: const BeakFormHeader(title: 'New basket'),
          layout: BeakFormLayout(children: [_title.input()]),
          onClose: () => closed = true,
        ),
      );
      await tester.enterText(find.byType(EditableText), 'Unsaved');
      await tester.tap(find.text('Save as draft'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be stored'), findsOneWidget);
      expect(find.textContaining('Saved at'), findsNothing);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is OiButton && widget.semanticLabel == 'Close',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Discard changes'), findsOneWidget);
      expect(
        find.textContaining('stored locally and can be resumed'),
        findsNothing,
      );
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Unsaved',
      );
    },
  );
  testWidgets(
    'catalog facets and bounded group pages preserve staged choices',
    (tester) async {
      final source = FakeDataSource(
        models: const [_Basket(), _Line(), _Item()],
        records: {
          'catalog': {
            'coffee': BeakRecord.fromRow({
              'id': 'coffee',
              'name': 'Coffee',
              'group': 'drinks',
            }),
            'tea': BeakRecord.fromRow({
              'id': 'tea',
              'name': 'Tea',
              'group': 'drinks',
            }),
            'cake': BeakRecord.fromRow({
              'id': 'cake',
              'name': 'Cake',
              'group': 'food',
            }),
          },
        },
      );
      const group = BeakScalarField<String>(
        model: _Item(),
        column: _Item.group,
      );
      late BeakFormSession session;
      final table = _lines.tableForm(
        children: const [],
        catalog: BeakRelationCatalog(
          selection: _selection,
          template: _template,
          groupBy: group,
          variantLabel: _name,
          quantity: _quantity,
          maxOptions: 10,
          pageSize: 1,
          tabs: [
            const BeakCatalogFilter(label: 'All'),
            BeakCatalogFilter(label: 'Food', filter: group.eq('food')),
          ],
          filters: [
            BeakCatalogFilter(label: 'Coffee only', filter: _name.eq('Coffee')),
          ],
        ),
      );
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          layout: BeakFormLayout(children: [table]),
          onSession: (value) => session = value,
        ),
      );
      Finder increment(String name) => find.byWidgetPredicate(
        (widget) =>
            widget is OiButton && widget.semanticLabel == 'Increase $name',
      );
      expect(increment('Coffee'), findsOneWidget);
      await tester.tap(increment('Coffee'));
      await tester.pumpAndSettle();
      final row = session.root.rows(_lines).single;
      tester.widget<OiPagination>(find.byType(OiPagination)).onPageChange!(1);
      await tester.pumpAndSettle();
      expect(increment('Cake'), findsOneWidget);
      expect(increment('Coffee'), findsNothing);
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(increment('Cake'), findsOneWidget);
      expect(find.byType(OiPagination), findsNothing);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee only'));
      await tester.pumpAndSettle();
      expect(increment('Coffee'), findsOneWidget);
      expect(increment('Cake'), findsNothing);
      expect(session.root.rows(_lines).single, same(row));
      expect(row.read(_quantity), 1);
      expect(source.createCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog hides old choices as soon as a new search is typed', (
    tester,
  ) async {
    late BeakFormSession session;
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _source(),
        layout: BeakFormLayout(
          children: [
            _lines.tableForm(
              children: const [],
              catalog: BeakRelationCatalog(
                selection: _selection,
                template: _template,
                quantity: _quantity,
                groupBy: _name,
              ),
            ),
          ],
        ),
        onSession: (value) => session = value,
      ),
    );
    Finder increase(String name) => find.byWidgetPredicate(
      (widget) =>
          widget is OiButton && widget.semanticLabel == 'Increase $name',
    );
    expect(increase('Coffee'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Sold');
    await tester.pump();
    expect(increase('Coffee'), findsNothing);
    expect(find.byType(OiProgress), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pumpAndSettle();
    expect(increase('Sold out'), findsOneWidget);
    await tester.tap(increase('Sold out'));
    await tester.pumpAndSettle();
    expect(
      session.root.rows(_lines).single.read(_selection)?['id']?.raw,
      'sold',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing an owned row preserves the active form tab', (
    tester,
  ) async {
    const lines = BeakToManyField(
      model: _Basket(),
      relation: _Basket.lines,
      target: _ValidatedLine(),
    );
    const lineName = BeakScalarField<String>(
      model: _ValidatedLine(),
      column: _ValidatedLine.name,
    );
    late BeakFormSession session;
    await _pump(
      tester,
      BeakConfiguredForm(
        model: const _Basket(),
        dataSource: _CheckingSource(),
        layout: BeakTabs(
          tabs: [
            BeakTab(title: 'Details', children: [_title.inputText()]),
            BeakTab(
              title: 'Lines',
              children: [
                lines.tableForm(children: [lineName.inputText()]),
              ],
            ),
          ],
        ),
        onSession: (value) => session = value,
      ),
    );
    session.root.addRow(lines);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lines'));
    await tester.pumpAndSettle();
    expect(tester.widget<OiTabs>(find.byType(OiTabs)).selectedIndex, 1);
    await tester.enterText(find.byType(EditableText), 'Large');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<OiTabs>(find.byType(OiTabs)).selectedIndex, 1);
    expect(session.root.rows(lines).single.read(lineName), 'Large');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bounded catalogs reject incomplete groups with a useful refinement message',
    (tester) async {
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          layout: BeakFormLayout(
            children: [
              _lines.tableForm(
                children: const [],
                catalog: BeakRelationCatalog(
                  selection: _selection,
                  template: _template,
                  groupBy: _name,
                  maxOptions: 1,
                  pageSize: 1,
                ),
              ),
            ],
          ),
        ),
      );
      expect(
        find.text('Too many catalog options. Refine the search or filters.'),
        findsOneWidget,
      );
      expect(find.text('Retry options'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);
    },
  );

  testWidgets(
    'read presentation uses configured choice labels and relationship templates',
    (tester) async {
      final source = _source();
      source.store.seed(const _Basket(), [
        BeakRecord.fromRow({
          'id': 'b1',
          'title': 'monthly',
          'choice_id': 'coffee',
        }),
      ]);
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: source,
          recordId: 'b1',
          mode: BeakFormMode.read,
          layout: BeakFormLayout(
            children: [
              _title.inputRadio(
                options: (_) => const [
                  BeakInputOption('monthly', 'Monthly invoice'),
                ],
              ),
              _choice.inputCombobox(template: _template),
            ],
          ),
        ),
      );
      expect(find.text('Monthly invoice'), findsOneWidget);
      expect(find.text('monthly'), findsNothing);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.byType(OiAvatar), findsOneWidget);
    },
  );

  testWidgets(
    'placeholder follows a declarative prerequisite and section divider',
    (tester) async {
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: _source(),
          layout: BeakFormLayout(
            children: [
              _title.input(),
              BeakSection(
                title: 'Profile',
                divider: true,
                description: 'Choose the customer first.',
                descriptionStyle: const TextStyle(fontSize: 16, height: 1.5),
                children: [
                  BeakFormPlaceholder(
                    label: 'Select a customer',
                    height: 100,
                    visibleIf: (state) =>
                        state.read(_title) == null ||
                        state.read(_title)!.isEmpty,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.byType(OiHatchPlaceholder), findsOneWidget);
      expect(
        tester.getSize(find.byType(OiHatchPlaceholder)).height,
        greaterThanOrEqualTo(100),
      );
      expect(find.byType(OiDivider), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Selected');
      await tester.pumpAndSettle();
      expect(find.byType(OiHatchPlaceholder), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'datetime inputs use the panel clock and preserve the underlying instant',
    (tester) async {
      const instant = BeakScalarField<DateTime>(
        model: _Basket(),
        column: BeakDateTimeColumn(key: 'scheduled', label: 'Scheduled'),
      );
      final original = DateTime.utc(2026, 9, 27, 7, 42);
      late BeakFormSession session;
      final source = _source();
      source.store.seed(const _Basket(), [
        BeakRecord.fromRow({
          'id': 'b1',
          'title': 'Before',
          'scheduled': original,
        }),
      ]);
      await _pump(
        tester,
        BeakFormattingScope(
          formatting: const BeakFormatting(timeZoneOffsetMinutes: 120),
          child: BeakConfiguredForm(
            model: const _Basket(),
            dataSource: source,
            recordId: 'b1',
            layout: BeakFormLayout(children: [instant.input()]),
            onSession: (value) => session = value,
          ),
        ),
      );
      final editor = tester.widget<OiDateTimeInput>(
        find.byType(OiDateTimeInput),
      );
      expect(editor.value?.hour, 9);
      expect(editor.value?.minute, 42);
      editor.onChanged!(DateTime(2026, 9, 27, 9, 42));
      await tester.pumpAndSettle();
      expect(session.root.read(instant), original);
      editor.onChanged!(DateTime.utc(2026, 9, 27, 10, 15));
      await tester.pumpAndSettle();
      expect(session.root.read(instant), DateTime.utc(2026, 9, 27, 8, 15));
      expect(tester.takeException(), isNull);
    },
  );
}

base class _Basket extends BeakModel {
  const _Basket();
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    rules: [BeakRequired()],
  );
  static const choice = BeakBelongsTo(
    key: 'choice',
    label: 'Choice',
    relatedTable: 'catalog',
    foreignKey: 'choice_id',
    displayColumnKey: 'name',
    searchColumnKeys: ['name'],
  );
  static const lines = BeakHasMany(
    key: 'lines',
    label: 'Lines',
    relatedTable: 'lines',
    foreignKey: 'basket_id',
    displayColumnKey: 'id',
    owned: true,
  );
  @override
  String get table => 'baskets';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    title,
    BeakStringColumn(key: 'choice_id', label: 'Choice'),
    BeakDateTimeColumn(key: 'scheduled', label: 'Scheduled'),
  ];
  @override
  List<BeakRelationship> get relationships => const [choice, lines];
  @override
  List<BeakModel> get relatedModels => const [_Item(), _Line()];
}

final class _Item extends BeakModel {
  const _Item();
  static const stockLines = BeakHasMany(
    key: 'stockLines',
    label: 'Stock lines',
    relatedTable: 'lines',
    foreignKey: 'item_id',
    displayColumnKey: 'id',
  );
  @override
  List<BeakRelationship> get relationships => const [stockLines];
  @override
  List<BeakModel> get relatedModels => const [_Line()];
  static const group = BeakStringColumn(key: 'group', label: 'Group');
  static const price = BeakIntColumn(key: 'price', label: 'Price');
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
  );
  @override
  String get table => 'catalog';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    name,
    group,
    price,
  ];
}

final class _Line extends BeakModel {
  const _Line();
  static const quantity = BeakIntColumn(
    key: 'quantity',
    label: 'Quantity',
    defaultValue: 1,
  );
  static const item = BeakBelongsTo(
    key: 'item',
    label: 'Product',
    relatedTable: 'catalog',
    foreignKey: 'item_id',
    displayColumnKey: 'name',
    searchColumnKeys: ['name'],
  );
  @override
  String get table => 'lines';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'basket_id', label: 'Basket'),
    BeakStringColumn(key: 'item_id', label: 'Product'),
    quantity,
  ];
  @override
  List<BeakRelationship> get relationships => const [item];
  @override
  List<BeakModel> get relatedModels => const [_Item()];
}

final class _PlaceBasket extends _Basket {
  const _PlaceBasket();
  @override
  BeakModelBehavior get behavior => const BeakModelBehavior(
    actions: [
      BeakModelAction(name: 'place', label: 'Place', allowOnCreate: true),
    ],
  );
}

final class _CommandSource extends FakeDataSource
    implements BeakCommitDataSource {
  _CommandSource() : super(models: const [_PlaceBasket(), _Item(), _Line()]);
  BeakSavePlan? plan;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true);
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    this.plan = plan;
    return BeakSaveResult(
      saveId: plan.saveId,
      mode: BeakSaveMode.atomic,
      outcomes: [
        for (final operation in plan.operations)
          BeakOperationResult(
            id: operation.id,
            status: BeakWriteOutcome.applied,
            resolvedId: 'b1',
            record: BeakRecord.fromRow({
              'id': 'b1',
              'title': 'Confirmed basket',
            }),
          ),
      ],
    );
  }

  @override
  Future<BeakSaveResult> recover(String saveId) => throw UnimplementedError();
}

final class _SuggestedBasket extends _Basket {
  const _SuggestedBasket();
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.suggested(
        field: const BeakScalarField<String>(
          model: _Basket(),
          column: BeakStringColumn(key: 'choice_id', label: 'Choice'),
        ),
        dependencies: [_title],
        resolve: (values) => values.read(_title),
      ),
    ],
  );
}

final class _DeferredSelectionSource extends FakeDataSource {
  _DeferredSelectionSource()
    : super(
        models: const [_SuggestedBasket(), _Item(), _Line()],
        records: {
          'catalog': {'coffee': _available, 'sold': _blocked},
        },
      );
  final pending = <String, (BeakQuerySpec, Completer<BeakPage<BeakRecord>>)>{};
  final resolved = <String>{};
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    if (spec.table == 'catalog' && spec.filter is BeakFieldFilter) {
      final value = (spec.filter! as BeakFieldFilter).value;
      if (resolved.contains(value.raw)) return super.query(spec);
      final completer = Completer<BeakPage<BeakRecord>>();
      pending[value.raw! as String] = (spec, completer);
      return completer.future;
    }
    return super.query(spec);
  }

  Future<void> resolve(String id) async {
    final (spec, completer) = pending.remove(id)!;
    resolved.add(id);
    completer.complete(await super.query(spec));
  }
}

final class _ActionBasket extends _Basket {
  const _ActionBasket();
  @override
  BeakModelBehavior get behavior => const BeakModelBehavior(
    actions: [
      BeakModelAction(name: 'pin', label: 'Pin'),
      BeakModelAction(name: 'archive', label: 'Archive'),
    ],
  );
}

final class _FailingDraftStore implements BeakDraftStore {
  const _FailingDraftStore();
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String document) async =>
      throw StateError('Storage unavailable');
  @override
  Future<void> remove(String key) async {}
}

final class _ValidatedLine extends BeakModel {
  const _ValidatedLine();
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    unique: true,
  );
  @override
  String get displayColumnKey => 'name';
  @override
  String get table => 'lines';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'basket_id', label: 'Basket'),
    name,
  ];
}

final class _CheckingSource extends FakeDataSource
    implements BeakValidationDataSource {
  _CheckingSource()
    : super(models: const [_Basket(), _ValidatedLine(), _Item()]);
  @override
  Future<BeakValidationReport> validateRecord(
    BeakValidationRequest request,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return const BeakValidationReport();
  }
}

final class _CodeLookupSource extends FakeDataSource {
  _CodeLookupSource()
    : super(
        models: const [_Basket(), _Item(), _Line()],
        records: {
          'catalog': {'coffee': _available, 'sold': _blocked},
        },
      );
  (BeakQuerySpec, Completer<BeakPage<BeakRecord>>)? pending;
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    if (spec.table != 'catalog') return super.query(spec);
    final completer = Completer<BeakPage<BeakRecord>>();
    pending = (spec, completer);
    return completer.future;
  }

  Future<void> resolve() async {
    final (spec, completer) = pending!;
    pending = null;
    completer.complete(await super.query(spec));
  }
}

final class _CatalogWaitSource extends FakeDataSource {
  _CatalogWaitSource()
    : super(
        models: const [_Basket(), _Line(), _Item()],
        records: {
          'catalog': {
            'small': BeakRecord.fromRow({
              'id': 'small',
              'name': 'Small',
              'group': 'drink',
            }),
            'large': BeakRecord.fromRow({
              'id': 'large',
              'name': 'Large',
              'group': 'drink',
            }),
          },
        },
      );
  bool pause = false;
  (BeakQuerySpec, Completer<BeakPage<BeakRecord>>)? pending;
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    if (pause && spec.table == 'catalog') {
      pause = false;
      final completion = Completer<BeakPage<BeakRecord>>();
      pending = (spec, completion);
      return completion.future;
    }
    return super.query(spec);
  }

  Future<void> release() async {
    final (spec, completion) = pending!;
    pending = null;
    completion.complete(await super.query(spec));
  }
}
