import 'dart:typed_data';

/// A supplier ("fournisseur") the shop buys stock from — referenced by
/// [PurchaseInvoice] so a supplier's whole purchase history can be shown
/// on their detail page.
class Supplier {
  final String id;
  final String nom;
  final String telephone;
  final String adresse;
  final Uint8List? photoBytes;

  const Supplier({
    required this.id,
    required this.nom,
    this.telephone = '',
    this.adresse = '',
    this.photoBytes,
  });

  Supplier copyWith({
    String? nom,
    String? telephone,
    String? adresse,
    Uint8List? photoBytes,
  }) => Supplier(
    id: id,
    nom: nom ?? this.nom,
    telephone: telephone ?? this.telephone,
    adresse: adresse ?? this.adresse,
    photoBytes: photoBytes ?? this.photoBytes,
  );
}
