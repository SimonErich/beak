import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _confirmed = BeakScalarField<bool>(
  model: _Order(),
  column: _Order.confirmed,
);
const _email = BeakScalarField<String>(
  model: _Order(),
  column: _Customer.email,
  path: [_Order.customer],
);

void main() {
  for (final denied in [false, true]) {
    testWidgets(
      'input dependencies autoload and honor relation permission (denied: $denied)',
      (tester) async {
        final source = _Source(denied: denied);
        var labelReads = 0;
        final input = _confirmed.inputCheckbox(
          dependencies: const [_email],
          labelBuilder: (state) {
            labelReads++;
            return 'Confirm for ${state.read(_email)}';
          },
        );
        late BeakFormSession session;
        await tester.pumpWidget(
          OiApp(
            theme: OiThemeData.light(),
            home: BeakConfiguredForm(
              model: const _Order(),
              dataSource: source,
              recordId: 'order',
              onSession: (value) => session = value,
              layout: BeakFormLayout(children: [input]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(session.root.visible(input), !denied);
        if (denied) {
          expect(labelReads, 0);
          expect(find.byType(OiCheckbox), findsNothing);
        } else {
          expect(
            find.text('Confirm for customer@example.test'),
            findsOneWidget,
          );
          expect(labelReads, greaterThan(0));
          expect(
            source.queryCalls
                .where((query) => query.table == 'orders')
                .single
                .relationLoads
                .single
                .relationKey,
            'customer',
          );
          await tester.tap(find.text('Confirm for customer@example.test'));
          await tester.pumpAndSettle();
          expect(session.root.read(_confirmed), isTrue);
          expect(source.updateCalls, isEmpty);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final class _Order extends BeakModel {
  const _Order();
  static const confirmed = BeakBoolColumn(key: 'confirmed', label: 'Confirmed');
  static const customer = BeakBelongsTo(
    key: 'customer',
    label: 'Customer',
    relatedTable: 'customers',
    foreignKey: 'customer_id',
    displayColumnKey: 'email',
  );
  @override
  String get table => 'orders';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'customer_id', label: 'Customer'),
    confirmed,
  ];
  @override
  List<BeakRelationship> get relationships => const [customer];
  @override
  List<BeakModel> get relatedModels => const [_Customer()];
}

final class _Customer extends BeakModel {
  const _Customer();
  static const email = BeakStringColumn(key: 'email', label: 'Email');
  @override
  String get table => 'customers';
  @override
  String get displayColumnKey => 'email';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    email,
  ];
}

final class _Source extends FakeDataSource implements BeakCapabilityDataSource {
  _Source({required this.denied})
    : super(
        models: const [_Order(), _Customer()],
        records: {
          'orders': {
            'order': BeakRecord.fromRow({
              'id': 'order',
              'customer_id': 'customer',
              'confirmed': false,
            }),
          },
          'customers': {
            'customer': BeakRecord.fromRow({
              'id': 'customer',
              'email': 'customer@example.test',
            }),
          },
        },
      );
  final bool denied;
  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async => denied && table == 'orders'
      ? const BeakAccessCapabilities(
          readableFields: {'id', 'confirmed', 'customer_id'},
        )
      : const BeakAccessCapabilities();
}
