import 'dart:typed_data';

/// Currencies selectable from "Devise" — [symbol] is what
/// [AppFormat] appends after every amount app-wide.
enum Currency { dt, tnd, eur, usd }

extension CurrencyLabel on Currency {
  String get symbol => switch (this) {
    Currency.dt => 'DT',
    Currency.tnd => 'TND',
    Currency.eur => '€',
    Currency.usd => '\$',
  };

  String get label => switch (this) {
    Currency.dt => 'Dinar tunisien (DT)',
    Currency.tnd => 'Dinar tunisien (TND)',
    Currency.eur => 'Euro (€)',
    Currency.usd => 'Dollar (\$)',
  };
}

enum AppLanguage { francais, arabe, anglais }

extension AppLanguageLabel on AppLanguage {
  String get label => switch (this) {
    AppLanguage.francais => 'Français',
    AppLanguage.arabe => 'العربية',
    AppLanguage.anglais => 'English',
  };
}

/// Store-wide preferences shown under Profil → "Magasin" and "Gestion de
/// l'entreprise" — [ticketName] and [logoBytes] are printed on every ticket
/// via [TicketPdfService], [currency] drives every [AppFormat] amount. The
/// store's display name itself lives on [AppUser.magasin] (already used
/// across the dashboard/Caisse headers), not here.
class CompanySettings {
  final Currency currency;
  final AppLanguage language;
  final String ticketName;
  final Uint8List? logoBytes;
  final String adresse;
  final String telephone;
  final String matriculeFiscal;

  const CompanySettings({
    this.currency = Currency.dt,
    this.language = AppLanguage.francais,
    this.ticketName = 'Sou9ix',
    this.logoBytes,
    this.adresse = 'La Marsa, Tunis',
    this.telephone = '+216 71 123 456',
    this.matriculeFiscal = '1234567A/A/M/000',
  });

  CompanySettings copyWith({
    Currency? currency,
    AppLanguage? language,
    String? ticketName,
    Uint8List? logoBytes,
    bool clearLogo = false,
    String? adresse,
    String? telephone,
    String? matriculeFiscal,
  }) => CompanySettings(
    currency: currency ?? this.currency,
    language: language ?? this.language,
    ticketName: ticketName ?? this.ticketName,
    logoBytes: clearLogo ? null : (logoBytes ?? this.logoBytes),
    adresse: adresse ?? this.adresse,
    telephone: telephone ?? this.telephone,
    matriculeFiscal: matriculeFiscal ?? this.matriculeFiscal,
  );
}
