import 'package:sou9ix/shared/core/models/discount.dart';

/// Shared [Discount] <-> Firestore map codec — used by every domain that
/// embeds a discount (PurchaseInvoice, Sale, ...), kept in one place so
/// they all encode/decode it identically.
Map<String, dynamic> discountToMap(Discount discount) => {
  'type': discount.type.name,
  'value': discount.value,
};

Discount discountFromMap(Map<String, dynamic>? map) {
  if (map == null) return const Discount.none();
  final type = DiscountType.values.firstWhere(
    (t) => t.name == map['type'],
    orElse: () => DiscountType.none,
  );
  final value = (map['value'] as num?)?.toDouble() ?? 0;
  return switch (type) {
    DiscountType.none => const Discount.none(),
    DiscountType.percent => Discount.percent(value),
    DiscountType.amount => Discount.amount(value),
  };
}
