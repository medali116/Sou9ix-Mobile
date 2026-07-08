import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/pos/model/cart_item.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';

/// Encapsulates the multi-step domain transactions around a [Sale]: every
/// place a sale is created, edited or deleted must keep stock and client
/// credit (karné) reconciled against it exactly the same way, so that logic
/// lives here once instead of being re-implemented per screen.
class SaleService {
  SaleService(this._ref);

  final Ref _ref;

  /// Records a new sale, decrements stock for every line sold, and — for a
  /// crédit (karné) payment — adds the total to the client's outstanding
  /// balance.
  Sale checkout({
    required List<CartItem> lignes,
    required ModePaiement modePaiement,
    String? clientId,
    String? employeeId,
    Discount discount = const Discount.none(),
  }) {
    final sale = _ref.read(salesProvider.notifier).recordSale(
          lignes: lignes,
          modePaiement: modePaiement,
          clientId: clientId,
          employeeId: employeeId,
          discount: discount,
        );

    for (final item in lignes) {
      _ref.read(productsProvider.notifier).decrementStock(item.product.id, item.quantite);
    }
    if (modePaiement == ModePaiement.credit && clientId != null) {
      _ref.read(clientsProvider.notifier).addCredit(clientId, sale.total);
    }
    return sale;
  }

  /// Replaces [original] with a corrected version, reconciling stock and
  /// client credit against what the *original* sale had applied — mirroring
  /// how [checkout] applies them in the first place.
  void updateSale({
    required Sale original,
    required List<CartItem> lignes,
    required ModePaiement modePaiement,
    String? clientId,
    Discount discount = const Discount.none(),
  }) {
    final oldQty = <String, double>{for (final l in original.lignes) l.product.id: l.quantite};
    final newQty = <String, double>{for (final l in lignes) l.product.id: l.quantite};
    for (final id in {...oldQty.keys, ...newQty.keys}) {
      final delta = (oldQty[id] ?? 0) - (newQty[id] ?? 0);
      if (delta != 0) _ref.read(productsProvider.notifier).adjustStock(id, delta);
    }

    final updated = Sale(
      id: original.id,
      dateHeure: original.dateHeure,
      lignes: lignes,
      modePaiement: modePaiement,
      clientId: modePaiement == ModePaiement.credit ? clientId : null,
      employeeId: original.employeeId,
      discount: discount,
    );

    if (original.modePaiement == ModePaiement.credit && original.clientId != null) {
      _ref.read(clientsProvider.notifier).addCredit(original.clientId!, -original.total);
    }
    if (updated.modePaiement == ModePaiement.credit && updated.clientId != null) {
      _ref.read(clientsProvider.notifier).addCredit(updated.clientId!, updated.total);
    }

    _ref.read(salesProvider.notifier).updateSale(updated);
  }

  /// Reverses a sale entirely: restores the stock it consumed, cancels the
  /// client credit it created (if any), then removes the record.
  void deleteSale(Sale sale) {
    for (final l in sale.lignes) {
      _ref.read(productsProvider.notifier).adjustStock(l.product.id, l.quantite);
    }
    if (sale.modePaiement == ModePaiement.credit && sale.clientId != null) {
      _ref.read(clientsProvider.notifier).addCredit(sale.clientId!, -sale.total);
    }
    _ref.read(salesProvider.notifier).removeSale(sale.id);
  }
}

final saleServiceProvider = Provider<SaleService>((ref) => SaleService(ref));
