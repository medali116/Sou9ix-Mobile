import 'dart:convert';
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

  Map<String, dynamic> toMap() => {
    'nom': nom,
    'telephone': telephone,
    'adresse': adresse,
    'photo': photoBytes == null ? null : base64Encode(photoBytes!),
  };

  factory Supplier.fromMap(String id, Map<String, dynamic> map) => Supplier(
    id: id,
    nom: map['nom'] as String,
    telephone: map['telephone'] as String? ?? '',
    adresse: map['adresse'] as String? ?? '',
    photoBytes: (map['photo'] ?? map['photoBytes']) == null
        ? null
        : base64Decode((map['photo'] ?? map['photoBytes']) as String),
  );

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
