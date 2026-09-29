import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'models/keeper.dart';

/// The blocks that read one keeper: fields, a field group and relations.
///
/// Record blocks have no query of their own. They read the record the
/// surrounding [BeakRecordScope] carries, so this tree is written once and
/// shows whichever keeper the route names.
// --8<-- [start:keeperSheetBlock]
BeakBlock keeperSheetBlock() => BeakColumnBlock(
  children: [
    BeakCardBlock(
      title: 'Keeper',
      child: BeakFieldGroupBlock([
        KeeperModel.name.column,
        KeeperModel.email.column,
        KeeperModel.role.column,
      ], columnCount: 3),
    ),
    BeakCardBlock(
      title: 'About',
      child: BeakFieldBlock(
        KeeperModel.bio.column,
        layout: BeakFieldLayout.inline,
      ),
    ),
    BeakRelationBlock(KeeperModel.habitats.relation, title: 'Habitats'),
  ],
);
// --8<-- [end:keeperSheetBlock]

/// The read screen of a keeper.
///
/// Loads the record the route names, then hands it to [keeperSheetBlock]
/// through a [BeakRecordScope].
class KeeperSheet extends HookWidget {
  /// Shows the keeper stored under [recordId].
  const KeeperSheet({required this.recordId, super.key});

  /// The identity taken from the route.
  final Object? recordId;

  @override
  Widget build(BuildContext context) {
    final source = beakDependencies(context)<BeakDataSource>();
    final id = recordId;
    final request = useMemoized(
      () => id == null
          ? null
          : BeakResourceRepository(
              source,
            ).getOne(const KeeperModel().table, id),
      [source, id],
    );
    final snapshot = useFuture(request);
    final strings = BeakLocalizations.of(context);
    // --8<-- [start:recordScopeHandOff]
    final Widget body = switch (snapshot.data) {
      BeakOk<BeakRecord>(:final value) => BeakRecordScope(
        model: const KeeperModel(),
        record: value,
        child: BeakBlockHost(block: keeperSheetBlock()),
      ),
      BeakErr<BeakRecord>(:final error) => OiLabel.body(
        strings.errorMessage(error),
      ),
      null => OiProgress.linear(indeterminate: true, label: strings.loading),
    };
    // --8<-- [end:recordScopeHandOff]
    return OiPageLayout(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      gap: 16,
      header: const OiPageHeader(
        title: 'Keeper',
        titleVariant: OiLabelVariant.h1,
        padding: EdgeInsets.zero,
      ),
      scrollable: true,
      child: body,
    );
  }
}
