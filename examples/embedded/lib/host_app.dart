import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import 'beak/panel.g.dart';
import 'models/ticket.dart';

/// The host application's Flutter app — not a Beak panel.
///
/// It has its own shell, its own navigation and its own screens. One of them
/// happens to render a Beak block: [BeakBlockHost] draws a data table against
/// the same models and the same API the admin panel uses, so support staff see
/// the ticket queue without leaving the product.
///
/// The only Beak wiring is [registerBeakDependencies], which is what gives the
/// blocks their data source.
// --8<-- [start:HostApp]
final class HostApp extends StatelessWidget {
  /// Creates the host app; [dataSource] injects a fake in widget tests.
  HostApp({this.dataSource, super.key}) {
    registerBeakDependencies(config: buildBeakPanel(), dataSource: dataSource);
  }

  /// Test seam replacing the HTTP-backed data source.
  final BeakDataSource? dataSource;

  @override
  Widget build(BuildContext context) =>
      OiApp(theme: OiThemeData.light(), home: const _SupportScreen());
}
// --8<-- [end:HostApp]

class _SupportScreen extends StatelessWidget {
  const _SupportScreen();

  @override
  Widget build(BuildContext context) => OiColumn(
    breakpoint: context.breakpoint,
    children: const [
      OiPageHeader(title: 'Support'),
      Expanded(
        child: BeakBlockHost(
          block: BeakTableBlock(
            model: TicketModel(),
            columns: [TicketColumns.subject, TicketColumns.status],
          ),
        ),
      ),
    ],
  );
}
