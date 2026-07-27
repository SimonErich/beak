/// Every schema class of the superdashboard, grouped by domain.
///
/// A barrel for the panel's own files: `beak prepare` discovers the models
/// themselves from `lib/models/`, so nothing here is a registration.
library;

export 'analytics/activity_heat_cell.dart';
export 'analytics/country_stat.dart';
export 'analytics/office_location.dart';
export 'analytics/price_candle.dart';
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
export 'commerce/order_comment.dart';
export 'commerce/order_event.dart';
export 'commerce/order_item.dart';
export 'commerce/price_rule.dart';
export 'commerce/product.dart';
export 'commerce/product_image.dart';
export 'commerce/product_review.dart';
export 'commerce/product_variant.dart';
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
