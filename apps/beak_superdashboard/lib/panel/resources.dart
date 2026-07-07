import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

import 'details/details.dart';
import 'forms/calendar_event_form.dart';

/// Every model surfaced as a navigable resource, grouped into sidebar
/// sections. Declaring a resource yields its full list/create/show/edit CRUD;
/// a couple opt into extra view modes (a kanban board, a calendar).
List<BeakResource> buildResources() => const [
  // ── Store ────────────────────────────────────────────────────────────────
  BeakResource(
    model: ProductModel(),
    icon: BeakIconToken(OiIcons.package),
    section: 'Store',
    detail: productLayout,
    formLayout: productLayout,
    filters: [
      BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
      BeakTextFilter(column: ProductColumns.name, label: 'Name'),
    ],
  ),
  BeakResource(
    model: CategoryModel(),
    icon: BeakIconToken(OiIcons.folderTree),
    section: 'Store',
    detail: categoryDetail,
  ),
  BeakResource(
    model: TagModel(),
    icon: BeakIconToken(OiIcons.tag),
    section: 'Store',
    detail: tagDetail,
  ),
  BeakResource(
    model: OrderModel(),
    icon: BeakIconToken(OiIcons.shoppingCart),
    section: 'Store',
    detail: orderLayout,
    formLayout: orderLayout,
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
    detail: transactionDetail,
    filters: [
      BeakSelectFilter(column: TransactionColumns.status, label: 'Status'),
    ],
  ),

  // ── People ─────────────────────────────────────────────────────────────────
  BeakResource(
    model: UserModel(),
    icon: BeakIconToken(OiIcons.users),
    section: 'People',
    detail: userDetail,
    filters: [
      BeakSelectFilter(column: UserColumns.role, label: 'Role'),
      BeakSelectFilter(column: UserColumns.status, label: 'Status'),
    ],
  ),
  BeakResource(
    model: TeamMemberModel(),
    icon: BeakIconToken(OiIcons.userCheck),
    section: 'People',
    detail: teamMemberDetail,
  ),
  BeakResource(
    model: ActivityModel(),
    icon: BeakIconToken(OiIcons.activity),
    section: 'People',
    detail: activityDetail,
  ),
  BeakResource(
    model: SkillModel(),
    icon: BeakIconToken(OiIcons.award),
    section: 'People',
    detail: skillDetail,
  ),

  // ── Projects ──────────────────────────────────────────────────────────────
  BeakResource(
    model: CalendarEventModel(),
    icon: BeakIconToken(OiIcons.calendar),
    section: 'Projects',
    detail: calendarEventDetail,
    formSteps: calendarEventFormSteps,
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
    detail: cardDetail,
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
    detail: boardDetail,
  ),
  BeakResource(
    model: InvoiceModel(),
    icon: BeakIconToken(OiIcons.fileText),
    section: 'Projects',
    detail: invoiceDetail,
    filters: [BeakSelectFilter(column: InvoiceColumns.status, label: 'Status')],
  ),

  // ── Content ──────────────────────────────────────────────────────────────
  BeakResource(
    model: PricingPlanModel(),
    icon: BeakIconToken(OiIcons.dollarSign),
    section: 'Content',
    detail: pricingPlanDetail,
  ),
  BeakResource(
    model: FaqModel(),
    icon: BeakIconToken(OiIcons.helpCircle),
    section: 'Content',
    detail: faqDetail,
  ),
  BeakResource(
    model: MediaAssetModel(),
    icon: BeakIconToken(OiIcons.image),
    section: 'Content',
    detail: mediaAssetDetail,
  ),
  BeakResource(
    model: NotificationModel(),
    icon: BeakIconToken(OiIcons.bell),
    section: 'Content',
    detail: notificationDetail,
  ),
];
