import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/settings/model/company_settings.dart';
import 'package:sou9ix/features/settings/service/company_settings_repository.dart';

class CompanySettingsNotifier extends StateNotifier<CompanySettings> {
  /// [shopCode] is null when nobody's logged in yet — there's no shop's
  /// settings to read, so this stays at the default until a session with a
  /// shop code exists.
  CompanySettingsNotifier({required String? shopCode, CompanySettingsRepository? repository})
    : _repo = shopCode == null ? null : (repository ?? CompanySettingsRepository(shopCode: shopCode)),
      super(const CompanySettings()) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watch().listen((settings) {
        state = settings;
        AppFormat.currencySymbol = settings.currency.symbol;
      });
    }
  }

  final CompanySettingsRepository? _repo;
  StreamSubscription<CompanySettings>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _apply(CompanySettings updated) {
    state = updated;
    _repo?.save(updated);
  }

  void setCurrency(Currency currency) {
    // AppFormat is a plain static utility (called from ~50 files as
    // `AppFormat.dt(...)`) rather than a Riverpod-aware service, so the
    // symbol it appends is mirrored here instead of threading `ref` through
    // every call site.
    AppFormat.currencySymbol = currency.symbol;
    _apply(state.copyWith(currency: currency));
  }

  void setLanguage(AppLanguage language) =>
      _apply(state.copyWith(language: language));

  void setTicketName(String name) => _apply(
    state.copyWith(ticketName: name.trim().isEmpty ? 'Sou9ix' : name.trim()),
  );

  void setLogo(Uint8List? bytes) =>
      _apply(state.copyWith(logoBytes: bytes, clearLogo: bytes == null));

  void updateStoreInfo({
    String? nom,
    String? typeActiviteId,
    String? adresse,
    String? telephone,
    String? ville,
    String? matriculeFiscal,
  }) {
    _apply(
      state.copyWith(
        nom: nom,
        typeActiviteId: typeActiviteId,
        adresse: adresse,
        telephone: telephone,
        ville: ville,
        matriculeFiscal: matriculeFiscal,
      ),
    );
  }
}

final companySettingsProvider =
    StateNotifierProvider<CompanySettingsNotifier, CompanySettings>(
      (ref) => CompanySettingsNotifier(shopCode: ref.watch(currentShopCodeProvider)),
    );
