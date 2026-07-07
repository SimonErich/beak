/// The shared Beak model definitions of the superdashboard, grouped by
/// domain and declared once — consumed by both the Shelf server (auto CRUD)
/// and the Flutter panel (resource pages).
library;

import 'package:beak_core/beak_core.dart';

import 'analytics/country_stat.dart';
import 'analytics/purchase_source.dart';
import 'analytics/time_series_point.dart';
import 'calendar/calendar_event.dart';
import 'calendar/event_category.dart';
import 'chat/chat_attachment.dart';
import 'chat/chat_message.dart';
import 'chat/conversation.dart';
import 'chat/conversation_participant.dart';
import 'commerce/category.dart';
import 'commerce/order.dart';
import 'commerce/order_item.dart';
import 'commerce/product.dart';
import 'commerce/tag.dart';
import 'commerce/transaction.dart';
import 'email/email.dart';
import 'email/email_attachment.dart';
import 'email/mail_folder.dart';
import 'email/mail_label.dart';
import 'faq/faq.dart';
import 'faq/faq_category.dart';
import 'files/file_folder.dart';
import 'files/file_share.dart';
import 'files/managed_file.dart';
import 'files/storage_account.dart';
import 'invoices/invoice.dart';
import 'invoices/invoice_item.dart';
import 'kanban/board.dart';
import 'kanban/board_column.dart';
import 'kanban/card.dart';
import 'kanban/card_label.dart';
import 'people/activity.dart';
import 'people/skill.dart';
import 'people/team_member.dart';
import 'people/user.dart';
import 'people/user_attachment.dart';
import 'pricing/plan_feature.dart';
import 'pricing/pricing_plan.dart';
import 'showcase/media_asset.dart';
import 'showcase/notification.dart';

export 'analytics/country_stat.dart';
export 'analytics/purchase_source.dart';
export 'analytics/time_series_point.dart';
export 'calendar/calendar_event.dart';
export 'calendar/event_category.dart';
export 'chat/chat_attachment.dart';
export 'chat/chat_message.dart';
export 'chat/conversation.dart';
export 'chat/conversation_participant.dart';
export 'commerce/category.dart';
export 'commerce/order.dart';
export 'commerce/order_item.dart';
export 'commerce/product.dart';
export 'commerce/tag.dart';
export 'commerce/transaction.dart';
export 'email/email.dart';
export 'email/email_attachment.dart';
export 'email/mail_folder.dart';
export 'email/mail_label.dart';
export 'faq/faq.dart';
export 'faq/faq_category.dart';
export 'files/file_folder.dart';
export 'files/file_share.dart';
export 'files/managed_file.dart';
export 'files/storage_account.dart';
export 'invoices/invoice.dart';
export 'invoices/invoice_item.dart';
export 'kanban/board.dart';
export 'kanban/board_column.dart';
export 'kanban/card.dart';
export 'kanban/card_label.dart';
export 'people/activity.dart';
export 'people/skill.dart';
export 'people/team_member.dart';
export 'people/user.dart';
export 'people/user_attachment.dart';
export 'pricing/plan_feature.dart';
export 'pricing/pricing_plan.dart';
export 'shared/enums.dart';
export 'shared/shared_columns.dart';
export 'showcase/media_asset.dart';
export 'showcase/notification.dart';

/// Every superdashboard model, in registration (and default navigation)
/// order, grouped by domain.
///
/// This is the single source of truth for the demo's shape: both the backend
/// (auto CRUD) and the panel (resource pages) derive their behavior from it.
const List<BeakModel> demoModels = [
  // People
  UserModel(),
  SkillModel(),
  TeamMemberModel(),
  ActivityModel(),
  UserAttachmentModel(),
  // Commerce
  CategoryModel(),
  TagModel(),
  ProductModel(),
  OrderModel(),
  OrderItemModel(),
  TransactionModel(),
  // Analytics
  TimeSeriesPointModel(),
  PurchaseSourceModel(),
  CountryStatModel(),
  // Email
  MailFolderModel(),
  MailLabelModel(),
  EmailModel(),
  EmailAttachmentModel(),
  // Chat
  ConversationModel(),
  ConversationParticipantModel(),
  ChatMessageModel(),
  ChatAttachmentModel(),
  // Calendar
  EventCategoryModel(),
  CalendarEventModel(),
  // Files
  FileFolderModel(),
  ManagedFileModel(),
  StorageAccountModel(),
  FileShareModel(),
  // Invoices
  InvoiceModel(),
  InvoiceItemModel(),
  // Kanban
  BoardModel(),
  BoardColumnModel(),
  CardModel(),
  CardLabelModel(),
  // Pricing
  PricingPlanModel(),
  PlanFeatureModel(),
  // FAQ
  FaqCategoryModel(),
  FaqModel(),
  // Showcase content
  MediaAssetModel(),
  NotificationModel(),
];

/// Builds a [BeakModelRegistry] over every model in [demoModels] — the index
/// both the server and the panel hand to Beak.
BeakModelRegistry buildDemoRegistry() {
  final registry = BeakModelRegistry();
  for (final model in demoModels) {
    registry.register(model);
  }
  return registry;
}
