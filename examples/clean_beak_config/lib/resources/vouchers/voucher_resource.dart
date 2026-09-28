import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/voucher.dart';
import 'screens/voucher_form.dart';

/// Reusable vouchers with explicit limits and scheduling.
final class VoucherResource extends BeakResource {
  /// Creates the vouchers section.
  VoucherResource()
    : super(
        model: const VoucherModel(),
        title: 'Vouchers',
        icon: const BeakIconToken(OiIcons.ticket),
        navigationGroup: 'Sales',
        navigationRank: 2,
        globalSearchSources: [VoucherModel.code, VoucherModel.name],
        filters: [
          VoucherModel.kind.selectFilter(),
          VoucherModel.active.boolFilter(),
          VoucherModel.endsAt.dateRangeFilter(label: 'Expiry'),
        ],
        screens: [
          BeakTableScreen(
            fields: [
              VoucherModel.code,
              VoucherModel.name,
              VoucherModel.kind,
              VoucherModel.value,
              VoucherModel.active,
              VoucherModel.endsAt,
            ],
          ),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: voucherForm(),
          ),
        ],
      );
}
