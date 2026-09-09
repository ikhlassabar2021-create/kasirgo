import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _numberFormat = NumberFormat.decimalPattern('id_ID');

  static String currency(double amount) => _currencyFormat.format(amount);
  static String date(DateTime date) => _dateFormat.format(date);
  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt);
  static String number(double n) => _numberFormat.format(n);
}