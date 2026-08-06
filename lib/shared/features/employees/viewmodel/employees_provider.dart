import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/shared/features/auth/model/user.dart' show UserRole;
import 'package:sou9ix/shared/features/employees/model/employee.dart';
import 'package:sou9ix/shared/features/employees/model/employee_module.dart';
import 'package:sou9ix/shared/features/employees/service/employees_repository.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';

final employeesRepositoryProvider = Provider<EmployeesRepository?>((ref) {
  final shopCode = ref.watch(shopCodeProvider);
  if (shopCode == null) return null;
  return EmployeesRepository(FirebaseFirestore.instance, shopCode);
});

class EmployeesNotifier extends StateNotifier<List<Employee>> {
  EmployeesNotifier(this._ref, this._repo) : super(_seed()) {
    unawaited(_init());
  }

  final Ref _ref;
  final EmployeesRepository? _repo;
  StreamSubscription<List<Employee>>? _sub;

  static List<Employee> _seed() => [
    const Employee(
      id: 'e1',
      nom: 'Yassine Karoui',
      telephone: '+216 20 111 222',
      poste: 'Gérant',
      pin: '1234',
      role: UserRole.admin,
      modules: {
        EmployeeModule.venteCaisse,
        EmployeeModule.clientsCredits,
        EmployeeModule.stockProduits,
        EmployeeModule.fournisseurs,
        EmployeeModule.rapportsFinanciers,
        EmployeeModule.administration,
      },
    ),
    const Employee(
      id: 'e2',
      nom: 'Rania Mejri',
      telephone: '+216 22 333 444',
      poste: 'Caissière',
      pin: '5678',
      role: UserRole.caissier,
    ),
  ];

  Future<void> _init() async {
    final repo = _repo;
    if (repo == null) return;
    await repo.bootstrapIfEmpty(state);
    _sub = repo.watchAll().listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> upsert(Employee employee) async {
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
          ancienneValeur: old.role == UserRole.admin
              ? 'Administrateur'
              : 'Caissier',
          nouvelleValeur: employee.role == UserRole.admin
              ? 'Administrateur'
              : 'Caissier',
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
      state = [
        for (final e in state)
          if (e.id == employee.id) employee else e,
      ];
    } else {
      state = [...state, employee];
      logActivity(
        _ref,
        category: ActivityCategory.employes,
        impact: ActivityImpact.ajout,
        action: 'Nouvel employé',
        targetName: employee.nom,
      );
    }
    await _repo?.upsert(employee);
  }

  /// Soft delete — keeps history/shifts pointing at a valid employee id
  /// instead of leaving them dangling like a hard remove would.
  Future<void> archive(String id, {required String motif}) async {
    final matches = state.where((e) => e.id == id);
    final employee = matches.isEmpty ? null : matches.first;
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(actif: false) else e,
    ];
    if (employee != null) {
      logActivity(
        _ref,
        category: ActivityCategory.employes,
        impact: ActivityImpact.suppression,
        action: 'Employé archivé',
        targetName: employee.nom,
        motif: motif,
      );
      await _repo?.upsert(employee.copyWith(actif: false));
    }
  }
}

final employeesProvider =
    StateNotifierProvider<EmployeesNotifier, List<Employee>>(
      (ref) => EmployeesNotifier(ref, ref.watch(employeesRepositoryProvider)),
    );

final activeEmployeesProvider = Provider<List<Employee>>((ref) {
  return ref.watch(employeesProvider).where((e) => e.actif).toList();
});
