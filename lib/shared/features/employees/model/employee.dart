import 'package:sou9ix/shared/features/auth/model/user.dart' show UserRole;
import 'package:sou9ix/shared/features/employees/model/employee_module.dart';

/// A staff roster entry — deliberately separate from the ephemeral login
/// session ([AppUser]): this is who sales/attendance get attributed to,
/// and (via [pin]/[role]) who can actually sign in as themselves, either
/// on "Connexion employé" (nom complet + PIN) or, for admins, on
/// "Connexion administrateur" (e-mail + mot de passe).
class Employee {
  final String id;
  final String nom;
  final String telephone;
  final String poste;
  final bool actif;
  final Set<EmployeeModule> modules;

  /// 4-digit code an employee types on the "Qui utilise Sou9ix ?" screen
  /// to open their own session — deliberately short/numeric since it's
  /// re-entered many times a day on a shared shop device, not a full
  /// password.
  final String pin;

  /// Which login role this employee signs in as — distinct from [poste]
  /// (a free-text job title like "Gérant"/"Vendeur") since two people with
  /// different titles can still need the same admin/caissier access level.
  final UserRole role;

  /// Real, typed e-mail — only set for admins created via the onboarding
  /// wizard. Null for legacy/seed employees, who fall back to
  /// [syntheticEmail] via [loginEmail].
  final String? email;

  /// Mock password for the separate admin login screen — plain, in-memory
  /// only, like everything else in this backend-less demo (no real hashing
  /// is honestly possible without a server). Null for legacy/seed
  /// employees, who keep the old any-non-empty-password mock behavior.
  final String? password;

  const Employee({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.poste,
    this.actif = true,
    this.modules = defaultCashierModules,
    this.pin = '0000',
    this.role = UserRole.caissier,
    this.email,
    this.password,
  });

  String get initiales {
    final parts = nom.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Login slug, e.g. "Rania Mejri" → "rania.mejri" — deterministic from
  /// [nom] so it never needs its own field or admin-side setup. Only used
  /// to build [syntheticEmail]; the employee login screen itself matches
  /// on the full name (see [matchesFullName]).
  String get identifiant => _slugify(nom);

  /// Mock e-mail used only for the separate admin login screen — same
  /// slug as [identifiant], since there's no real account system behind
  /// either.
  String get syntheticEmail => '$identifiant@sou9ix.tn';

  /// What actually gets typed on the admin login screen and checked for
  /// uniqueness at signup — the real [email] when one was set, else the
  /// deterministic [syntheticEmail].
  String get loginEmail => email ?? syntheticEmail;

  /// Whether [query] names this employee, ignoring case/accents/spacing —
  /// how the employee login screen resolves "Nom complet" to a roster
  /// entry. Relies on full names being unique among active employees (see
  /// the duplicate-name guard in `employee_form_screen.dart`).
  bool matchesFullName(String query) => _normalizeName(nom) == _normalizeName(query);

  Employee copyWith({
    String? nom,
    String? telephone,
    String? poste,
    bool? actif,
    Set<EmployeeModule>? modules,
    String? pin,
    UserRole? role,
    String? email,
    String? password,
  }) => Employee(
    id: id,
    nom: nom ?? this.nom,
    telephone: telephone ?? this.telephone,
    poste: poste ?? this.poste,
    actif: actif ?? this.actif,
    modules: modules ?? this.modules,
    pin: pin ?? this.pin,
    role: role ?? this.role,
    email: email ?? this.email,
    password: password ?? this.password,
  );
}

const _accentFold = {
  'à': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i',
  'ô': 'o', 'ö': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

String _normalizeName(String input) {
  var out = input.toLowerCase();
  _accentFold.forEach((accented, plain) => out = out.replaceAll(accented, plain));
  out = out.replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
  return out.replaceAll(RegExp(r'\s+'), ' ');
}

String _slugify(String input) => _normalizeName(input).replaceAll(' ', '.');

/// Public so `employee_form_screen.dart` can block duplicate full names at
/// creation time — the employee login screen depends on names being
/// unique among active employees.
String normalizeEmployeeName(String input) => _normalizeName(input);

/// True for a PIN that's all one digit (`0000`, `1111`…) or a strictly
/// ascending/descending run (`1234`, `2345`…`9876`, `4321`…) — works for
/// any length so the same check covers the admin's 4–6 digit PIN and the
/// caissier's fixed 4 digits.
bool isWeakPin(String pin) {
  final digits = pin.split('').map(int.parse).toList();
  if (digits.toSet().length == 1) return true;
  final steps = [
    for (var i = 0; i < digits.length - 1; i++) digits[i + 1] - digits[i],
  ];
  return steps.every((s) => s == 1) || steps.every((s) => s == -1);
}
