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

enum TypeActivite { epicerie, cafe, boutique, autre }

extension TypeActiviteLabel on TypeActivite {
  String get label => switch (this) {
    TypeActivite.epicerie => 'Épicerie',
    TypeActivite.cafe => 'Café',
    TypeActivite.boutique => 'Boutique',
    TypeActivite.autre => 'Autre',
  };
}

/// Store-wide preferences shown under Profil → "Magasin" and "Gestion de
/// l'entreprise", and set once at signup on the admin onboarding wizard —
/// [nom] is what every dashboard/Caisse header displays (also mirrored
/// onto the current session's [AppUser.magasin] at login time), [ticketName]
/// and [logoBytes] are printed on every ticket via [TicketPdfService],
/// [currency] drives every [AppFormat] amount.
class CompanySettings {
  final Currency currency;
  final AppLanguage language;
  final String ticketName;
  final Uint8List? logoBytes;
  final String nom;
  final TypeActivite typeActivite;
  final String adresse;
  final String telephone;
  final String? ville;
  final String matriculeFiscal;

  /// This shop's permanent join code (e.g. `S9X-4F82A`), generated once at
  /// admin signup and registered in Firestore under `shops/{companyCode}`
  /// — the one thing an employee needs to link the Caissier app to this
  /// shop on first launch. Null until signup completes (or for installs
  /// created before this feature existed).
  final String? companyCode;

  const CompanySettings({
    this.currency = Currency.dt,
    this.language = AppLanguage.francais,
    this.ticketName = 'Sou9ix',
    this.logoBytes,
    this.nom = 'Épicerie El Baraka — La Marsa',
    this.typeActivite = TypeActivite.epicerie,
    this.adresse = 'La Marsa, Tunis',
    this.telephone = '+216 71 123 456',
    this.ville,
    this.matriculeFiscal = '1234567A/A/M/000',
    this.companyCode,
  });

  CompanySettings copyWith({
    Currency? currency,
    AppLanguage? language,
    String? ticketName,
    Uint8List? logoBytes,
    bool clearLogo = false,
    String? nom,
    TypeActivite? typeActivite,
    String? adresse,
    String? telephone,
    String? ville,
    String? matriculeFiscal,
    String? companyCode,
  }) => CompanySettings(
    currency: currency ?? this.currency,
    language: language ?? this.language,
    ticketName: ticketName ?? this.ticketName,
    logoBytes: clearLogo ? null : (logoBytes ?? this.logoBytes),
    nom: nom ?? this.nom,
    typeActivite: typeActivite ?? this.typeActivite,
    adresse: adresse ?? this.adresse,
    telephone: telephone ?? this.telephone,
    ville: ville ?? this.ville,
    matriculeFiscal: matriculeFiscal ?? this.matriculeFiscal,
    companyCode: companyCode ?? this.companyCode,
  );
}
