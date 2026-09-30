# A dashboard KPI

> Put a live count on a page with BeakMetricBlock, share its filter with the work queue, and total exact money in a widget when no block can.

You want a number at the top of a page: how many orders wait to be fulfilled, how much money is outstanding. It should be right when the page opens and again after someone saves an order.

## Recipe

A number is a `BeakMetricBlock` with an aggregate. `count()` needs nothing else. This is the shop's simplest one:

```dart title="examples/clean_beak_config/lib/overview.dart"
BeakMetricBlock(
  label: 'Products',
  icon: OiIcons.package,
  aggregate: const ProductModel().count(),
),
```

Filter the count with the same typed filters a list uses. "Orders to fulfill" is a filter that the shop defines once and uses twice, on the card and on the work queue, so the number and the rows behind it cannot disagree:

```dart title="examples/clean_beak_config/lib/operations.dart"
/// The same operational definition is used by the dashboard and work queue.
BeakFilter fulfillmentQueueFilter() => BeakOrFilter([
  OrderModel.status.eq(OrderStatus.confirmed),
  OrderModel.status.eq(OrderStatus.packing),
]);
```

Lay the metrics out in a grid on a page. `BeakGridBlock` puts as many columns as fit and stacks them on a phone:

```dart title="examples/clean_beak_config/lib/overview.dart"
BeakGridBlock(
  minColumnWidthInPixels: 220,
  children: [
    BeakMetricBlock(
      label: 'Products',
      icon: OiIcons.package,
      aggregate: const ProductModel().count(),
    ),
    BeakMetricBlock(
      label: 'Orders to fulfill',
      icon: OiIcons.shoppingCart,
      aggregate: const OrderModel().count(
        filter: fulfillmentQueueFilter(),
      ),
    ),
    BeakMetricBlock(
      label: 'Awaiting payment',
      icon: OiIcons.receiptText,
      aggregate: const InvoiceModel().count(
        filter: InvoiceModel.status.eq(InvoiceStatus.issued),
      ),
    ),
    BeakMetricBlock(
      label: 'Low-stock variants',
      icon: OiIcons.layers,
      aggregate: const ProductVariantModel().count(
        filter: ProductVariantModel.stock.lte(5),
      ),
    ),
  ],
),
```

The page is a `BeakScreen`. With `path: '/'` it becomes the landing page, see [Dashboards](../panel/dashboards.md#make-it-the-landing-page). In an authored panel, list it in `pages:`. In a generated one, put it under `lib/screens/`.

### Money

Two cases, decided by how the money is stored.

Money stored as a plain number is still a metric. `sum` returns storage units, so integer cents need `minorUnits: true` (and `scale` if it is not 2) to show major units, and `format: BeakValueFormat.currency` uses the panel's currency. The Aviary keeps its invoice total as a `double` in major units, so its "Feed invoiced" card sets only the format. The same block holds a comparison (`previous`), a target and a unit on the other cards:

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakBlock _metrics() => BeakGridBlock(
  minColumnWidthInPixels: 220,
  children: [
    BeakMetricBlock(
      label: 'Specimens',
      icon: OiIcons.bird,
      aggregate: const SpecimenModel().count(),
      target: 60,
    ),
    BeakMetricBlock(
      label: 'Endangered',
      icon: OiIcons.egg,
      aggregate: const SpecimenModel().count(
        filter: SpecimenModel.endangered.eq(true),
      ),
    ),
    BeakMetricBlock(
      label: 'Average weight',
      icon: OiIcons.feather,
      aggregate: const SpecimenModel().avg(SpecimenModel.weightInGrams),
      unit: 'g',
    ),
    BeakMetricBlock(
      label: 'Birds seen, second fortnight',
      icon: OiIcons.trees,
      aggregate: const SightingModel().sum(
        SightingModel.birdsSeen,
        filter: SightingModel.spottedOn.gte(AviaryDates.secondFortnightStart),
      ),
      previous: const SightingModel().sum(
        SightingModel.birdsSeen,
        filter: SightingModel.spottedOn.lt(AviaryDates.secondFortnightStart),
      ),
    ),
    BeakMetricBlock(
      label: 'Feed invoiced',
      icon: OiIcons.receiptText,
      aggregate: const InvoiceModel().sum(InvoiceModel.total),
      format: BeakValueFormat.currency,
    ),
  ],
);
```

Money stored as `BeakDecimal`, which is what the shop uses, cannot go through `BeakMetricBlock`. Its `aggregate` comes from `model.sum(field)`, and that takes a `BeakScalarField<num>`. A `BeakDecimal` is not a `num`, on purpose: it would make exact money a `double` again. The field has its own exact `sum`, which returns a `BeakDecimal` and throws instead of rounding. Call it in a widget and place the widget with `BeakWidgetBlock`:

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
final source = beakDependencies(context)<BeakDataSource>();
final revision = useBeakDataRevision(
  source,
  table: const InvoiceModel().table,
);
final attempt = useState(0);
final request = useMemoized(
  () => BeakResourceRepository(source).run(
    () => InvoiceModel.total.sum(
      source,
      filter: InvoiceModel.status.eq(InvoiceStatus.issued),
    ),
  ),
  [source, revision, attempt.value],
);
final snapshot = useFuture(request, preserveState: false);
final strings = BeakLocalizations.of(context);
final format = BeakFormatting.of(context);
```

```dart title="examples/clean_beak_config/lib/overview.dart"
      BeakWidgetBlock((context) => const ShopReceivablesCard()),
```

## How it works

- The block does not fetch rows. It sends one aggregate request to the data source (count, sum or average, with the filter), and the server answers with a number. Two requests when `previous` is set.
- Blocks refetch after any write to the table they aggregate, made through this panel. A save in a form updates the card without a reload. A colleague's write in another browser does not, unless the panel sets a `refreshPolicy`, see [Dashboards](../panel/dashboards.md#keep-it-current).
- `useBeakDataRevision(source, table: ...)` is the hook that does it. The exact-money card puts the counter it returns into its memo key, which is all it takes to refetch.
- A metric that fails shows the error and a retry button. The receivables card does the same, and it never shows zero for a failed request. The shop's test forces the failure and asserts that the retry is there and the words `All clear` are not.
- The server decides what the number counts. A row policy narrows the count for the account, and an account that may not read the table sees the error state.

## Variations

| You want | Do this |
| --- | --- |
| Change against last month | `previous:` with the aggregate for the earlier period. The card shows the percentage change, and nothing when the earlier value is 0. |
| Progress towards a goal | `target:` in the aggregate's own units, drawn as a progress bar. |
| A unit after the number | `unit: 'kg'` |
| An average | `const SpecimenModel().avg(SpecimenModel.weightInGrams)` |
| A number split by a field | Not a metric. Use a `BeakSummaryBlock`, see [Population summaries](../blocks/summaries.md). |
| The figure to follow the list's filters | A summary block in a composed list's header with `scope: active`, see [Composed lists](../panel/composed-lists.md). |

## Verify

The shop's overview renders its metrics and tables against an in-memory source. The receivables card has a test that forces the aggregate to fail:

```dart title="examples/clean_beak_config/test/custom_shop_test.dart"
testWidgets(
  'custom billing widget shows a retryable error without a false zero',
  (tester) async {
    final registry = buildBeakRegistry();
    final source = _FailingAggregate(
      InMemoryBeakDataSource(registry: registry),
    );
    await tester.pumpWidget(
      BeakPanel(
        pages: [
          BeakScreen(
            path: '/',
            title: 'Billing',
            icon: const BeakIconToken(OiIcons.receiptText),
            body: BeakWidgetBlock((_) => const ShopReceivablesCard()),
          ),
        ],
        resources: [InvoiceResource()],
        dataSource: source,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('All clear. No issued invoices are awaiting payment.'),
      findsNothing,
    );
    source.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('All clear. No issued invoices are awaiting payment.'),
      findsOneWidget,
    );
  },
);
```

```console
$ cd examples/clean_beak_config
$ flutter test test/shop_widget_test.dart --plain-name 'shop overview'
All tests passed!
$ flutter test test/custom_shop_test.dart --plain-name 'custom billing widget'
All tests passed!
```

## Continue reading

- [A saved list view](a-saved-list-view.md) keeps a filtered list one click away.
- [Dashboards](../panel/dashboards.md) covers the landing page, grouped figures and refresh.
- [A money field](a-money-field.md) declares the exact money the receivables card sums.
