import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/profile.dart';

/// Reusable delivery addresses searchable by title or address.
final class ProfileResource extends BeakResource {
  /// Creates the delivery profiles section.
  ProfileResource()
    : super(
        model: const ProfileModel(),
        title: 'Delivery profiles',
        icon: const BeakIconToken(OiIcons.mapPin),
        navigationGroup: 'Customers',
        navigationRank: 8,
        globalSearchSources: [ProfileModel.name, ProfileModel.address],
        filters: [
          ProfileModel.name.textFilter(),
          ProfileModel.address.textFilter(),
        ],
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
                  title: 'Delivery address',
                  children: [
                    ProfileModel.name.inputText(),
                    ProfileModel.address.inputText(),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}
