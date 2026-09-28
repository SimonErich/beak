import 'package:beak/migrations.dart';
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/beak/registry.g.dart';
import 'package:foodio_adminpanel/beak/server.g.dart';
import 'package:foodio_adminpanel/models/models.dart';
import 'package:foodio_adminpanel/main.dart';
import 'package:go_router/go_router.dart';
import 'package:foodio_adminpanel/resources/orders/forms/order_wizard_screen.dart';
import 'package:foodio_adminpanel/seeders/foodio_seeder.dart';
import 'package:foodio_adminpanel/theme/gabel_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;

void main() {
  late DatabaseAdapter adapter;
  late BeakClient client;
  late HttpBeakDataSource source;
  var commits = 0;
  setUpAll(() async {
    final host = beakHost(
      environment: {
        'DATABASE_URL': 'sqlite::memory:',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    await MigrationRunner(
      adapter: adapter,
      migrations: host.migrations,
      seeders: host.seeders,
    ).fresh(seed: true);
    final server = host.buildServer(adapter: adapter);
    client = BeakClient(
      baseUrl: 'http://foodio.test',
      httpClient: MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/commits')) {
          commits++;
        }
        final response = await server.handler(
          shelf.Request(
            request.method,
            request.url,
            headers: request.headers,
            body: request.bodyBytes,
          ),
        );
        return http.Response(
          await response.readAsString(),
          response.statusCode,
          headers: response.headers,
        );
      }),
    );
    source = HttpBeakDataSource(client);
  });
  tearDownAll(() async {
    client.close();
    await adapter.disconnect();
    await Worm.reset();
  });

  test(
    'typed option search traverses customer profiles to their organization',
    () async {
      final input = OrderModel.customer.inputSearch(
        searchSources: [
          CustomerModel.profiles.search(DeliveryProfileModel.organization.name),
        ],
      );
      final session = BeakFormSession(
        model: const OrderModel(),
        dataSource: source,
        registry: buildBeakRegistry(),
        layout: BeakFormLayout(children: [input]),
      );
      addTearDown(session.dispose);
      await session.load();
      final options = await session.root.search(input, 'Nordlicht');
      expect(
        options.map((record) => record.asCustomer.id),
        contains(FoodioIds.lena),
      );
      expect(
        options.map((record) => record.asCustomer.name),
        isNot(contains('Nordlicht')),
      );
    },
  );

  test(
    'private delivery choices retain the profile’s own saved location',
    () async {
      Iterable<BeakFormNode> nodes(BeakFormNode node) sync* {
        yield node;
        if (node is BeakFormLayout) {
          for (final child in node.children) {
            yield* nodes(child);
          }
        }
      }

      final location = nodes(BeakFormLayout(children: orderWizard().steps))
          .whereType<BeakRelationInput>()
          .firstWhere((node) => node.field.key == OrderModel.location.key);
      final session = BeakFormSession(
        model: const OrderModel(),
        dataSource: source,
        registry: buildBeakRegistry(),
        layout: BeakFormLayout(children: [location]),
      );
      addTearDown(session.dispose);
      await session.load();
      session.root.select(
        OrderModel.profile,
        await source.getOne('delivery_profiles', FoodioIds.lenaPrivate),
      );
      final choices = await session.root.search(location, '');
      expect(choices.map((record) => record.asDeliveryLocation.id), [
        'location-home',
      ]);
    },
  );

  testWidgets('dish pricing tab retains owned edits and newly added sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(config: foodioPanel(), dataSource: source),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    router.go('/dishes/${FoodioIds.risotto}/edit');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sizes & pricing'));
    await tester.pumpAndSettle();
    final editors = find.descendant(
      of: find.byType(BeakConfiguredForm),
      matching: find.byType(EditableText),
    );
    final initialCount = editors.evaluate().length;
    expect(initialCount, 6);
    await tester.enterText(editors.first, 'Small serving');
    await tester.pumpAndSettle();
    expect(tester.widget<OiTabs>(find.byType(OiTabs)).selectedIndex, 1);
    await tester.enterText(editors.at(1), '8.50');
    await tester.pumpAndSettle();
    expect(tester.widget<OiTabs>(find.byType(OiTabs)).selectedIndex, 1);
    await tester.tap(find.text('Add Available sizes'));
    await tester.pumpAndSettle();
    expect(tester.widget<OiTabs>(find.byType(OiTabs)).selectedIndex, 1);
    expect(editors, findsNWidgets(initialCount + 2));
    await tester.enterText(editors.at(initialCount), 'Family');
    await tester.pumpAndSettle();
    expect(tester.widget<OiTabs>(find.byType(OiTabs)).selectedIndex, 1);
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sizes & pricing'));
    await tester.pumpAndSettle();
    final values = tester
        .widgetList<EditableText>(editors)
        .map((input) => input.controller.text)
        .toList();
    expect(values, containsAll(['Small serving', '8.50', 'Family']));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'five configured steps place one authoritative graph and preserve selections',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final screen = orderWizard();
      late BeakFormSession session;
      BeakRecord? saved;
      await tester.pumpWidget(
        OiApp(
          theme: gabelTheme(),
          home: BeakConfiguredForm(
            model: const OrderModel(),
            dataSource: source,
            registry: buildBeakRegistry(),
            steps: screen.steps,
            header: screen.header,
            aside: screen.aside,
            asideFooter: screen.asideFooter,
            footer: screen.footer,
            navigation: screen.navigation,
            submitAction: screen.submitAction,
            submitLabel: screen.submitLabel,
            onSession: (value) => session = value,
            onSaved: (record) => saved = record,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      int step() => tester
          .widget<OiWizardLayout>(find.byType(OiWizardLayout))
          .currentStep;
      Future<void> next(int expected) async {
        await tester.tap(
          find.widgetWithText(
            OiButton,
            screen.steps[step()].continueLabel ?? 'Continue',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          step(),
          expected,
          reason: '${session.root.errors} / ${session.error.value}',
        );
        expect(tester.takeException(), isNull);
      }

      await tester.enterText(find.byType(EditableText).first, 'Lena');
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('customer:${FoodioIds.lena}')),
      );
      await tester.pumpAndSettle();
      expect(session.root.read(OrderModel.customerId), FoodioIds.lena);
      expect(session.root.read(OrderModel.profileId), FoodioIds.lenaCompany);
      await next(1);
      final slot = find
          .byWidgetPredicate(
            (widget) =>
                widget is OiRadioTile<Object> &&
                widget.key.toString().contains('slot:') &&
                widget.enabled,
          )
          .first;
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      final selectedSlot = session.root.read(OrderModel.slotId);
      expect(selectedSlot, isNotNull);
      await next(2);
      await tester.enterText(find.byType(EditableText).first, 'risotto');
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(find.text('Beetroot risotto with goat’s cheese'), findsWidgets);
      final increase = find
          .byWidgetPredicate(
            (widget) =>
                widget is OiButton &&
                (widget.semanticLabel?.startsWith('Increase ') ?? false),
          )
          .first;
      await tester.ensureVisible(increase);
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(find.byType(OiQuantitySelector), findsOneWidget);
      await tester.tap(increase);
      await tester.pumpAndSettle();
      final line = session.root.rows(OrderModel.items).single;
      expect(line.read(OrderItemModel.quantity), 2);
      expect(line.read(OrderItemModel.dishId), FoodioIds.risotto);
      expect(line.read(OrderItemModel.unitPriceCents), isPositive);
      expect(commits, 0);
      await next(3);
      expect(session.root.read(OrderModel.paymentMode), 'monthlyInvoice');
      await tester.tap(find.widgetWithText(OiButton, 'Back'));
      await tester.pumpAndSettle();
      expect(step(), 2);
      expect(session.root.rows(OrderModel.items).single, same(line));
      await next(3);
      await next(4);
      expect(find.text('Check and place the order'), findsOneWidget);
      expect(find.text('Order confirmation'), findsOneWidget);
      expect(
        find.text('2 × Beetroot risotto with goat’s cheese'),
        findsOneWidget,
      );
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      expect(step(), 0);
      for (var index = 1; index <= 4; index++) {
        await next(index);
      }
      expect(session.root.rows(OrderModel.items).single, same(line));
      expect(session.root.read(OrderModel.slotId), selectedSlot);
      expect(commits, 0);
      await tester.tap(find.widgetWithText(OiButton, 'Place order'));
      await tester.pumpAndSettle();
      expect(
        session.saveResult.value?.complete,
        isTrue,
        reason:
            '${session.root.errors} / ${session.error.value} / ${session.saveResult.value?.toJson()}',
      );
      expect(saved, isNotNull);
      expect(commits, 1);
      final persisted = await source.getOne('orders', saved!.asOrder.id!);
      expect(persisted?.asOrder.status, OrderStatus.confirmed);
      expect(persisted?.asOrder.grossCents, isPositive);
      final rows = await source.query(
        const OrderItemModel().query(
          filter: OrderItemModel.orderId.eq(saved!.asOrder.id),
        ),
      );
      expect(rows.items, hasLength(1));
      expect(rows.items.single.asOrderItem.quantity, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
