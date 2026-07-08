import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/products/model/product.dart';

class CartItem {
  final Product product;
  final double quantite; // pieces or kg depending on product.venduAuPoids
  final Discount discount;

  const CartItem({
    required this.product,
    required this.quantite,
    this.discount = const Discount.none(),
  });

  double get sousTotalAvantRemise => product.prixVente * quantite;
  double get sousTotal => discount.applyTo(sousTotalAvantRemise);

  CartItem copyWith({double? quantite, Discount? discount}) => CartItem(
        product: product,
        quantite: quantite ?? this.quantite,
        discount: discount ?? this.discount,
      );
}
