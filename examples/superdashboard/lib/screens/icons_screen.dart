import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

/// One entry in the curated icon reference.
typedef _Icon = (BeakIconToken, String);

/// A representative slice of the `OiIcons` (Lucide) set — the panel's icon
/// reference, rendered declaratively through `BeakIconGalleryBlock`.
const List<_Icon> _icons = [
  (BeakIconToken(OiIcons.home), 'home'),
  (BeakIconToken(OiIcons.user), 'user'),
  (BeakIconToken(OiIcons.users), 'users'),
  (BeakIconToken(OiIcons.settings), 'settings'),
  (BeakIconToken(OiIcons.bell), 'bell'),
  (BeakIconToken(OiIcons.search), 'search'),
  (BeakIconToken(OiIcons.star), 'star'),
  (BeakIconToken(OiIcons.heart), 'heart'),
  (BeakIconToken(OiIcons.download), 'download'),
  (BeakIconToken(OiIcons.upload), 'upload'),
  (BeakIconToken(OiIcons.trash2), 'trash2'),
  (BeakIconToken(OiIcons.pencil), 'pencil'),
  (BeakIconToken(OiIcons.plus), 'plus'),
  (BeakIconToken(OiIcons.check), 'check'),
  (BeakIconToken(OiIcons.calendar), 'calendar'),
  (BeakIconToken(OiIcons.mail), 'mail'),
  (BeakIconToken(OiIcons.messageCircle), 'messageCircle'),
  (BeakIconToken(OiIcons.folder), 'folder'),
  (BeakIconToken(OiIcons.fileText), 'fileText'),
  (BeakIconToken(OiIcons.image), 'image'),
  (BeakIconToken(OiIcons.barChart2), 'barChart2'),
  (BeakIconToken(OiIcons.layoutDashboard), 'layoutDashboard'),
  (BeakIconToken(OiIcons.creditCard), 'creditCard'),
  (BeakIconToken(OiIcons.shoppingCart), 'shoppingCart'),
  (BeakIconToken(OiIcons.package), 'package'),
  (BeakIconToken(OiIcons.tag), 'tag'),
  (BeakIconToken(OiIcons.activity), 'activity'),
  (BeakIconToken(OiIcons.bookmark), 'bookmark'),
  (BeakIconToken(OiIcons.camera), 'camera'),
  (BeakIconToken(OiIcons.clock), 'clock'),
  (BeakIconToken(OiIcons.globe), 'globe'),
  (BeakIconToken(OiIcons.lock), 'lock'),
];

/// The icons reference page — a named grid of the design-system icon set.
// --8<-- [start:buildIconsScreen]
BeakScreen buildIconsScreen() => BeakScreen(
  path: '/icons',
  title: 'Icons',
  icon: const BeakIconToken(OiIcons.star),
  section: 'Showcase',
  body: BeakCardBlock(
    title: 'Lucide icons',
    child: BeakIconGalleryBlock(
      columns: 6,
      items: [
        for (final (icon, label) in _icons)
          BeakIconGalleryItem(icon: icon, label: label),
      ],
    ),
  ),
);

// --8<-- [end:buildIconsScreen]
