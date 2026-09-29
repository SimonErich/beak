import 'package:beak/panel.dart';
import 'package:bookshop_beak/bookshop_beak.dart';

/// The Authors section: a table and a form.
final class AuthorResource extends BeakResource {
  /// Creates the Authors section.
  AuthorResource()
    : super(
        model: const AuthorModel(),
        title: 'Authors',
        filters: [AuthorModel.name.textFilter()],
        screens: [
          BeakTableScreen(fields: [AuthorModel.name, AuthorModel.website]),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: BeakFormLayout(
              children: [
                AuthorModel.name.inputText(),
                AuthorModel.website.inputText(),
                AuthorModel.bio.inputText(maxLines: 6),
              ],
            ),
          ),
        ],
      );
}
