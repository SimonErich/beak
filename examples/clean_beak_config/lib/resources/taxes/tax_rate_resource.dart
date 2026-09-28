import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/tax_rate.dart';

/// Configurable exclusive tax rates, shared by catalog and invoice lines.
final class TaxRateResource extends BeakResource {
  /// Creates the tax-rate section.
  TaxRateResource()
    : super(
        model: const TaxRateModel(),
        title: 'Tax rates',
        icon: const BeakIconToken(OiIcons.percent),
        navigationGroup: 'Settings',
        navigationRank: 10,
        globalSearchSources: [TaxRateModel.name, TaxRateModel.ratePercent],
        filters: [
          TaxRateModel.active.boolFilter(label: 'Available'),
          TaxRateModel.ratePercent.numberRangeFilter(label: 'Rate (%)'),
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
                  title: 'Exclusive tax',
                  description:
                      'Tax is added to discounted net amounts. Saved invoices retain their original rates.',
                  children: [
                    TaxRateModel.name.inputText(),
                    TaxRateModel.ratePercent.inputNumber(label: 'Rate (%)'),
                    TaxRateModel.active.inputToggle(
                      label: 'Available for new sales',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}
