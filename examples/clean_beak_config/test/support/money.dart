import 'package:beak/beak.dart';

/// An exact euro amount or percentage, such as `eur('12.50')` or `eur('20')`.
///
/// Tests state amounts as text so no expectation ever passes through a
/// binary floating-point number.
BeakDecimal eur(String amount) => BeakDecimal.parse(amount);
