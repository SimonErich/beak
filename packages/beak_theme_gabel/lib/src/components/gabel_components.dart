import 'package:obers_ui/obers_ui.dart';

import '../gabel_palette.dart';
import '../gabel_text.dart';
import 'gabel_choice_components.dart';
import 'gabel_data_components.dart';
import 'gabel_display_components.dart';
import 'gabel_input_components.dart';
import 'gabel_shell_components.dart';

/// Every Gabel component theme of [p], assembled from the files that each own
/// one area of the design.
OiComponentThemes gabelComponents(GabelPalette p, GabelText text) =>
    OiComponentThemes(
      sheet: gabelSheetTheme(p),
      icon: gabelIconTheme(),
      appShell: gabelAppShellTheme(p, text),
      navigationRail: gabelNavigationRailTheme(p),
      stepper: gabelStepperTheme(p),
      sidebar: gabelSidebarTheme(p, text),
      card: gabelCardTheme(p),
      table: gabelTableTheme(p, text),
      capacity: gabelCapacityTheme(p, text),
      bulkBar: gabelBulkBarTheme(text),
      actionBar: gabelActionBarTheme(),
      pagination: gabelPaginationTheme(p, text),
      chart: gabelChartTheme(p, text),
      badge: gabelBadgeTheme(text),
      banner: gabelBannerTheme(p),
      fieldDisplay: gabelFieldDisplayTheme(p, text),
      checkbox: gabelCheckboxTheme(p),
      radio: gabelRadioTheme(p, text),
      radioTile: gabelRadioTileTheme(p, text),
      tabs: gabelTabsTheme(p, text),
      switchTheme: gabelSwitchTheme(p),
      segmentedControl: gabelSegmentedControlTheme(p, text),
      button: gabelButtonTheme(p, text),
      textInput: gabelTextInputTheme(p, text),
      searchTrigger: gabelSearchTriggerTheme(p, text),
    );
