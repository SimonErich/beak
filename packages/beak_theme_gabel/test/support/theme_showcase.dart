import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// A small panel-like composition that touches the components the Gabel
/// theme styles most: sidebar, card, buttons, input, badges and a table.
Widget themeShowcase() => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(
      width: 220,
      child: OiSidebar(
        label: 'Main',
        width: 220,
        selectedId: 'orders',
        onSelect: (_) {},
        sections: const [
          OiSidebarSection(
            collapsible: false,
            items: [
              OiSidebarItem(
                id: 'overview',
                label: 'Overview',
                icon: OiIcons.layoutDashboard,
              ),
              OiSidebarItem(
                id: 'orders',
                label: 'Orders',
                icon: OiIcons.receipt,
                badgeCount: 12,
              ),
              OiSidebarItem(
                id: 'customers',
                label: 'Customers',
                icon: OiIcons.users,
              ),
            ],
          ),
        ],
      ),
    ),
    Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: OiCard(
          title: const OiLabel.h4('Orders'),
          subtitle: const OiLabel.small('Today'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: OiTextInput(
                      label: 'Customer',
                      placeholder: 'Search by name',
                    ),
                  ),
                  const SizedBox(width: 8),
                  OiButton.primary(label: 'Create', onTap: () {}),
                  const SizedBox(width: 8),
                  OiButton.secondary(label: 'Export', onTap: () {}),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                spacing: 8,
                children: [
                  OiBadge.soft(label: 'Confirmed', color: OiBadgeColor.success),
                  OiBadge.soft(
                    label: 'In kitchen',
                    color: OiBadgeColor.warning,
                  ),
                  OiBadge.soft(label: 'Refused', color: OiBadgeColor.error),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: OiTable<List<String>>(
                  label: 'Orders',
                  showStatusBar: false,
                  rows: const [
                    ['#1042', 'Tobias Wagner', 'EUR 41.31'],
                    ['#1043', 'Mira Hofer', 'EUR 48.60'],
                    ['#1044', 'Jonas Reiter', 'EUR 12.00'],
                  ],
                  columns: [
                    OiTableColumn(
                      id: 'id',
                      header: 'Order',
                      width: 80,
                      valueGetter: (row) => row[0],
                    ),
                    OiTableColumn(
                      id: 'customer',
                      header: 'Customer',
                      valueGetter: (row) => row[1],
                    ),
                    OiTableColumn(
                      id: 'total',
                      header: 'Total',
                      width: 100,
                      textAlign: TextAlign.end,
                      valueGetter: (row) => row[2],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ],
);
