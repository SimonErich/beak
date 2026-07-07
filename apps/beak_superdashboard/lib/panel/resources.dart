import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

/// Every model surfaced as a navigable resource, grouped into sidebar
/// sections. Declaring a resource yields its full list/create/show/edit CRUD;
/// a couple opt into extra view modes (a kanban board, a calendar).
List<BeakResource> buildResources() => const [
  // ── Store ────────────────────────────────────────────────────────────────
  BeakResource(
    model: ProductModel(),
    icon: BeakIconToken(OiIcons.package),
    section: 'Store',
    filters: [
      BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
      BeakTextFilter(column: ProductColumns.name, label: 'Name'),
    ],
  ),
  BeakResource(
    model: CategoryModel(),
    icon: BeakIconToken(OiIcons.folderTree),
    section: 'Store',
  ),
  BeakResource(
    model: TagModel(),
    icon: BeakIconToken(OiIcons.tag),
    section: 'Store',
  ),
  BeakResource(
    model: OrderModel(),
    icon: BeakIconToken(OiIcons.shoppingCart),
    section: 'Store',
    filters: [
      BeakSelectFilter(column: OrderColumns.status, label: 'Status'),
      BeakSelectFilter(column: OrderColumns.source, label: 'Source'),
    ],
    viewModes: [
      BeakTableView(),
      BeakKanbanView(
        groupField: OrderColumns.status,
        titleField: OrderColumns.reference,
        subtitleField: OrderColumns.total,
      ),
    ],
  ),
  BeakResource(
    model: TransactionModel(),
    icon: BeakIconToken(OiIcons.creditCard),
    section: 'Store',
    filters: [
      BeakSelectFilter(column: TransactionColumns.status, label: 'Status'),
    ],
  ),

  // ── People ─────────────────────────────────────────────────────────────────
  BeakResource(
    model: UserModel(),
    icon: BeakIconToken(OiIcons.users),
    section: 'People',
    filters: [
      BeakSelectFilter(column: UserColumns.role, label: 'Role'),
      BeakSelectFilter(column: UserColumns.status, label: 'Status'),
    ],
  ),
  BeakResource(
    model: TeamMemberModel(),
    icon: BeakIconToken(OiIcons.userCheck),
    section: 'People',
  ),
  BeakResource(
    model: ActivityModel(),
    icon: BeakIconToken(OiIcons.activity),
    section: 'People',
  ),
  BeakResource(
    model: SkillModel(),
    icon: BeakIconToken(OiIcons.award),
    section: 'People',
  ),

  // ── Projects ──────────────────────────────────────────────────────────────
  BeakResource(
    model: CalendarEventModel(),
    icon: BeakIconToken(OiIcons.calendar),
    section: 'Projects',
    viewModes: [
      BeakTableView(),
      BeakCalendarView(
        titleField: CalendarEventColumns.title,
        startField: CalendarEventColumns.startAt,
        endField: CalendarEventColumns.endAt,
        allDayField: CalendarEventColumns.allDay,
      ),
    ],
  ),
  BeakResource(
    model: CardModel(),
    icon: BeakIconToken(OiIcons.trello),
    section: 'Projects',
    filters: [
      BeakSelectFilter(column: CardColumns.priority, label: 'Priority'),
    ],
    viewModes: [
      BeakTableView(),
      BeakKanbanView(
        groupField: CardColumns.priority,
        titleField: CardColumns.title,
      ),
    ],
  ),
  BeakResource(
    model: BoardModel(),
    icon: BeakIconToken(OiIcons.layoutGrid),
    section: 'Projects',
  ),
  BeakResource(
    model: InvoiceModel(),
    icon: BeakIconToken(OiIcons.fileText),
    section: 'Projects',
    filters: [BeakSelectFilter(column: InvoiceColumns.status, label: 'Status')],
  ),

  // ── Content ──────────────────────────────────────────────────────────────
  BeakResource(
    model: PricingPlanModel(),
    icon: BeakIconToken(OiIcons.dollarSign),
    section: 'Content',
  ),
  BeakResource(
    model: FaqModel(),
    icon: BeakIconToken(OiIcons.helpCircle),
    section: 'Content',
  ),
  BeakResource(
    model: MediaAssetModel(),
    icon: BeakIconToken(OiIcons.image),
    section: 'Content',
  ),
  BeakResource(
    model: NotificationModel(),
    icon: BeakIconToken(OiIcons.bell),
    section: 'Content',
  ),
];
