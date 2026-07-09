class AppFormat {
  AppFormat._();

  /// Currency symbol appended to every formatted amount — set from
  /// Profil → "Gestion de l'entreprise" → Devise (see
  /// [CompanySettingsNotifier.setCurrency]).
  static String currencySymbol = 'DT';

  static String dt(num value) => '${value.toStringAsFixed(3)} $currencySymbol';
  static String dtShort(num value) =>
      '${value.toStringAsFixed(2)} $currencySymbol';
  static String kg(num value) => '${value.toStringAsFixed(3)} kg';

  static String weekday(DateTime date) {
    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return days[date.weekday - 1];
  }
}
