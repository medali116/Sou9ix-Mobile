import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/auth/model/user.dart' show UserRole;
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/employee_module.dart';
import 'package:sou9ix/features/employees/service/employees_repository.dart';

class EmployeesNotifier extends StateNotifier<List<Employee>> {
  /// [shopCode] is null when nobody's logged in yet (e.g. on the login
  /// screens themselves) — there's no shop to subscribe to, so the roster
  /// just stays empty until a session with a shop code exists.
  EmployeesNotifier(this._ref, {required String? shopCode, EmployeesRepository? repository})
    : _repo = shopCode == null ? null : (repository ?? EmployeesRepository(shopCode: shopCode)),
      super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((employees) => state = employees);
    }
  }

  final Ref _ref;
  final EmployeesRepository? _repo;
  StreamSubscription<List<Employee>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void upsert(Employee employee) {
    final exists = state.any((e) => e.id == employee.id);
    if (exists) {
      final old = state.firstWhere((e) => e.id == employee.id);
      if (old.nom != employee.nom) {
        logActivity(
          _ref,
          category: ActivityCategory.employes,
          impact: ActivityImpact.modification,
          action: 'Employé modifié',
          targetName: employee.nom,
          champ: 'Nom',
          ancienneValeur: old.nom,
          nouvelleValeur: employee.nom,
        );
      }
      if (old.telephone != employee.telephone) {
        logActivity(
          _ref,
          category: ActivityCategory.employes,
          impact: ActivityImpact.modification,
          action: 'Employé modifié',
          targetName: employee.nom,
          champ: 'Téléphone',
          ancienneValeur: old.telephone,
          nouvelleValeur: employee.telephone,
        );
      }
      if (old.poste != employee.poste) {
        logActivity(
          _ref,
          category: ActivityCategory.employes,
          impact: ActivityImpact.modification,
          action: 'Employé modifié',
          targetName: employee.nom,
          champ: 'Poste',
          ancienneValeur: old.poste,
          nouvelleValeur: employee.poste,
        );
      }
      if (old.role != employee.role) {
        logActivity(
          _ref,
          category: ActivityCategory.employes,
          impact: ActivityImpact.modification,
          action: 'Rôle modifié',
          targetName: employee.nom,
          champ: 'Rôle',
          ancienneValeur: old.role == UserRole.admin ? 'Administrateur' : 'Caissier',
          nouvelleValeur: employee.role == UserRole.admin ? 'Administrateur' : 'Caissier',
        );
      }
      if (old.pin != employee.pin) {
        // Never write the actual PIN value to the audit trail.
        logActivity(
          _ref,
          category: ActivityCategory.employes,
          impact: ActivityImpact.modification,
          action: 'Code PIN modifié',
          targetName: employee.nom,
        );
      }
      if (old.modules != employee.modules) {
        logActivity(
          _ref,
          category: ActivityCategory.employes,
          impact: ActivityImpact.modification,
          action: 'Accès modifiés',
          targetName: employee.nom,
          champ: 'Modules',
          ancienneValeur: old.modules.map((m) => m.label).join(', '),
          nouvelleValeur: employee.modules.map((m) => m.label).join(', '),
        );
      }
    } else {
      logActivity(
        _ref,
        category: ActivityCategory.employes,
        impact: ActivityImpact.ajout,
        action: 'Nouvel employé',
        targetName: employee.nom,
      );
    }
    _repo?.upsert(employee);
  }

  /// Soft delete — keeps history/shifts pointing at a valid employee id
  /// instead of leaving them dangling like a hard remove would.
  void archive(String id, {required String motif}) {
    final matches = state.where((e) => e.id == id);
    final employee = matches.isEmpty ? null : matches.first;
    if (employee == null) return;
    _repo?.upsert(employee.copyWith(actif: false));
    logActivity(
      _ref,
      category: ActivityCategory.employes,
      impact: ActivityImpact.suppression,
      action: 'Employé archivé',
      targetName: employee.nom,
      motif: motif,
    );
  }
}

final employeesProvider =
    StateNotifierProvider<EmployeesNotifier, List<Employee>>(
      (ref) => EmployeesNotifier(ref, shopCode: ref.watch(currentShopCodeProvider)),
    );

final activeEmployeesProvider = Provider<List<Employee>>((ref) {
  return ref.watch(employeesProvider).where((e) => e.actif).toList();
});
