import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

final class _ProductModel extends BeakModel {
  const _ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];

  @override
  BeakModelLabels get labels =>
      const BeakModelLabels(other: {'de': 'Produkte', 'en': 'Products'});
}

/// The host app's own copy, as gen-l10n would generate it.
final class _ShopStrings {
  const _ShopStrings(this.locale);

  final Locale locale;

  static _ShopStrings of(BuildContext context) =>
      Localizations.of<_ShopStrings>(context, _ShopStrings)!;

  String get catalog => locale.languageCode == 'de' ? 'Katalog' : 'Catalog';
}

final class _ShopDelegate extends LocalizationsDelegate<_ShopStrings> {
  const _ShopDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<_ShopStrings> load(Locale locale) =>
      SynchronousFuture(_ShopStrings(locale));

  @override
  bool shouldReload(_ShopDelegate old) => false;
}

void main() {
  tearDown(() => BeakLabels.language = null);

  Future<void> pump(WidgetTester tester, Locale locale) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? pluralWhileBuilding;
    await tester.pumpWidget(
      BeakLocalizedPanel(
        locale: locale,
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: const [_ShopDelegate()],
        dataSource: FakeDataSource(models: const [_ProductModel()]),
        config: (context) {
          pluralWhileBuilding = const _ProductModel().pluralLabel;
          return BeakPanelConfig(
            title: 'Shop',
            resources: [BeakResource.standard(const _ProductModel())],
            navigation: BeakNavigation(
              sections: [
                BeakNavigationSection(
                  key: 'catalog',
                  label: _ShopStrings.of(context).catalog,
                  icon: OiIcons.package,
                  items: const [BeakNavigationItem.resource(_ProductModel())],
                ),
              ],
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
      pluralWhileBuilding,
      locale.languageCode == 'de' ? 'Produkte' : 'Products',
    );
  }

  testWidgets('the config builder reads the app copy from its context', (
    tester,
  ) async {
    await pump(tester, const Locale('de'));

    expect(find.text('Katalog'), findsWidgets);
    expect(find.text('Produkte'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another locale builds the config in that language', (
    tester,
  ) async {
    await pump(tester, const Locale('en'));

    expect(find.text('Catalog'), findsWidgets);
    expect(find.text('Products'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
