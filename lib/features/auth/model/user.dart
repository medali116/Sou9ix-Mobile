enum UserRole { admin, caissier }

class AppUser {
  final String id;
  final String nom;
  final String email;
  final UserRole role;
  final String magasin;

  const AppUser({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    required this.magasin,
  });

  String get initiales {
    final parts = nom.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}