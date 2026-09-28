import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _customerId = BeakScalarField<String>(
  model: _Booking(),
  column: BeakStringColumn(key: 'customer_id', label: 'Customer'),
);
const _profileId = BeakScalarField<String>(
  model: _Booking(),
  column: BeakStringColumn(key: 'profile_id', label: 'Profile'),
);
const _profileCustomerId = BeakScalarField<String>(
  model: _Profile(),
  column: BeakStringColumn(
    key: 'customer_id',
    label: 'Customer',
    rules: [BeakRequired()],
  ),
);
const _name = BeakScalarField<String>(
  model: _Customer(),
  column: BeakStringColumn(key: 'name', label: 'Name', rules: [BeakRequired()]),
);
const _profileName = BeakScalarField<String>(
  model: _Profile(),
  column: BeakStringColumn(
    key: 'name',
    label: 'Profile name',
    rules: [BeakRequired()],
  ),
);
const _customer = BeakToOneField(
  model: _Booking(),
  target: _Customer(),
  relation: BeakBelongsTo(
    key: 'customer',
    label: 'Customer',
    relatedTable: 'people',
    foreignKey: 'customer_id',
    displayColumnKey: 'name',
  ),
);
const _profile = BeakToOneField(
  model: _Booking(),
  target: _Profile(),
  relation: BeakBelongsTo(
    key: 'profile',
    label: 'Profile',
    relatedTable: 'profiles',
    foreignKey: 'profile_id',
    displayColumnKey: 'name',
  ),
);
const _profileCustomer = BeakToOneField(
  model: _Profile(),
  target: _Customer(),
  relation: BeakBelongsTo(
    key: 'customer',
    label: 'Customer',
    relatedTable: 'people',
    foreignKey: 'customer_id',
    displayColumnKey: 'name',
  ),
);

final customerInput = _customer.inputSearch(
  exclusive: false,
  createForm: BeakFormLayout(children: [_name.input()]),
);
final profileInput = _profile.inputCards(
  exclusive: false,
  createForm: BeakFormLayout(
    children: [_profileName.input(), _profileCustomer.inputCombobox()],
  ),
);
final layout = BeakFormLayout(children: [customerInput, profileInput]);

void main() {
  BeakFormSession session(FakeDataSource source, {BeakFormDrafts? drafts}) =>
      BeakFormSession(
        model: const _Booking(),
        dataSource: source,
        layout: layout,
        drafts: drafts,
      );
  FakeDataSource source() =>
      FakeDataSource(models: const [_Booking(), _Customer(), _Profile()]);

  test(
    'dependent inline creations commit one shared target and resolve both foreign keys',
    () async {
      final data = source();
      final form = session(data);
      addTearDown(form.dispose);
      await form.load();
      expect(form.root.enabled(profileInput), isFalse);
      final customer = form.root.createSelection(customerInput)
        ..set(_name, 'Ada');
      expect(form.root.enabled(profileInput), isTrue);
      final profile = form.root.createSelection(profileInput)
        ..set(_profileName, 'Work');
      customer.set(_name, 'Ada Lovelace');
      expect(profile.read(_profileCustomer)?['name']?.raw, 'Ada Lovelace');
      expect(
        await form.validate(),
        isTrue,
        reason: '${form.root.errors} / ${profile.errors}',
      );
      final result = await form.save();
      expect(
        result?.complete,
        isTrue,
        reason: '${result?.toJson()} / ${form.root.errors}',
      );
      expect(data.createCalls.map((call) => call.$1), [
        'people',
        'profiles',
        'bookings',
      ]);
      final person = (await data.query(const _Customer().query())).items.single;
      final savedProfile = (await data.query(
        const _Profile().query(),
      )).items.single;
      final booking = (await data.query(const _Booking().query())).items.single;
      expect(savedProfile['customer_id'], person['id']);
      expect(booking['customer_id'], person['id']);
      expect(booking['profile_id'], savedProfile['id']);
      expect(form.root.read(_profile)?['customer_id'], person['id']);
    },
  );

  test(
    'durable drafts restore shared links without duplicating the staged record',
    () async {
      final data = source();
      final store = BeakMemoryDraftStore();
      final drafts = BeakFormDrafts(
        store: store,
        key: 'booking',
        context: 'user:1',
      );
      final first = session(data, drafts: drafts);
      await first.load();
      first.root.createSelection(customerInput).set(_name, 'Grace');
      first.root.createSelection(profileInput).set(_profileName, 'Office');
      expect(await first.persistDraft(), isTrue);
      first.dispose();
      final restored = session(data, drafts: drafts);
      addTearDown(restored.dispose);
      await restored.load();
      restored.resumeDraft();
      expect(
        restored.root
            .read(_profile)
            ?.relations['customer']
            ?.single['name']
            ?.raw,
        'Grace',
      );
      final result = await restored.save();
      expect(
        result?.complete,
        isTrue,
        reason: '${result?.toJson()} / ${restored.root.errors}',
      );
      expect(
        data.createCalls.where((call) => call.$1 == 'people'),
        hasLength(1),
      );
      final person = (await data.query(const _Customer().query())).items.single;
      final profile = (await data.query(const _Profile().query())).items.single;
      expect(profile['customer_id'], person['id']);
    },
  );

  test(
    'replacing a prerequisite rejects a dependent staged selection instead of saving an orphan',
    () async {
      final data = source();
      final form = session(data);
      addTearDown(form.dispose);
      await form.load();
      form.root.createSelection(customerInput).set(_name, 'First customer');
      form.root
          .createSelection(profileInput)
          .set(_profileName, 'First profile');
      form.root.createSelection(customerInput).set(_name, 'Second customer');
      expect(await form.validate(), isFalse);
      expect(form.root.errors['profile'], isNotEmpty);
      expect(await form.save(), isNull);
      expect(data.createCalls, isEmpty);
    },
  );
  testWidgets(
    'inline creation keeps the staged option visible and selected without an ID',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = source();
      late BeakFormSession form;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Booking(),
            dataSource: data,
            layout: layout,
            onSession: (value) => form = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Customer'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(EditableText).last,
        'New local customer',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final option = tester.widget<OiRadioTile<Object>>(
        find.byKey(const ValueKey('customer:local')),
      );
      expect(option.groupValue, option.value);
      expect(find.text('New local customer'), findsOneWidget);
      await tester.tap(find.text('Create Profile'));
      await tester.pumpAndSettle();
      final nameInput = find.byWidgetPredicate(
        (widget) => widget is OiTextInput && widget.label == 'Profile name',
      );
      await tester.enterText(
        find.descendant(of: nameInput, matching: find.byType(EditableText)),
        'New profile',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile:local')), findsOneWidget);
      expect(
        form.root.read(_profile)?.relations['customer']?.single['name']?.raw,
        'New local customer',
      );
      expect(data.createCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'pending receipt restoration retains shared references and recovers without resubmitting',
    () async {
      final data = _PendingSource();
      final drafts = BeakFormDrafts(
        store: BeakMemoryDraftStore(),
        key: 'new',
        context: 'person',
      );
      final first = session(data, drafts: drafts);
      await first.load();
      first.root.createSelection(customerInput).set(_name, 'Pending person');
      first.root
          .createSelection(profileInput)
          .set(_profileName, 'Pending profile');
      await first.save();
      expect(first.hasUnknown, isTrue);
      first.dispose();
      final reopened = session(data, drafts: drafts);
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.hasUnknown, isTrue);
      expect(
        reopened.root
            .read(_profile)
            ?.relations['customer']
            ?.single['name']
            ?.raw,
        'Pending person',
      );
      await reopened.save();
      expect(data.commitCalls, 1);
      data.confirmed = true;
      await reopened.recover();
      expect(reopened.hasUnknown, isFalse);
      expect(reopened.saveResult.value?.complete, isTrue);
      expect(reopened.root.read(_profile)?['customer_id']?.raw, 'people-id');
      expect(data.commitCalls, 1);
    },
  );
}

final class _Booking extends BeakModel {
  const _Booking();
  @override
  String get table => 'bookings';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'ID'),
    _customerId.column,
    _profileId.column,
  ];
  @override
  List<BeakRelationship> get relationships => [
    _customer.relation,
    _profile.relation,
  ];
  @override
  List<BeakModel> get relatedModels => const [_Customer(), _Profile()];
  @override
  List<BeakRecordRule> get validationRules => [
    const BeakExists(
      _profileId,
      BeakScalarField<String>(
        model: _Profile(),
        column: BeakStringColumn(key: 'id', label: 'ID'),
      ),
      matching: [
        BeakFieldMatch(target: _profileCustomerId, source: _customerId),
      ],
    ),
  ];
}

final class _Customer extends BeakModel {
  const _Customer();
  @override
  String get table => 'people';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'ID'),
    _name.column,
  ];
}

final class _Profile extends BeakModel {
  const _Profile();
  @override
  String get table => 'profiles';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'ID'),
    _profileName.column,
    _profileCustomerId.column,
  ];
  @override
  List<BeakRelationship> get relationships => [_profileCustomer.relation];
  @override
  List<BeakModel> get relatedModels => const [_Customer()];
}

final class _PendingSource extends FakeDataSource
    implements BeakCommitDataSource {
  _PendingSource() : super(models: const [_Booking(), _Customer(), _Profile()]);
  BeakSavePlan? plan;
  bool confirmed = false;
  int commitCalls = 0;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true);
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    this.plan = plan;
    commitCalls++;
    return result;
  }

  @override
  Future<BeakSaveResult> recover(String id) async => result;
  BeakSaveResult get result => BeakSaveResult(
    saveId: plan!.saveId,
    mode: BeakSaveMode.atomic,
    outcomes: [
      for (final operation in plan!.operations)
        BeakOperationResult(
          id: operation.id,
          status: confirmed
              ? BeakWriteOutcome.applied
              : BeakWriteOutcome.unknown,
          resolvedId: confirmed ? '${operation.target.table}-id' : null,
          record: confirmed
              ? BeakRecord(
                  values: {
                    ...operation.values.values,
                    'id': BeakStringValue('${operation.target.table}-id'),
                    for (final reference in operation.references.entries)
                      reference.key: BeakStringValue(
                        '${reference.value.table}-id',
                      ),
                  },
                )
              : null,
        ),
    ],
  );
}
