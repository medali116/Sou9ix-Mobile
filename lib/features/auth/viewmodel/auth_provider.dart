import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/employee_module.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/features/settings/service/company_settings_repository.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  /// Opens the app session for whoever authenticated — either an employee
  /// (nom complet + PIN) or an admin (e-mail + password) — with the
  /// role/access that follows from their own roster entry, never chosen by
  /// hand. The shop name is fetched directly (not via [companySettingsProvider]
  /// — that provider is itself scoped to `AppUser.shopCode`, which doesn't
  /// exist yet at the moment this runs, so it would still be reading the
  /// *previous* session's shop, or the empty default on a fresh app launch).
  Future<void> loginAsEmployee(Employee employee) async {
    final settings = await CompanySettingsRepository(
      shopCode: employee.shopCode,
    ).fetchOnce();
    state = AppUser(
      id: 'u_${employee.id}',
      nom: employee.nom,
      email: employee.loginEmail,
      telephone: employee.telephone,
      role: employee.role,
      magasin: settings.nom,
      shopCode: employee.shopCode,
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
  (ref) => AuthNotifier(),
);

/// The active session's shop, or `null` when nobody's logged in — every
/// shop-scoped provider (products, categories, employees, suppliers, company
/// settings) watches this to know which `shops/{shopCode}/...` subtree to
/// read/write, and gets disposed/recreated whenever it changes (login,
/// logout, or switching accounts).
final currentShopCodeProvider = Provider<String?>(
  (ref) => ref.watch(authProvider)?.shopCode,
);

/// Which [EmployeeModule]s the active session may work in — an admin can
/// always work everywhere; a caissier is limited to whatever was granted
/// on their roster entry (falling back to [defaultCashierModules] if their
/// [Employee] record can't be found, e.g. mid-load). Feature screens gate
/// sensitive actions (adding/deleting a loss, editing prices…) on this
/// instead of on [UserRole] alone, since two caissiers can be trusted with
/// different areas of the shop.
final currentModulesProvider = Provider<Set<EmployeeModule>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return const {};
  if (user.role == UserRole.admin) return EmployeeModule.values.toSet();
  final employeeId = user.employeeId;
  if (employeeId == null) return defaultCashierModules;
  final matches = ref.watch(employeesProvider).where((e) => e.id == employeeId);
  return matches.isEmpty ? defaultCashierModules : matches.first.modules;
});

final hasModuleProvider = Provider.family<bool, EmployeeModule>(
  (ref, module) => ref.watch(currentModulesProvider).contains(module),
);
