enum DiscountType { none, percent, amount }

/// A discount applied to a price — either a percentage off, or a flat
/// amount off, or none. Shared between a cart line ([CartItem]) and a
/// whole ticket ([Sale]) so both apply the exact same rule.
class Discount {
  final DiscountType type;
  final double value;

  const Discount.none()
      : type = DiscountType.none,
        value = 0;
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
