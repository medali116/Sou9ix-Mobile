import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/settings/viewmodel/company_settings_provider.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier(this._ref) : super(null);

  final Ref _ref;

  /// Opens the app session for whoever authenticated — either an employee
  /// (nom complet + PIN) or an admin (e-mail + password) — with the
  /// role/access that follows from their own roster entry, never chosen
  /// by hand. The shop name comes from [companySettingsProvider], set once
  /// at signup on the admin onboarding wizard (or the seed default for the
  /// demo data).
  void loginAsEmployee(Employee employee) {
    state = AppUser(
      id: 'u_${employee.id}',
      nom: employee.nom,
      email: employee.loginEmail,
      telephone: employee.telephone,
      role: employee.role,
      magasin: _ref.read(companySettingsProvider).nom,
      employeeId: employee.id,
    );
  }

  void logout() => state = null;

  void updateProfile({
    String? nom,
    String? email,
    String? telephone,
    String? magasin,
    Uint8List? photoBytes,
  }) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(
      nom: nom,
      email: email,
      telephone: telephone,
      magasin: magasin,
      photoBytes: photoBytes,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>(
  (ref) => AuthNotifier(ref),
);
