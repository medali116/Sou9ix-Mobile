import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/employee_module.dart';

class EmployeesNotifier extends StateNotifier<List<Employee>> {
  EmployeesNotifier(this._ref) : super(_seed());

  final Ref _ref;

  static List<Employee> _seed() => [
    const Employee(
      id: 'e1',
      nom: 'Yassine Karoui',
      telephone: '+216 20 111 222',
      poste: 'Gérant',
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
    ),
  ];

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
  }

  /// Soft delete — keeps history/shifts pointing at a valid employee id
  /// instead of leaving them dangling like a hard remove would.
  void archive(String id, {required String motif}) {
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
    }
  }
}

final employeesProvider =
    StateNotifierProvider<EmployeesNotifier, List<Employee>>(
      (ref) => EmployeesNotifier(ref),
    );

final activeEmployeesProvider = Provider<List<Employee>>((ref) {
  return ref.watch(employeesProvider).where((e) => e.actif).toList();
});
