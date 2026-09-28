part of '../beak_block_host.dart';

/// Fetches a [BeakPricingBlock]'s plan records, maps each (with its feature
/// relation) to an [OiPricingPlan], and renders them on `OiPricingTable`.
class _BeakPricingBlockView extends HookWidget {
  const _BeakPricingBlockView({required this.block});

  final BeakPricingBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(dataSource).query(
          BeakQuerySpec(
            table: block.model.table,
            sorts: [
              if (block.sortField case final BeakColumn column)
                BeakSort(column.key),
            ],
            relationLoads: [
              // Without this the plans arrive relation-less and every card
              // renders an empty feature list.
              if (block.featuresRelation case final BeakRelationship relation)
                BeakRelationLoad(relation.key),
            ],
            pagination: _modulePage,
          ),
        );
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          records.value = value.items;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    return OiPricingTable(
      label: block.label,
      currencySymbol: block.currencySymbol,
      showBillingToggle: block.yearlyPriceField != null,
      plans: [
        for (final (index, record) in records.value.indexed)
          _planOf(index, record),
      ],
    );
  }

  OiPricingPlan _planOf(int index, BeakRecord record) => OiPricingPlan(
    key: (block.model.primaryKeyOf(record) ?? index).toString(),
    name: _readString(record, block.nameField) ?? '',
    monthlyPrice: _readDouble(record, block.priceField) ?? 0,
    yearlyPrice: _readDouble(record, block.yearlyPriceField),
    description: _readString(record, block.descriptionField),
    recommended: _readBool(record, block.featuredField),
    ctaLabel: _readString(record, block.ctaField) ?? 'Get Started',
    features: _featuresOf(record),
  );

  List<String> _featuresOf(BeakRecord record) {
    final BeakRelationship? relation = block.featuresRelation;
    final BeakColumn? labelField = block.featureLabelField;
    if (relation == null || labelField == null) {
      return const [];
    }
    return [
      for (final feature
          in record.relations[relation.key] ?? const <BeakRecord>[])
        if (_readString(feature, labelField) case final String label) label,
    ];
  }
}
