import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/foodio_clock.dart';
import '../../../models/models.dart';
import 'order_identity_tokens.dart';
import 'order_dish_presentations.dart';

/// Live review addresses follow explicit overrides; saved views use the order's
/// immutable delivery snapshot even after a location's address changes.
BeakValueBinding<String> orderAddress({bool saved = false}) =>
    BeakValueBinding<String>.computed(
      dependencies: [
        OrderModel.addressOverride,
        OrderModel.street,
        OrderModel.postalCode,
        OrderModel.city,
        OrderModel.location.street,
        OrderModel.location.postalCode,
        OrderModel.location.city,
      ],
      maxLines: null,
      compute: (state) {
        final snapshot =
            saved || state.read(OrderModel.addressOverride) == true;
        final street = snapshot
            ? state.read(OrderModel.street)
            : state.read(OrderModel.location.street);
        final postal = snapshot
            ? state.read(OrderModel.postalCode)
            : state.read(OrderModel.location.postalCode);
        final city = snapshot
            ? state.read(OrderModel.city)
            : state.read(OrderModel.location.city);
        return [
          street,
          [postal, city].whereType<String>().join(' '),
        ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
      },
    );

/// The compact allergen codes remain a snapshot; presentation turns them into tags.
BeakValueBinding<List<String>> allergenBadges(BeakScalarField<String> field) =>
    BeakValueBinding<List<String>>.computed(
      dependencies: [field],
      compute: (row) => (row.read(field) ?? '')
          .split(',')
          .map((code) => code.trim())
          .where((code) => code.isNotEmpty)
          .toList(),
      badge: true,
      badgeToken: true,
      itemTooltip: (code, _) => allergenLabel(code.toString()),
    );

/// Compact customer identity used by the customer search.
BeakRecordTemplate customerIdentity() => BeakRecordTemplate(
  title: BeakValueBinding.field(
    CustomerModel.name,
    textStyle: const TextStyle(fontWeight: FontWeight.w500),
  ),
  subtitle: [
    BeakValueBinding.field(CustomerModel.email),
    BeakValueBinding.field(CustomerModel.phone),
  ],
  trailing: [
    BeakValueBinding<String>.computed(
      dependencies: [CustomerModel.profiles],
      compute: (row) {
        final count = row.read(CustomerModel.profiles)?.length ?? 0;
        return '$count ${count == 1 ? 'profile' : 'profiles'}';
      },
      textStyle: const TextStyle(
        fontSize: 12,
        height: 4 / 3,
        fontWeight: FontWeight.w500,
      ),
      color: BeakColor.muted,
    ),
  ],
  avatar: true,
  avatarPalette: identityPalette,
  avatarTone: BeakValueBinding<BeakAvatarTone>.computed(
    dependencies: const [],
    compute: (_) => identityPalette[1],
  ),
  identityGap: 12,
  textGap: 0,
);

/// A profile exposes its organization, address and billing defaults.
BeakRecordTemplate profileIdentity() => BeakRecordTemplate(
  title: BeakValueBinding.field(
    DeliveryProfileModel.name,
    textStyle: const TextStyle(fontWeight: FontWeight.w500),
  ),
  avatar: true,
  avatarRadius: const BorderRadius.all(Radius.circular(6)),
  avatarPalette: identityPalette,
  avatarTone: BeakValueBinding<BeakAvatarTone>.computed(
    dependencies: [DeliveryProfileModel.kind],
    compute: (row) => row.read(DeliveryProfileModel.kind) == 'company'
        ? identityPalette[1]
        : identityPalette[2],
  ),
  iconSize: 32,
  identityGap: 12,
  textGap: 2,
  identityMinHeight: 48,
  footnoteSpacing: 14,
  inlineSubtitle: true,
  icon: BeakValueBinding<IconData>.computed(
    dependencies: [DeliveryProfileModel.kind],
    compute: (row) =>
        row.read(DeliveryProfileModel.kind) == 'company' ? null : OiIcons.house,
  ),
  subtitle: [
    BeakValueBinding<String>.computed(
      dependencies: [
        DeliveryProfileModel.role,
        DeliveryProfileModel.kind,
        DeliveryProfileModel.customer.name,
      ],
      compute: (row) => row.read(DeliveryProfileModel.kind) == 'company'
          ? row.read(DeliveryProfileModel.role)
          : '${(row.read(DeliveryProfileModel.customer.name) ?? 'Customer').split(' ').first} pays personally',
    ),
    BeakValueBinding<String>.computed(
      dependencies: [DeliveryProfileModel.isDefault],
      visibleIf: (row) => row.read(DeliveryProfileModel.isDefault) == true,
      compute: (_) => 'Default',
      badge: true,
      color: BeakColor.info,
    ),
  ],
  details: [
    BeakValueBinding<String>.computed(
      dependencies: [
        DeliveryProfileModel.paymentMode,
        DeliveryProfileModel.customer.paymentMethods,
      ],
      iconFor: (row) => row.read(DeliveryProfileModel.kind) == 'company'
          ? OiIcons.landmark
          : OiIcons.creditCard,
      maxLines: 2,
      compute: (row) => switch (row.read(DeliveryProfileModel.paymentMode)) {
        'monthlyInvoice' => 'Company invoice · monthly collective',
        'weeklyInvoice' => 'Company invoice · weekly collective',
        final mode => _profilePayment(row, mode),
      },
    ),
    BeakValueBinding<String>.computed(
      dependencies: [
        DeliveryProfileModel.location.method,
        DeliveryProfileModel.location.handover,
      ],
      icon: OiIcons.package,
      maxLines: 2,
      compute: (row) => [
        row.read(DeliveryProfileModel.location.method) == 'office'
            ? 'Office delivery'
            : 'Home delivery',
        row.read(DeliveryProfileModel.location.handover),
      ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
    ),
    BeakValueBinding<List<Object?>>.computed(
      dependencies: [
        DeliveryProfileModel.location.routeCode,
        DeliveryProfileModel.preferredDeliveryStart,
        DeliveryProfileModel.preferredDeliveryEnd,
      ],
      iconFor: (row) =>
          (row.read(DeliveryProfileModel.location.routeCode) ?? '')
              .toLowerCase()
              .startsWith('bike')
          ? OiIcons.bike
          : OiIcons.truck,
      compute: (row) => [
        row.read(DeliveryProfileModel.location.routeCode),
        row.read(DeliveryProfileModel.preferredDeliveryStart),
        row.read(DeliveryProfileModel.preferredDeliveryEnd),
      ],
      display: (values, format) {
        final route = values?[0] as String? ?? '';
        final start = values?[1] as BeakTime?;
        final end = values?[2] as BeakTime?;
        final window = start == null || end == null
            ? ''
            : ' · ${format.clockTime(start)}–${format.clockTime(end)}';
        return (route.toLowerCase().startsWith('bike')
                ? 'Bike courier'
                : 'Cooled van · Route $route') +
            window;
      },
    ),
    BeakValueBinding<String>.computed(
      dependencies: [
        DeliveryProfileModel.location.street,
        DeliveryProfileModel.location.postalCode,
        DeliveryProfileModel.location.city,
      ],
      icon: OiIcons.mapPin,
      maxLines: 2,
      compute: (row) =>
          '${row.read(DeliveryProfileModel.location.street) ?? ''}, '
          '${row.read(DeliveryProfileModel.location.postalCode) ?? ''} '
          '${row.read(DeliveryProfileModel.location.city) ?? ''}',
    ),
    BeakValueBinding<String>.computed(
      dependencies: [DeliveryProfileModel.kind, DeliveryProfileModel.budgets],
      icon: OiIcons.wallet,
      maxLines: 2,
      compute: (row) {
        if (row.read(DeliveryProfileModel.kind) != 'company') {
          return 'No company budget';
        }
        final period = const FoodioClock().today.toString().substring(0, 7);
        for (final record
            in row.read(DeliveryProfileModel.budgets) ?? <BeakRecord>[]) {
          final budget = record.asBudgetAccount;
          if (budget.period != period) continue;
          final allowance = budget.allowanceCents;
          final remaining =
              allowance - budget.reservedCents - budget.spentCents;
          return '€${BeakDecimal(remaining, scale: 2)} left of '
              '€${BeakDecimal(allowance, scale: 2)} this month';
        }
        return 'No budget set for this month';
      },
    ),
  ],
  footnote: BeakValueBinding<String>.computed(
    dependencies: [
      DeliveryProfileModel.kind,
      DeliveryProfileModel.approvalThresholdCents,
      DeliveryProfileModel.approver.name,
      DeliveryProfileModel.location.instructions,
    ],
    iconFor: (row) => row.read(DeliveryProfileModel.kind) == 'company'
        ? OiIcons.info
        : OiIcons.messageSquare,
    maxLines: null,
    compute: (row) => row.read(DeliveryProfileModel.kind) == 'company'
        ? 'Orders over €${BeakDecimal(row.read(DeliveryProfileModel.approvalThresholdCents) ?? 0, scale: 2)} '
              'need approval by ${row.read(DeliveryProfileModel.approver.name) ?? 'the company approver'}'
        : row.read(DeliveryProfileModel.location.instructions),
    visibleIf: (row) =>
        row.read(DeliveryProfileModel.kind) == 'company' ||
        (row.read(DeliveryProfileModel.location.instructions)?.isNotEmpty ??
            false),
  ),
);

/// Catalog options combine a dish identity with its priced variant.
BeakRecordTemplate variantIdentity() => BeakRecordTemplate(
  identityGap: 12,
  identityMinHeight: 48,
  textGap: 4,
  title: BeakValueBinding.field(
    DishVariantModel.dish.name,
    textStyle: const TextStyle(fontWeight: FontWeight.w500),
    maxLines: 2,
  ),
  inlineSubtitle: true,
  icon: BeakValueBinding<IconData>.computed(
    dependencies: [DishVariantModel.dish.category, DishVariantModel.dish.diet],
    compute: (row) => dishIcon(
      row.read(DishVariantModel.dish.category),
      row.read(DishVariantModel.dish.diet),
    ),
  ),
  avatarPalette: identityPalette,
  avatarTone: dishToneBinding(
    DishVariantModel.dish.category,
    DishVariantModel.dish.diet,
  ),
  subtitle: [
    BeakValueBinding<String>.computed(
      dependencies: [
        DishVariantModel.dish.category,
        DishVariantModel.dish.diet,
      ],
      compute: (row) => switch (row.read(DishVariantModel.dish.category)) {
        'Soups' => 'Soup',
        'Desserts' => 'Dessert',
        'Mains' =>
          (row.read(DishVariantModel.dish.diet) ?? '').contains('vegan')
              ? 'Vegan main'
              : (row.read(DishVariantModel.dish.diet) ?? '').contains(
                  'vegetarian',
                )
              ? 'Vegetarian main'
              : 'Classic main',
        final category => category,
      },
    ),
    allergenBadges(DishVariantModel.dish.allergens),
    BeakValueBinding<String>.computed(
      dependencies: [
        DishVariantModel.dish.diet,
        DishVariantModel.dish.category,
      ],
      compute: (_) => 'Vegetarian',
      visibleIf: (row) =>
          row.read(DishVariantModel.dish.category) == 'Soups' &&
          (row.read(DishVariantModel.dish.diet) ?? '')
              .split(',')
              .map((tag) => tag.trim())
              .contains('vegetarian'),
      badge: true,
      icon: OiIcons.leaf,
      color: BeakColor.info,
    ),
    BeakValueBinding<String>.computed(
      dependencies: [DishVariantModel.dish.diet],
      compute: (_) => 'Mildly spicy',
      visibleIf: (row) => (row.read(DishVariantModel.dish.diet) ?? '')
          .split(',')
          .map((tag) => tag.trim())
          .contains('mildly spicy'),
      badge: true,
      icon: OiIcons.flame,
      color: BeakColor.warning,
    ),
  ],
);

/// Operational state combines order, approval and collection status.
String _profilePayment(BeakDraftReader row, String? mode) {
  final methods =
      (row.read(DeliveryProfileModel.customer.paymentMethods) ??
              const <BeakRecord>[])
          .map((record) => record.asPaymentMethod)
          .where((method) => method.active)
          .toList();
  final matching = methods.where((method) => method.kind == mode).toList();
  final primary =
      matching.where((method) => method.isDefault).firstOrNull ??
      matching.firstOrNull;
  if (primary == null) return paymentLabels[mode] ?? 'Private payment';
  final alternatives = methods
      .where((method) => method.id != primary.id && method.kind != primary.kind)
      .map((method) => method.name);
  return [
    primary.name,
    for (final alternative in alternatives) '$alternative as backup',
  ].join(' · ');
}
