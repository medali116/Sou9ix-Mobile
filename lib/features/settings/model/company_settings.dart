import 'dart:convert';
import 'dart:typed_data';

import 'package:sou9ix/features/settings/model/activity_type.dart';

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

/// Built-in shop activity types offered as chips on the admin onboarding
/// wizard. Not exhaustive — an admin can add a custom one on the fly (see
/// [ActivityType]) when none of these fit, so there's no catch-all "Autre"
/// value here anymore.
enum TypeActivite { epicerie, cafe, boutique }

extension TypeActiviteLabel on TypeActivite {
  String get label => switch (this) {
    TypeActivite.epicerie => 'Épicerie',
    TypeActivite.cafe => 'Café',
    TypeActivite.boutique => 'Boutique',
  };
}

/// Resolves a [CompanySettings.typeActiviteId] to a human label — either one
/// of the built-in [TypeActivite] names, or a custom [ActivityType] created
/// from the wizard's "+ Nouveau type d'activité" option.
String typeActiviteLabel(String id, List<ActivityType> customTypes) {
  final builtins = TypeActivite.values.where((t) => t.name == id);
  if (builtins.isNotEmpty) return builtins.first.label;
  final customs = customTypes.where((t) => t.id == id);
  if (customs.isNotEmpty) return customs.first.name;
  return id;
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

  /// Either a built-in [TypeActivite]'s [Enum.name], or a custom
  /// [ActivityType]'s id — resolve to a label via [typeActiviteLabel].
  final String typeActiviteId;
  final String adresse;
  final String telephone;
  final String? ville;
  final String matriculeFiscal;

  const CompanySettings({
    this.currency = Currency.dt,
    this.language = AppLanguage.francais,
    this.ticketName = 'Sou9ix',
    this.logoBytes,
    this.nom = 'Épicerie El Baraka — La Marsa',
    this.typeActiviteId = 'epicerie',
    this.adresse = 'La Marsa, Tunis',
    this.telephone = '+216 71 123 456',
    this.ville,
    this.matriculeFiscal = '1234567A/A/M/000',
  });

  Map<String, dynamic> toMap() => {
    'devise': currency.name,
    'langue': language.name,
    'nomTicket': ticketName,
    'logo': logoBytes == null ? null : base64Encode(logoBytes!),
    'nom': nom,
    'typeActiviteId': typeActiviteId,
    'adresse': adresse,
    'telephone': telephone,
    'ville': ville,
    'matriculeFiscal': matriculeFiscal,
  };

  factory CompanySettings.fromMap(Map<String, dynamic> map) => CompanySettings(
    currency: Currency.values.firstWhere(
      (c) => c.name == (map['devise'] ?? map['currency']),
      orElse: () => Currency.dt,
    ),
    language: AppLanguage.values.firstWhere(
      (l) => l.name == (map['langue'] ?? map['language']),
      orElse: () => AppLanguage.francais,
    ),
    ticketName: (map['nomTicket'] ?? map['ticketName']) as String? ?? 'Sou9ix',
    logoBytes: (map['logo'] ?? map['logoBytes']) == null
        ? null
        : base64Decode((map['logo'] ?? map['logoBytes']) as String),
    nom: map['nom'] as String? ?? 'Épicerie El Baraka — La Marsa',
    // Falls back to the old enum-backed 'typeActivite' key so a doc saved
    // before this field became a free-form id still reads back correctly.
    typeActiviteId:
        map['typeActiviteId'] as String? ??
        map['typeActivite'] as String? ??
        'epicerie',
    adresse: map['adresse'] as String? ?? 'La Marsa, Tunis',
    telephone: map['telephone'] as String? ?? '+216 71 123 456',
    ville: map['ville'] as String?,
    matriculeFiscal: map['matriculeFiscal'] as String? ?? '1234567A/A/M/000',
  );

  CompanySettings copyWith({
    Currency? currency,
    AppLanguage? language,
    String? ticketName,
    Uint8List? logoBytes,
    bool clearLogo = false,
    String? nom,
    String? typeActiviteId,
    String? adresse,
    String? telephone,
    String? ville,
    String? matriculeFiscal,
  }) => CompanySettings(
    currency: currency ?? this.currency,
    language: language ?? this.language,
    ticketName: ticketName ?? this.ticketName,
    logoBytes: clearLogo ? null : (logoBytes ?? this.logoBytes),
    nom: nom ?? this.nom,
    typeActiviteId: typeActiviteId ?? this.typeActiviteId,
    adresse: adresse ?? this.adresse,
    telephone: telephone ?? this.telephone,
    ville: ville ?? this.ville,
    matriculeFiscal: matriculeFiscal ?? this.matriculeFiscal,
  );
}
