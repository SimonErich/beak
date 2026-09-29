# Detail views

> Reuse a structured layout to read, edit and create records, with record blocks and relation managers.

Assign the read, create and edit roles to one `BeakFormScreen` to reuse its layout. Beak renders values in read mode and inputs in edit mode. Cards, tabs and related sections retain their structure, and the panel formatting policy applies consistently.

Edit permission and lifecycle guards control whether editing is offered. Entering edit mode creates a draft; Cancel restores the baseline. Saving validates and commits the graph, then refreshes related views. Individual fields and custom form nodes can opt out of read presentation when they only make sense while editing.

Set `recordHeader` to a `BeakRecordTemplate` when the record needs a title, inline status badges and identity metadata above its layout. Beak uses the existing live draft and infers the header's relationship loads with those of the body. `recordActions` appear beside the form's Edit, Save or Cancel controls. Their optional `roles` select list/read/create/edit presentations and follow live mode changes, so print actions can remain in read headers while editing focuses on saving.

```dart title="examples/clean_beak_config/lib/resources/users/user_resource.dart"
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
```

## Continue reading

- [Forms](form-screens.md)
- [Formatting](../models/semantic-fields.md)
