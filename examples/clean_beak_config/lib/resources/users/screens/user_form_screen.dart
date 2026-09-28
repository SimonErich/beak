import 'package:beak/panel.dart';
import '../../profiles/models/profile.dart';
import '../models/user.dart';
import '../models/user_profile_connection.dart';
import 'user_profile_connection_form.dart';

/// A reusable structure for viewing, creating and editing a customer.
final class UserFormScreen extends BeakFormScreen {
  /// Creates the shared customer form and detail screen.
  UserFormScreen()
    : super(
        roles: const {
          BeakScreenRole.read,
          BeakScreenRole.create,
          BeakScreenRole.edit,
        },
        layout: BeakFormLayout(
          children: [
            BeakColumns(
              children: [
                BeakCard(
                  title: 'Personal details',
                  children: [
                    UserModel.firstName.inputText(),
                    UserModel.lastName.inputText(),
                    UserModel.email.inputText(),
                  ],
                ),
                BeakCard(
                  title: 'Company',
                  children: [
                    UserModel.company.inputCombobox(),
                    UserModel.invoiceCompany.inputToggle(
                      label: 'Invoice the company',
                      visibleIf: (state) => state.asUser.companyId != null,
                    ),
                  ],
                ),
              ],
            ),
            BeakCard(
              title: 'Delivery profiles',
              children: [
                UserModel.profiles.tableForm(
                  label: 'Profiles',
                  removeBehavior: BeakRemoveBehavior.deleteOwned,
                  children: [
                    UserProfileConnectionModel.name.inputText(
                      label: 'Label for this customer',
                    ),
                    UserProfileConnectionModel.profile.inputCombobox(
                      exclusive: false,
                      createForm: BeakFormLayout(
                        children: [
                          ProfileModel.name.inputText(),
                          ProfileModel.address.inputText(),
                        ],
                      ),
                    ),
                  ],
                  advancedForm: userProfileConnectionForm,
                ),
              ],
            ),
          ],
        ),
      );
}
