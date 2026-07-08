import 'product.dart';

class CartItem {
  final Product product;
  final double quantite; // pieces or kg depending on product.venduAuPoids

  const CartItem({required this.product, required this.quantite});

  double get sousTotal => product.prixVente * quantite;

  CartItem copyWith({double? quantite}) =>
      CartItem(product: product, quantite: quantite ?? this.quantite);
}
