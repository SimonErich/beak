import 'package:beak/panel.dart';
import 'package:bookshop_beak/bookshop_beak.dart';

/// The Books section, in Beak's golden-path style.
///
/// Every reference is a typed ref of the `Book` model in `bookshop_beak`: a
/// renamed or retyped field stops this file compiling where it used the field.
final class BookResource extends BeakResource {
  /// Creates the Books section.
  BookResource()
    : super(
        model: const BookModel(),
        title: 'Books',
        filters: [
          BookModel.title.textFilter(),
          BookModel.author.relationFilter(),
          BookModel.format.selectFilter(),
          BookModel.priceInCents.numberRangeFilter(label: 'Price'),
        ],
        screens: [
          BeakTableScreen(
            fields: [
              BookModel.title,
              BookModel.author.name,
              BookModel.format,
              BookModel.priceInCents,
              BookModel.stock,
            ],
          ),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: BeakFormLayout(
              children: [
                BookModel.title.inputText(),
                BookModel.isbn.inputText(),
                BookModel.author.inputCombobox(),
                BookModel.format.inputSelect(),
                BookModel.priceInCents.inputNumber(),
                BookModel.stock.inputNumber(),
              ],
            ),
          ),
        ],
      );
}
