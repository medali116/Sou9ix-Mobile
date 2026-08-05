enum DiscountType { none, percent, amount }

/// A discount applied to a price — either a percentage off, or a flat
/// amount off, or none. Shared between a cart line ([CartItem]) and a
/// whole ticket ([Sale]) so both apply the exact same rule.
class Discount {
  final DiscountType type;
  final double value;

  const Discount.none() : type = DiscountType.none, value = 0;
  const Discount.percent(this.value) : type = DiscountType.percent;
  const Discount.amount(this.value) : type = DiscountType.amount;

  bool get isNone => type == DiscountType.none || value <= 0;

  /// Amount deducted from [base] by this discount (never more than [base]).
  double amountOff(double base) {
    if (isNone) return 0;
    final off = type == DiscountType.percent ? base * value / 100 : value;
    return off.clamp(0, base);
  }

  double applyTo(double base) => base - amountOff(base);

  Map<String, dynamic> toMap() => {'type': type.name, 'valeur': value};

  factory Discount.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const Discount.none();
    final type = DiscountType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => DiscountType.none,
    );
    final value = (map['valeur'] as num? ?? map['value'] as num?)?.toDouble() ?? 0;
    return switch (type) {
      DiscountType.none => const Discount.none(),
      DiscountType.percent => Discount.percent(value),
      DiscountType.amount => Discount.amount(value),
    };
  }

  String label(String Function(num) formatAmount) {
    switch (type) {
      case DiscountType.none:
        return '';
      case DiscountType.percent:
        return '-${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}%';
      case DiscountType.amount:
        return '-${formatAmount(value)}';
    }
  }
}
