import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/settings/model/company_settings.dart';

class CompanySettingsNotifier extends StateNotifier<CompanySettings> {
  CompanySettingsNotifier() : super(const CompanySettings());

  void setCurrency(Currency currency) {
    state = state.copyWith(currency: currency);
    // AppFormat is a plain static utility (called from ~50 files as
    // `AppFormat.dt(...)`) rather than a Riverpod-aware service, so the
    // symbol it appends is mirrored here instead of threading `ref` through
    // every call site.
    AppFormat.currencySymbol = currency.symbol;
  }

  void setLanguage(AppLanguage language) =>
      state = state.copyWith(language: language);

  void setTicketName(String name) => state = state.copyWith(
    ticketName: name.trim().isEmpty ? 'Sou9ix' : name.trim(),
  );

  void setLogo(Uint8List? bytes) =>
      state = state.copyWith(logoBytes: bytes, clearLogo: bytes == null);

  void updateStoreInfo({
    required String adresse,
    required String telephone,
    required String matriculeFiscal,
  }) {
    state = state.copyWith(
      adresse: adresse,
      telephone: telephone,
      matriculeFiscal: matriculeFiscal,
    );
  }
}

final companySettingsProvider =
    StateNotifierProvider<CompanySettingsNotifier, CompanySettings>(
      (ref) => CompanySettingsNotifier(),
    );
