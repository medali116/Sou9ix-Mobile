import 'package:sou9ix/features/employees/model/employee_permission.dart';

/// A staff roster entry — deliberately separate from [AppUser]/[UserRole]:
/// this is who sales/attendance get attributed to, not a login account.
class Employee {
  final String id;
  final String nom;
  final String telephone;
  final String poste;
  final bool actif;
  final Set<EmployeePermission> permissions;

  const Employee({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.poste,
    this.actif = true,
    this.permissions = defaultCashierPermissions,
  });

  String get initiales {
    final parts = nom.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Employee copyWith({
    String? nom,
    String? telephone,
    String? poste,
    bool? actif,
    Set<EmployeePermission>? permissions,
  }) => Employee(
    id: id,
    nom: nom ?? this.nom,
    telephone: telephone ?? this.telephone,
    poste: poste ?? this.poste,
    actif: actif ?? this.actif,
    permissions: permissions ?? this.permissions,
  );
}
