import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/user.dart';
import 'screens/user_form_screen.dart';

/// Customer administration shares one layout across all record modes.
final class UserResource extends BeakResource {
  /// Creates the customer section.
  UserResource()
    : super(
        model: const UserModel(),
        title: 'Customers',
        icon: const BeakIconToken(OiIcons.users),
        navigationGroup: 'Customers',
        navigationRank: 6,
        globalSearchSources: [
          UserModel.email,
          UserModel.firstName,
          UserModel.lastName,
          UserModel.company.name,
        ],
        filters: [
          UserModel.email.textFilter(),
          UserModel.company.relationFilter(),
          UserModel.invoiceCompany.boolFilter(label: 'Company billing'),
        ],
        screens: [
          BeakTableScreen(
            fields: [UserModel.firstName, UserModel.lastName, UserModel.email],
          ),
          UserFormScreen(),
        ],
      );
}
