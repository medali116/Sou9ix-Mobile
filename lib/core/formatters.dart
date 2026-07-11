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

  /// "samedi" — full French weekday name, lowercase (for phrases like
  /// "vs samedi dernier").
  static String weekdayFull(DateTime date) =>
      _weekdayNames[date.weekday - 1].toLowerCase();

  static const _weekdayNames = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  static const _monthNames = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  /// "Vendredi 10 juillet" — spelled out manually (not via `intl`'s
  /// locale-aware `DateFormat`) since this app never calls
  /// `initializeDateFormatting`, so a locale-dependent pattern like
  /// `DateFormat('EEEE dd MMMM', 'fr_FR')` would throw at runtime.
  static String fullDate(DateTime date) =>
      '${_weekdayNames[date.weekday - 1]} ${date.day} ${_monthNames[date.month - 1]}';
}
