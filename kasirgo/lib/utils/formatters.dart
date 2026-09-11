import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String currency(num amount) {
    return _currencyFormat.format(amount);
  }

  static String date(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  static String dateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(dateTime);
  }

  static String time(DateTime dateTime) {
    return DateFormat('HH:mm', 'id_ID').format(dateTime);
  }

  static String number(num value) {
    return NumberFormat('#,###', 'id_ID').format(value);
  }

  static String shortDate(DateTime date) {
    return DateFormat('dd/MM/yy', 'id_ID').format(date);
  }
}