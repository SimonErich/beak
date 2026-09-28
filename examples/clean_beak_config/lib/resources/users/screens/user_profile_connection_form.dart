import 'package:beak/panel.dart';
import '../models/user_profile_connection.dart';

/// Reusable advanced fields for a customer/profile association.
final BeakFormLayout userProfileConnectionForm = BeakFormLayout(
  children: [
    UserProfileConnectionModel.notes.inputText(label: 'Delivery instructions'),
  ],
);
