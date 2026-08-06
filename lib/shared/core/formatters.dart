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

  /// Digit-grouped variant ("1 928.750") for dense figures (statistics,
  /// reports) where a bare "1928.750" is harder to scan at a glance —
  /// spaces every 3 digits, decimal point kept (not the French-locale
  /// comma, to stay consistent with [dt]/[dtShort] everywhere else).
  static String _grouped(String fixed) {
    final negative = fixed.startsWith('-');
    final unsigned = negative ? fixed.substring(1) : fixed;
    final dotIndex = unsigned.indexOf('.');
    final intPart = dotIndex == -1 ? unsigned : unsigned.substring(0, dotIndex);
    final fracPart = dotIndex == -1 ? '' : unsigned.substring(dotIndex);
    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      // Non-breaking space: some renderers give a plain U+0020 an
      // inconsistent (occasionally near-zero) advance width next to bold
      // digits, which made the grouping invisible in practice; U+00A0
      // renders reliably in every case we've hit.
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(intPart[i]);
    }
    return '${negative ? '-' : ''}$buffer$fracPart';
  }

  static String dtGrouped(num value) =>
      '${_grouped(value.toStringAsFixed(3))} $currencySymbol';
  static String dtShortGrouped(num value) =>
      '${_grouped(value.toStringAsFixed(2))} $currencySymbol';

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
