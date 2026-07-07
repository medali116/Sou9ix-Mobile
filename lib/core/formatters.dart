class AppFormat {
  AppFormat._();

  static String dt(num value) => '${value.toStringAsFixed(3)} DT';
  static String dtShort(num value) => '${value.toStringAsFixed(2)} DT';
  static String kg(num value) => '${value.toStringAsFixed(3)} kg';

  static String weekday(DateTime date) {
    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return days[date.weekday - 1];
  }
}
