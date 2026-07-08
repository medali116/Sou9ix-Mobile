import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/employees/model/employee.dart';

class EmployeesNotifier extends StateNotifier<List<Employee>> {
  EmployeesNotifier() : super(_seed());

  static List<Employee> _seed() => const [
        Employee(id: 'e1', nom: 'Yassine Karoui', telephone: '+216 20 111 222', poste: 'Gérant'),
        Employee(id: 'e2', nom: 'Rania Mejri', telephone: '+216 22 333 444', poste: 'Caissière'),
      ];

  void upsert(Employee employee) {
    final exists = state.any((e) => e.id == employee.id);
    if (exists) {
      state = [for (final e in state) if (e.id == employee.id) employee else e];
    } else {
      state = [...state, employee];
    }
  }

  /// Soft delete — keeps history/shifts pointing at a valid employee id
  /// instead of leaving them dangling like a hard remove would.
  void archive(String id) {
    state = [for (final e in state) if (e.id == id) e.copyWith(actif: false) else e];
  }
}

final employeesProvider = StateNotifierProvider<EmployeesNotifier, List<Employee>>(
  (ref) => EmployeesNotifier(),
);

final activeEmployeesProvider = Provider<List<Employee>>((ref) {
  return ref.watch(employeesProvider).where((e) => e.actif).toList();
});
