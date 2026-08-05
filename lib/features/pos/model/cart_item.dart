import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/products/model/product.dart';

class CartItem {
  final Product product;
  final double quantite; // pieces or kg depending on product.venduAuPoids
  final Discount discount;

  /// For a weighed product, the kg amount that was entered when the line
  /// was created (or last manually re-typed) — the "unit" the +/- stepper
  /// steps by, so a cashier who weighs 2kg once can then tap + to add
  /// another 2kg (4kg), + again for 6kg, etc. Unused for piece products.
  final double? poidsUnitaire;

  const CartItem({
    required this.product,
    required this.quantite,
    this.poidsUnitaire,
    this.discount = const Discount.none(),
  });

  double get sousTotalAvantRemise => product.prixVente * quantite;
  double get sousTotal => discount.applyTo(sousTotalAvantRemise);

  CartItem copyWith({
    double? quantite,
    double? poidsUnitaire,
    Discount? discount,
  }) => CartItem(
    product: product,
    quantite: quantite ?? this.quantite,
    poidsUnitaire: poidsUnitaire ?? this.poidsUnitaire,
    discount: discount ?? this.discount,
  );

  /// Embeds a full snapshot of [product] as it was at sale time (not a
  /// reference) — a later price/name change on the catalogue must never
  /// alter what a past ticket shows it sold for.
  Map<String, dynamic> toMap() => {
    'productId': product.id,
    'produit': product.toMap(),
    'quantite': quantite,
    'poidsUnitaire': poidsUnitaire,
    'remise': discount.toMap(),
  };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    product: Product.fromMap(
      map['productId'] as String,
      (map['produit'] ?? map['product']) as Map<String, dynamic>,
    ),
    quantite: (map['quantite'] as num).toDouble(),
    poidsUnitaire: (map['poidsUnitaire'] as num?)?.toDouble(),
    discount: Discount.fromMap(
      (map['remise'] ?? map['discount']) as Map<String, dynamic>?,
    ),
  );
}
