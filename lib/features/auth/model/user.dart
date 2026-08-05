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

  /// Which shop this session is scoped to — every shop-scoped provider
  /// (products, employees, suppliers, company settings) watches this
  /// indirectly via `currentShopCodeProvider` to know which
  /// `shops/{shopCode}/...` subtree to read/write.
  final String shopCode;

  /// Which staff-roster [Employee] this login account is — lets a
  /// Caissier's session (fond de caisse, ventes attribuées) resolve
  /// automatically from who's logged in, instead of asking them to pick
  /// themselves from a list every time. Null for an account with no
  /// matching roster entry (e.g. a brand-new admin-only login).
  final String? employeeId;

  const AppUser({
    required this.id,
    required this.nom,
    required this.email,
    this.telephone = '',
    required this.role,
    required this.magasin,
    required this.shopCode,
    this.photoBytes,
    this.employeeId,
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
    shopCode: shopCode,
    photoBytes: photoBytes ?? this.photoBytes,
  );
}
