import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/company.dart';

/// Company directory, linked from customer billing profiles.
final class CompanyResource extends BeakResource {
  /// Creates the companies section.
  CompanyResource()
    : super(
        model: const CompanyModel(),
        title: 'Companies',
        icon: const BeakIconToken(OiIcons.building2),
        navigationGroup: 'Customers',
        navigationRank: 7,
        globalSearchSources: [CompanyModel.name],
        filters: [CompanyModel.name.textFilter()],
        screens: [
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: BeakFormLayout(
              children: [
                BeakCard(
                  title: 'Company details',
                  children: [CompanyModel.name.inputText()],
                ),
              ],
            ),
          ),
        ],
      );
}
