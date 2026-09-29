import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'keeper_sheet.dart';
import 'models/keeper.dart';

/// The people, with a read screen composed from record blocks.
final class KeeperResource extends BeakResource {
  /// Creates the keepers section.
  KeeperResource()
    : super(
        model: const KeeperModel(),
        title: 'Keepers',
        icon: const BeakIconToken(OiIcons.users),
        navigationGroup: 'Team',
        navigationRank: 3,
        globalSearchSources: [KeeperModel.name, KeeperModel.email],
        filters: [KeeperModel.role.selectFilter()],
        screens: [
          BeakTableScreen(
            fields: [KeeperModel.name, KeeperModel.email, KeeperModel.role],
          ),
          BeakCustomResourceScreen(
            roles: const {BeakScreenRole.read},
            builder: (context, recordId) => KeeperSheet(recordId: recordId),
          ),
        ],
      );
}
