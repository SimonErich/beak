import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'models/models.dart';
import 'pages/operations.dart';
import 'theme/gabel_tokens.dart';

/// Each workspace has a compact rail destination and contextual navigation.
final foodioNavigation = BeakNavigation(
  searchPlaceholder: 'Search orders, customers, invoices…',
  showThemeToggle: false,
  currentRecordBranch: true,
  searchShortcut: ['⌘', 'K'],
  userMenu: const Builder(builder: _accountMenu),
  leading: const Padding(
    padding: EdgeInsets.only(top: 4, bottom: 8),
    child: SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF393B47),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Center(
          child: Text(
            'G',
            style: TextStyle(
              color: GabelLight.railInk,
              fontSize: 20,
              fontVariations: [
                FontVariation('wght', 640),
                FontVariation('wdth', 106),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  sections: [
    BeakNavigationSection(
      key: 'home',
      label: 'Home',
      icon: OiIcons.layoutDashboard,
      items: [BeakNavigationItem.screen(overviewScreen, label: 'Overview')],
    ),
    BeakNavigationSection(
      key: 'orders',
      label: 'Orders',
      icon: OiIcons.shoppingBag,
      items: [
        const BeakNavigationItem.resource(
          OrderModel(),
          showCount: true,
          recordLabelMonospace: true,
        ),
        const BeakNavigationItem.resource(DeliverySlotModel()),
        BeakNavigationItem.screen(kitchenScreen),
        const BeakNavigationItem.resource(ComplaintModel(), showCount: true),
      ],
    ),
    const BeakNavigationSection(
      key: 'people',
      label: 'People',
      icon: OiIcons.users,
      items: [
        BeakNavigationItem.resource(CustomerModel()),
        BeakNavigationItem.resource(OrganizationModel()),
        BeakNavigationItem.resource(DeliveryProfileModel()),
        BeakNavigationItem.resource(StaffMemberModel()),
      ],
    ),
    const BeakNavigationSection(
      key: 'kitchen',
      label: 'Kitchen',
      icon: OiIcons.chefHat,
      items: [
        BeakNavigationItem.resource(DishModel()),
        BeakNavigationItem.resource(MenuPlanModel()),
      ],
    ),
    const BeakNavigationSection(
      key: 'finance',
      label: 'Finance',
      icon: OiIcons.receipt,
      items: [
        BeakNavigationItem.resource(InvoiceModel()),
        BeakNavigationItem.resource(VoucherModel()),
        BeakNavigationItem.resource(BudgetAccountModel()),
      ],
    ),
    const BeakNavigationSection(
      key: 'settings',
      bottom: true,
      label: 'Settings',
      icon: OiIcons.settings,
      items: [
        BeakNavigationItem.resource(DeliveryLocationModel()),
        BeakNavigationItem.resource(AppSettingModel()),
        BeakNavigationItem.resource(NotificationModel()),
      ],
    ),
  ],
);

Widget _accountMenu(BuildContext context) => OiUserMenu(
  label: 'Marie Novak account menu',
  userName: 'Marie Novak',
  avatar: const OiAvatar(
    semanticLabel: 'Marie Novak',
    initials: 'MN',
    size: OiAvatarSize.sm,
    backgroundColor: Color(0xFFE5F5FA),
    foregroundColor: Color(0xFF26708C),
  ),
  items: [
    OiMenuItem(
      label: 'Staff profiles',
      icon: OiIcons.users,
      onTap: () => context.go(BeakRoutes.list(const StaffMemberModel().table)),
    ),
    OiMenuItem(
      label: 'Settings',
      icon: OiIcons.settings,
      onTap: () => context.go(BeakRoutes.list(const AppSettingModel().table)),
    ),
  ],
);

/// Help uses the shared dialog; notifications and account links use panel data.
List<Widget> foodioShellActions(BuildContext context) => [
  OiButton.icon(
    icon: OiIcons.circleHelp,
    label: 'Order workspace help',
    onTap: () => showOiDialog<void>(
      context,
      semanticLabel: 'Order workspace help',
      builder: (context, close) => OiDialog.alert(
        label: 'Order workspace help',
        title: 'Working with orders',
        content: const OiLabel.body(
          'Search across orders, customers and invoices with Ctrl-K or Cmd-K. '
          'Use presets to choose a workspace, then preview filters before applying them. '
          'Open an order to review its delivery, payment and activity history. '
          'Changes are validated and saved together; uncertain saves can be checked without repeating the command.',
        ),
        onClose: close,
        actions: [OiButton.primary(label: 'Got it', onTap: close)],
      ),
    ),
  ),
];
