import 'dart:async';
import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/form/beak_object_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _model = _Fields();
const _flag = BeakScalarField<bool>(model: _model, column: _Fields.flag);
const _count = BeakScalarField<int>(model: _model, column: _Fields.quantity);
const _json = BeakScalarField<String>(model: _model, column: _Fields.json);

void main() {
  Future<void> showForm(
    WidgetTester tester,
    BeakFormLayout layout,
    void Function(BeakFormSession) onSession, {
    BeakModel model = const _SemanticFields(),
    OiThemeData? theme,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: theme ?? OiThemeData.light(),
        home: BeakFormattingScope(
          formatting: const BeakFormatting(locale: 'de_AT', currency: 'EUR'),
          child: BeakConfiguredForm(
            model: model,
            dataSource: FakeDataSource(models: [model]),
            layout: layout,
            onSession: onSession,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'calendar shortcuts share typed state and leave calendar dates unrestricted',
    (tester) async {
      const date = BeakScalarField<BeakDate>(
        model: _SemanticFields(),
        column: _SemanticFields.date,
      );
      late BeakFormSession session;
      await showForm(
        tester,
        BeakFormLayout(
          children: [
            date.inputDate(
              shortcuts: (_) => const [
                BeakInputOption(BeakDate(2026, 9, 29), 'Tomorrow'),
                BeakInputOption(BeakDate(2026, 9, 28), 'Today', enabled: false),
              ],
            ),
          ],
        ),
        (value) => session = value,
      );
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      expect(session.root.read(date), const BeakDate(2026, 9, 29));
      await tester.tap(find.text('Today'));
      expect(session.root.read(date), const BeakDate(2026, 9, 29));
      final picker = tester.widget<OiDateInput>(find.byType(OiDateInput));
      picker.onChanged!(DateTime(2026, 10, 8));
      await tester.pumpAndSettle();
      expect(session.root.read(date), const BeakDate(2026, 10, 8));
      expect(await session.root.validate(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quantity stepper respects model bounds and binds the same draft',
    (tester) async {
      late BeakFormSession session;
      await showForm(
        tester,
        BeakFormLayout(children: [_count.inputQuantity()]),
        (value) => session = value,
        model: _model,
      );
      final control = tester.widget<OiQuantitySelector>(
        find.byType(OiQuantitySelector),
      );
      expect(control.min, 1);
      expect(control.max, 9);
      expect(session.root.read(_count), isNull);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is OiButton && widget.semanticLabel == 'Increase quantity',
        ),
      );
      await tester.pumpAndSettle();
      expect(session.root.read(_count), 1);
      session.root.set(_count, 9);
      await tester.pumpAndSettle();
      final increase = tester.widget<OiButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is OiButton && widget.semanticLabel == 'Increase quantity',
        ),
      );
      expect(increase.onTap, isNull);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is OiButton && widget.semanticLabel == 'Decrease quantity',
        ),
      );
      await tester.pumpAndSettle();
      expect(session.root.read(_count), 8);
      expect(await session.validate(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('multiline padding is scoped to its placement', (tester) async {
    const field = BeakScalarField<String>(
      model: _Fields(),
      column: _Fields.note,
    );
    final theme = OiThemeData.light().copyWith(
      components: const OiComponentThemes(
        textInput: OiTextInputThemeData(
          textStyle: TextStyle(fontSize: 14, height: 10 / 7),
          multilineContentPadding: EdgeInsets.all(12),
        ),
      ),
    );
    await showForm(
      tester,
      BeakFormLayout(
        children: [
          field.inputText(
            label: 'Compact',
            maxLines: 2,
            showCounter: false,
            multilineContentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
          ),
        ],
      ),
      (_) {},
      model: _model,
      theme: theme,
    );
    final compact = find.byType(OiTextInput).evaluate().single;
    expect(
      OiTheme.of(compact).components.textInput!.multilineContentPadding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    );
    final compactHeight = (compact.renderObject! as RenderBox).size.height;
    await showForm(
      tester,
      BeakFormLayout(
        children: [
          field.inputText(label: 'Default', maxLines: 2, showCounter: false),
        ],
      ),
      (_) {},
      model: _model,
      theme: theme,
    );
    final ordinary = find.byType(OiTextInput).evaluate().single;
    expect(
      OiTheme.of(ordinary).components.textInput!.multilineContentPadding,
      const EdgeInsets.all(12),
    );
    expect(
      (ordinary.renderObject! as RenderBox).size.height - compactHeight,
      6,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiline string placement binds ordinary string columns', (
    tester,
  ) async {
    const field = BeakScalarField<String>(
      model: _Fields(),
      column: _Fields.note,
    );
    late BeakFormSession session;
    await showForm(
      tester,
      BeakFormLayout(children: [field.inputText(maxLines: 3)]),
      (value) => session = value,
      model: _model,
    );
    final input = tester.widget<OiTextInput>(find.byType(OiTextInput));
    expect(input.minLines, 3);
    expect(input.maxLines, 3);
    expect(input.keyboardType, TextInputType.multiline);
    expect(input.textInputAction, TextInputAction.newline);
    expect(input.maxLength, 40);
    expect(input.showCounter, isTrue);
    await tester.enterText(
      find.byType(EditableText),
      'Reception\nCall on arrival',
    );
    expect(session.root.read(field), 'Reception\nCall on arrival');
    expect(await session.root.validate(), isTrue);
  });

  testWidgets('read mode presents embedded schema fields with their labels', (
    tester,
  ) async {
    const details = BeakScalarField<BeakJsonObject>(
      model: _SemanticFields(),
      column: _SemanticFields.details,
    );
    final source = FakeDataSource(
      models: const [_SemanticFields()],
      records: {
        'semantic_values': {
          'one': const BeakRecord(
            values: {
              'id': BeakStringValue('one'),
              'details': BeakStringValue('{"city":"Vienna","postal":"1020"}'),
            },
          ),
        },
      },
    );
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const _SemanticFields(),
          dataSource: source,
          recordId: 'one',
          mode: BeakFormMode.read,
          layout: BeakFormLayout(children: [details.input()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Vienna'), findsOneWidget);
    expect(find.text('Postal code'), findsOneWidget);
    expect(find.text('1020'), findsOneWidget);
    expect(find.text('{"city":"Vienna","postal":"1020"}'), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('duration and percentage editor text trims insignificant zeros', (
    tester,
  ) async {
    late BeakFormSession session;
    const elapsed = BeakScalarField<Duration>(
      model: _SemanticFields(),
      column: _SemanticFields.elapsed,
    );
    const percent = BeakScalarField<double>(
      model: _SemanticFields(),
      column: _SemanticFields.percent,
    );
    await showForm(
      tester,
      BeakFormLayout(children: [elapsed.input(), percent.input()]),
      (value) => session = value,
    );
    session.root.set(elapsed, const Duration(hours: 24));
    session.root.set(percent, 0.025);
    await tester.pumpAndSettle();
    final inputs = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(inputs[0].controller.text, '24:00:00');
    expect(inputs[1].controller.text, '2,5');
    expect(session.root.read(percent), 0.025);
    expect(await session.root.validate(), isTrue);
  });

  testWidgets('nested read properties use shared formatting and empty values', (
    tester,
  ) async {
    const schema = BeakObjectSchema(
      columns: [
        BeakJsonColumn(
          key: 'nested',
          label: 'Delivery',
          semantic: BeakSemantic.object(
            BeakObjectSchema(
              columns: [
                BeakIntColumn(
                  key: 'fee',
                  label: 'Fee',
                  semantic: BeakSemantic.money(currency: 'EUR'),
                ),
                BeakStringColumn(key: 'note', label: 'Note'),
              ],
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: const BeakFormattingScope(
          formatting: BeakFormatting(
            locale: 'de_AT',
            emptyValue: 'Not provided',
          ),
          child: BeakObjectView(
            schema: schema,
            value: BeakJsonObject({
              'nested': BeakJsonObject({'fee': BeakJsonNumber(1250)}),
            }),
          ),
        ),
      ),
    );
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Fee'), findsOneWidget);
    expect(find.textContaining('12,50'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Not provided'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('exact money parses localized text and blocks excess scale', (
    tester,
  ) async {
    late BeakFormSession session;
    const amount = BeakScalarField<BeakDecimal>(
      model: _SemanticFields(),
      column: _SemanticFields.money,
    );
    await showForm(
      tester,
      BeakFormLayout(children: [amount.inputCurrency()]),
      (value) => session = value,
    );
    expect(find.text('KWD'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '123,456');
    expect(session.root.read(amount), const BeakDecimal(123456, scale: 3));
    expect(await session.root.validate(), isTrue);
    await tester.enterText(find.byType(EditableText), '123,4567');
    expect(await session.root.validate(), isFalse);
    expect(session.root.read(amount), const BeakDecimal(123456, scale: 3));
    expect(session.isDirty, isTrue);
    await tester.enterText(find.byType(EditableText), '');
    expect(await session.root.validate(), isTrue);
    expect(session.root.read(amount), isNull);
  });

  testWidgets(
    'time and duration preserve seconds, microseconds and long hours',
    (tester) async {
      late BeakFormSession session;
      const time = BeakScalarField<BeakTime>(
        model: _SemanticFields(),
        column: _SemanticFields.time,
      );
      const elapsed = BeakScalarField<Duration>(
        model: _SemanticFields(),
        column: _SemanticFields.elapsed,
      );
      await showForm(
        tester,
        BeakFormLayout(children: [time.inputTime(), elapsed.inputDuration()]),
        (value) => session = value,
      );
      await tester.enterText(
        find.byType(EditableText).at(0),
        '12:34:56.000001',
      );
      await tester.enterText(
        find.byType(EditableText).at(1),
        '27:15:02.000003',
      );
      expect(
        session.root.read(time),
        const BeakTime(12, 34, second: 56, microsecond: 1),
      );
      expect(
        session.root.read(elapsed),
        const Duration(hours: 27, minutes: 15, seconds: 2, microseconds: 3),
      );
      expect(await session.root.validate(), isTrue);
      await tester.enterText(find.byType(EditableText).at(1), '27:99');
      expect(await session.root.validate(), isFalse);
    },
  );

  testWidgets('typed checkboxes reject a selection removed by a dependency', (
    tester,
  ) async {
    late BeakFormSession session;
    const tags = BeakScalarField<List<String>>(
      model: _SemanticFields(),
      column: _SemanticFields.tags,
    );
    const date = BeakScalarField<BeakDate>(
      model: _SemanticFields(),
      column: _SemanticFields.date,
    );
    await showForm(
      tester,
      BeakFormLayout(
        children: [
          date.inputDate(),
          tags.inputCheckboxGroup(
            options: (state) => [
              const BeakInputOption('one', 'One'),
              if (state.read(date) == null) const BeakInputOption('two', 'Two'),
            ],
          ),
        ],
      ),
      (value) => session = value,
    );
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(session.root.read(tags), ['two']);
    expect(await session.root.validate(), isTrue);
    tester.widget<OiDateInput>(find.byType(OiDateInput)).onChanged!(
      DateTime(2028, 2, 29),
    );
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsNothing);
    expect(session.root.read(tags), ['two']);
    expect(await session.root.validate(), isFalse);
    expect(
      session.root.errors[tags.key],
      contains('Choose an available option.'),
    );
  });

  testWidgets(
    'embedded object editor validates children and preserves nested JSON',
    (tester) async {
      late BeakFormSession session;
      const details = BeakScalarField<BeakJsonObject>(
        model: _SemanticFields(),
        column: _SemanticFields.details,
      );
      await showForm(
        tester,
        BeakFormLayout(children: [details.input()]),
        (value) => session = value,
      );
      await tester.enterText(find.byType(EditableText).first, 'Vienna');
      await tester.enterText(find.byType(EditableText).last, '');
      expect(await session.root.validate(), isFalse);
      await tester.enterText(find.byType(EditableText).last, '1020');
      expect(await session.root.validate(), isTrue);
      final raw = session.root.buildRecord()[details.key]?.raw;
      expect(raw, '{"city":"Vienna","postal":"1020"}');
    },
  );

  testWidgets(
    'attribute type changes adapt editor while retaining canonical strings',
    (tester) async {
      late BeakFormSession session;
      const type = BeakScalarField<String>(
        model: _Attributes(),
        column: _Attributes.type,
      );
      const value = BeakScalarField<String>(
        model: _Attributes(),
        column: _Attributes.value,
      );
      await showForm(
        tester,
        BeakFormLayout(
          children: [
            type.input(),
            value.inputAttribute(
              type: (state) => switch (state.read(type)) {
                'number' => BeakAttributeType.number,
                'boolean' => BeakAttributeType.boolean,
                'choice' => BeakAttributeType.choice,
                _ => BeakAttributeType.text,
              },
              options: (_) => const [BeakInputOption('small', 'Small')],
            ),
          ],
        ),
        (result) => session = result,
        model: const _Attributes(),
      );
      session.root.set(type, 'number');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '1,25');
      expect(session.root.read(value), '1.25');
      expect(await session.root.validate(), isTrue);
      session.root.set(type, 'boolean');
      await tester.pumpAndSettle();
      expect(await session.root.validate(), isFalse);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(session.root.read(value), 'true');
      expect(await session.root.validate(), isTrue);
      session.root.set(type, 'choice');
      await tester.pumpAndSettle();
      expect(await session.root.validate(), isFalse);
    },
  );

  testWidgets('debounced preflight is coalesced with Save and Save waits', (
    tester,
  ) async {
    final source = _ValidationSource();
    late BeakFormSession session;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const _Rules(),
          dataSource: source,
          onSession: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    session.root.set(_Rules.value, 'new');
    session.root.set(_Rules.confirmation, 'new');
    await tester.pump(const Duration(milliseconds: 349));
    expect(source.calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(source.calls, 1);
    expect(session.root.validating, isTrue);
    final save = session.save();
    await tester.pump();
    expect(session.submitting.value, isTrue);
    expect(source.calls, 1);
    expect(source.store.rowsOf('rules'), isEmpty);
    source.first.complete(const BeakValidationReport());
    await tester.pumpAndSettle();
    expect((await save)?.complete, isTrue);
    expect(source.store.rowsOf('rules'), hasLength(1));
  });

  testWidgets(
    'primitive arrays keep integer elements and enforce collection limits',
    (tester) async {
      late BeakFormSession session;
      const weights = BeakScalarField<List<int>>(
        model: _SemanticFields(),
        column: _SemanticFields.weights,
      );
      await showForm(
        tester,
        BeakFormLayout(children: [weights.input()]),
        (value) => session = value,
      );
      session.root.set(weights, <int>[]);
      expect(await session.root.validate(), isFalse);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      tester.widget<OiNumberInput>(find.byType(OiNumberInput)).onChanged!(12);
      await tester.pumpAndSettle();
      expect(session.root.read(weights), <int>[12]);
      expect(await session.root.validate(), isTrue);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      tester.widget<OiNumberInput>(find.byType(OiNumberInput).last).onChanged!(
        12,
      );
      expect(await session.root.validate(), isFalse);
    },
  );

  testWidgets('tags and radio choices persist typed values automatically', (
    tester,
  ) async {
    late BeakFormSession session;
    const tags = BeakScalarField<List<String>>(
      model: _SemanticFields(),
      column: _SemanticFields.tags,
    );
    await showForm(
      tester,
      BeakFormLayout(children: [tags.inputTags()]),
      (value) => session = value,
    );
    tester.widget<OiTagInput>(find.byType(OiTagInput)).onChanged!([
      'one',
      'two',
    ]);
    await tester.pumpAndSettle();
    expect(session.root.read(tags), ['one', 'two']);
    expect(session.root.buildRecord()[tags.key]?.raw, '["one","two"]');
    const type = BeakScalarField<String>(
      model: _Attributes(),
      column: _Attributes.type,
    );
    await showForm(
      tester,
      BeakFormLayout(
        children: [
          type.inputRadio(
            options: (_) => const [
              BeakInputOption('number', 'Numeric'),
              BeakInputOption('text', 'Text'),
            ],
          ),
        ],
      ),
      (value) => session = value,
      model: const _Attributes(),
    );
    await tester.tap(find.text('Numeric'));
    await tester.pumpAndSettle();
    expect(session.root.read(type), 'number');
  });

  testWidgets('choice cards share a row and preserve typed selection', (
    tester,
  ) async {
    const type = BeakScalarField<String>(
      model: _Attributes(),
      column: _Attributes.type,
    );
    late BeakFormSession session;
    await showForm(
      tester,
      BeakFormLayout(
        children: [
          type.inputRadio(
            cards: true,
            minCardWidth: 180,
            options: (_) => const [
              BeakInputOption(
                'number',
                'Numeric',
                description: 'Counted values',
              ),
              BeakInputOption('text', 'Text', description: 'Written values'),
              BeakInputOption(
                'other',
                'Other',
                description: 'Additional values',
              ),
            ],
          ),
        ],
      ),
      (value) => session = value,
      model: const _Attributes(),
    );
    expect(
      tester.getTopLeft(find.text('Numeric')).dy,
      tester.getTopLeft(find.text('Other')).dy,
    );
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    expect(session.root.read(type), 'text');
    expect(tester.takeException(), isNull);
  });

  test(
    'async validation failure blocks saving and disposal ignores late results',
    () async {
      final failing = _FailingValidationSource();
      final session = BeakFormSession(
        model: const _Rules(),
        dataSource: failing,
      );
      session.root.set(_Rules.value, 'value');
      session.root.set(_Rules.confirmation, 'value');
      expect(await session.save(), isNull);
      expect(session.submitting.value, isFalse);
      expect(
        session.root.errors.values.expand((values) => values),
        contains('Validation service unavailable.'),
      );
      expect(failing.store.rowsOf('rules'), isEmpty);
      session.dispose();
      final delayed = _ValidationSource();
      final other = BeakFormSession(model: const _Rules(), dataSource: delayed);
      other.root.set(_Rules.value, 'value');
      other.root.set(_Rules.confirmation, 'value');
      final pending = other.root.validate();
      await Future<void>.delayed(Duration.zero);
      other.dispose();
      delayed.first.complete(const BeakValidationReport());
      expect(await pending, isFalse);
    },
  );

  test(
    'malformed stored semantic values remain blocked until corrected',
    () async {
      final controller = BeakFormController(model: const _SemanticFields());
      addTearDown(controller.dispose);
      controller.prefill(
        const BeakRecord(values: {'date': BeakStringValue('2028-02-31')}),
      );
      expect(controller.inputErrors, contains(_SemanticFields.date.key));
      expect(controller.isDirty, isFalse);
      expect(await controller.validate(), isFalse);
      controller.setValue(_SemanticFields.date, const BeakDate(2028, 2, 29));
      expect(controller.inputErrors, isEmpty);
    },
  );

  test('date range validates order without manual form state', () async {
    const first = BeakScalarField<BeakDate>(
      model: _SemanticFields(),
      column: _SemanticFields.date,
    );
    const last = BeakScalarField<BeakDate>(
      model: _SemanticFields(),
      column: _SemanticFields.end,
    );
    final session = BeakFormSession(
      model: const _SemanticFields(),
      dataSource: FakeDataSource(),
      layout: first.inputDateRange(end: last),
    );
    addTearDown(session.dispose);
    session.root.set(first, const BeakDate(2028, 3, 1));
    session.root.set(last, const BeakDate(2028, 2, 29));
    expect(await session.root.validate(), isFalse);
    session.root.set(last, const BeakDate(2028, 3, 1));
    expect(await session.root.validate(), isTrue);
  });

  test(
    'shared cross-field and asynchronous rules gate the current draft',
    () async {
      final source = _ValidationSource();
      final session = BeakFormSession(
        model: const _Rules(),
        dataSource: source,
      );
      addTearDown(session.dispose);
      session.root.set(_Rules.value, 'old');
      session.root.set(_Rules.confirmation, 'different');
      expect(await session.root.validate(), isFalse);
      expect(
        session.root.errors[_Rules.confirmation.key],
        contains('Must match Value.'),
      );
      session.root.set(_Rules.confirmation, 'old');
      final validation = session.root.validate();
      await Future<void>.delayed(Duration.zero);
      session.root.set(_Rules.value, 'new');
      session.root.set(_Rules.confirmation, 'new');
      source.first.complete(
        const BeakValidationReport(
          fieldErrors: {
            'value': ['Already used.'],
          },
        ),
      );
      expect(await validation, isTrue);
      expect(source.calls, 2);
      expect(source.last!.record['value']?.raw, 'new');
      expect(session.root.errors, isEmpty);
    },
  );

  test(
    'semantic controller round trips exact values without display rounding',
    () {
      final controller = BeakFormController(model: const _SemanticFields());
      addTearDown(controller.dispose);
      controller.prefill(
        const BeakRecord(
          values: {
            'date': BeakStringValue('2028-02-29'),
            'time': BeakStringValue('14:35:12'),
            'money': BeakIntValue(1234567890123),
            'elapsed': BeakIntValue(3600000001),
            'tags': BeakStringValue('["one","two"]'),
          },
        ),
      );
      expect(controller.valueOf<Object>(_SemanticFields.tags), ['one', 'two']);
      expect(controller.buildData()['money']?.raw, 1234567890123);
      expect(controller.buildData()['date']?.raw, '2028-02-29');
      expect(controller.buildData()['elapsed']?.raw, 3600000001);
    },
  );

  test('nullable boolean starts unset and retains all three values', () {
    final controller = BeakFormController(model: _model);
    addTearDown(controller.dispose);
    expect(controller.valueOf<bool>(_Fields.flag), isNull);
    for (final value in <bool?>[true, false, null]) {
      controller.setValue(_Fields.flag, value);
      expect(controller.buildData()[_Fields.flag.key]?.raw, value);
    }
  });

  test(
    'configured validation applies model bounds without local rules',
    () async {
      final session = BeakFormSession(
        model: _model,
        dataSource: FakeDataSource(),
        layout: BeakFormLayout(children: [_count.input()]),
      );
      addTearDown(session.dispose);
      session.root.set(_count, 0);
      expect(await session.root.validate(), isFalse);
      expect(session.root.errors[_count.key], ['Must be at least 1.']);
    },
  );

  testWidgets(
    'typed JSON fields validate their canonical document while exposing a typed tree',
    (tester) async {
      late BeakFormSession session;
      const json = BeakScalarField<BeakJson>(
        model: _Fields(),
        column: _Fields.json,
      );
      await showForm(
        tester,
        BeakFormLayout(children: [json.inputJson()]),
        (value) => session = value,
        model: const _Fields(),
      );
      await tester.enterText(find.byType(EditableText), '{"nested":1}');
      expect(
        session.root.read(json),
        const BeakJsonObject({'nested': BeakJsonNumber(1)}),
      );
      expect(await session.root.validate(), isTrue);
    },
  );

  testWidgets('JSON syntax errors prevent submission and retain entered text', (
    tester,
  ) async {
    late BeakFormSession session;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: _model,
          dataSource: FakeDataSource(),
          layout: BeakFormLayout(children: [_json.input()]),
          onSession: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '{broken');
    expect(await session.root.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('{broken'), findsOneWidget);
    expect(session.root.errors[_json.key], contains('Must be valid JSON.'));
    await tester.enterText(
      find.byType(EditableText),
      '{"nested":[1,true,null]}',
    );
    expect(await session.root.validate(), isTrue);
    expect(
      session.root.buildRecord()[_json.key]?.raw,
      '{"nested":[1,true,null]}',
    );
  });

  testWidgets('nullable boolean offers an explicit unset choice', (
    tester,
  ) async {
    late BeakFormSession session;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: _model,
          dataSource: FakeDataSource(),
          layout: BeakFormLayout(children: [_flag.input()]),
          onSession: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not set'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(session.root.read(_flag), isTrue);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(session.root.read(_flag), isFalse);
    await tester.tap(find.text('Not set'));
    await tester.pumpAndSettle();
    expect(session.root.read(_flag), isNull);
  });
}

final class _Fields extends BeakModel {
  const _Fields();
  static const flag = BeakBoolColumn(
    key: 'flag',
    label: 'Flag',
    tristate: true,
  );
  static const quantity = BeakIntColumn(
    key: 'count',
    label: 'Count',
    min: 1,
    max: 9,
  );
  static const json = BeakJsonColumn(key: 'json', label: 'JSON');
  static const note = BeakStringColumn(
    key: 'note',
    label: 'Note',
    rules: [BeakMaxLength(40)],
  );
  @override
  String get table => 'semantic_fields';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    flag,
    quantity,
    json,
    note,
  ];
}

final class _SemanticFields extends BeakModel {
  const _SemanticFields();
  static const date = BeakStringColumn(
    key: 'date',
    label: 'Date',
    semantic: BeakSemantic.calendarDate(),
  );
  static const end = BeakStringColumn(
    key: 'end',
    label: 'End',
    semantic: BeakSemantic.calendarDate(),
  );
  static const details = BeakJsonColumn(
    key: 'details',
    label: 'Details',
    semantic: BeakSemantic.object(
      BeakObjectSchema(
        columns: [
          BeakStringColumn(key: 'city', label: 'City'),
          BeakStringColumn(
            key: 'postal',
            label: 'Postal code',
            rules: [BeakRequired()],
          ),
        ],
      ),
    ),
  );
  static const time = BeakStringColumn(
    key: 'time',
    label: 'Time',
    semantic: BeakSemantic.time(),
  );
  static const money = BeakIntColumn(
    key: 'money',
    label: 'Amount',
    semantic: BeakSemantic.money(scale: 3, currency: 'KWD'),
  );
  static const elapsed = BeakIntColumn(
    key: 'elapsed',
    label: 'Elapsed',
    semantic: BeakSemantic.duration(),
  );
  static const percent = BeakDecimalColumn(
    key: 'percent',
    label: 'Percent',
    precision: 4,
    semantic: BeakSemantic.percentage(scale: 1),
  );
  static const weights = BeakJsonColumn(
    key: 'weights',
    label: 'Weights',
    semantic: BeakSemantic.list(
      BeakPrimitiveType.integer,
      minItems: 1,
      maxItems: 2,
      distinctItems: true,
    ),
  );
  static const tags = BeakJsonColumn(
    key: 'tags',
    label: 'Tags',
    semantic: BeakSemantic.list(BeakPrimitiveType.string),
  );
  @override
  String get table => 'semantic_values';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    date,
    end,
    details,
    time,
    money,
    elapsed,
    tags,
    weights,
    percent,
  ];
}

final class _Rules extends BeakModel {
  const _Rules();
  static const value = BeakScalarField<String>(
    model: _Rules(),
    column: BeakStringColumn(key: 'value', label: 'Value', unique: true),
  );
  static const confirmation = BeakScalarField<String>(
    model: _Rules(),
    column: BeakStringColumn(key: 'confirmation', label: 'Confirmation'),
  );
  @override
  String get table => 'rules';
  @override
  String get displayColumnKey => 'value';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    value.column,
    confirmation.column,
  ];
  @override
  List<BeakRecordRule> get validationRules => const [
    BeakSameAs(confirmation, value),
  ];
}

final class _ValidationSource extends FakeDataSource
    implements BeakValidationDataSource {
  _ValidationSource() : super(models: const [_Rules()]);
  final first = Completer<BeakValidationReport>();
  int calls = 0;
  BeakValidationRequest? last;
  @override
  Future<BeakValidationReport> validateRecord(BeakValidationRequest request) {
    last = request;
    calls++;
    return calls == 1
        ? first.future
        : Future.value(const BeakValidationReport());
  }
}

final class _Attributes extends BeakModel {
  const _Attributes();
  static const type = BeakStringColumn(key: 'type', label: 'Type');
  static const value = BeakStringColumn(key: 'value', label: 'Value');
  @override
  String get table => 'attributes';
  @override
  String get displayColumnKey => 'value';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    type,
    value,
  ];
}

final class _FailingValidationSource extends FakeDataSource
    implements BeakValidationDataSource {
  _FailingValidationSource() : super(models: const [_Rules()]);
  @override
  Future<BeakValidationReport> validateRecord(
    BeakValidationRequest request,
  ) async =>
      throw const BeakStorageException('Validation service unavailable.');
}
