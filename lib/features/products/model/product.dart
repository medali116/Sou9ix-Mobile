import 'dart:typed_data';

class Product {
  final String id;
  final String name;
  final String emoji;
  final Uint8List? photoBytes;
  final double prixVente;
  final double prixAchat;
  final String? codeBarres;
  final bool venduAuPoids;
  final String categorieId;
  final double stock;
  final double seuilAlerte;
  final DateTime? datePeremption;

  const Product({
    required this.id,
    required this.name,
    required this.emoji,
    this.photoBytes,
    required this.prixVente,
    required this.prixAchat,
    this.codeBarres,
    required this.venduAuPoids,
    required this.categorieId,
    required this.stock,
    required this.seuilAlerte,
    this.datePeremption,
  });

  double get marge => prixVente - prixAchat;
  double get margePct => prixAchat == 0 ? 0 : (marge / prixAchat) * 100;
  bool get stockFaible => stock <= seuilAlerte;
  String get unite => venduAuPoids ? 'kg' : 'pc';

  Product copyWith({
    String? name,
    Uint8List? photoBytes,
    double? prixVente,
    double? prixAchat,
    String? codeBarres,
    bool? venduAuPoids,
    String? categorieId,
    double? stock,
    double? seuilAlerte,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      emoji: emoji,
      photoBytes: photoBytes ?? this.photoBytes,
      prixVente: prixVente ?? this.prixVente,
      prixAchat: prixAchat ?? this.prixAchat,
      codeBarres: codeBarres ?? this.codeBarres,
      venduAuPoids: venduAuPoids ?? this.venduAuPoids,
      categorieId: categorieId ?? this.categorieId,
      stock: stock ?? this.stock,
      seuilAlerte: seuilAlerte ?? this.seuilAlerte,
      datePeremption: datePeremption,
    );
  }
}
