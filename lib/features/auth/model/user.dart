import 'dart:typed_data';

enum UserRole { admin, caissier }

class AppUser {
  final String id;
  final String nom;
  final String email;
  final String telephone;
  final UserRole role;
  final String magasin;
  final Uint8List? photoBytes;

  const AppUser({
    required this.id,
    required this.nom,
    required this.email,
    this.telephone = '',
    required this.role,
    required this.magasin,
    this.photoBytes,
  });

  String get initiales {
    final parts = nom.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  AppUser copyWith({
    String? nom,
    String? email,
    String? telephone,
    String? magasin,
    Uint8List? photoBytes,
  }) => AppUser(
    id: id,
    nom: nom ?? this.nom,
    email: email ?? this.email,
    telephone: telephone ?? this.telephone,
    role: role,
    magasin: magasin ?? this.magasin,
    photoBytes: photoBytes ?? this.photoBytes,
  );
}
