import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/core/models/discount.dart';
import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/trash_provider.dart';
import 'package:sou9ix/shared/features/pos/model/cart_item.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/sales/service/sales_repository.dart';
import 'package:sou9ix/shared/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/shared/features/stock/model/stock_movement.dart';
import 'package:sou9ix/shared/features/stock/viewmodel/stock_movements_provider.dart';

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
  ///
  /// A client is only ever attached to the sale for a crédit payment — a
  /// client scanned ahead of time on the Caisse screen but then paid in
  /// cash/carte shouldn't have their name recorded on the ticket.
  ///
  /// Every one of those writes (the Sale doc, each product's stock
  /// decrement, each stock-movement log entry, the client's credit
  /// increment) is folded into a single [SalesRepository.recordSaleBatch]
  /// atomic write — this is the highest-contention path in the app (two
  /// cashiers on two devices could hit "payer" on the same product at
  /// once), so it's the one write path in this migration that isn't just
  /// "optimistic local update + a handful of independent background
  /// writes". Locally, every provider still updates immediately via its
  /// `*Local` variant, so the UI feels exactly as instant as before.
  Sale checkout({
    required List<CartItem> lignes,
    required ModePaiement modePaiement,
    String? clientId,
    String? employeeId,
    Discount discount = const Discount.none(),
  }) {
    final effectiveClientId = modePaiement == ModePaiement.credit
        ? clientId
        : null;
    final sale = Sale(
      id: 'v${DateTime.now().microsecondsSinceEpoch}',
      dateHeure: DateTime.now(),
      lignes: lignes,
      modePaiement: modePaiement,
      clientId: effectiveClientId,
      employeeId: employeeId,
      discount: discount,
    );
    _ref.read(salesProvider.notifier).addLocal(sale);

    final movements = <StockMovement>[];
    final stockDeltas = <String, double>{};
    for (final item in lignes) {
      _ref
          .read(productsProvider.notifier)
          .decrementStockLocal(item.product.id, item.quantite);
      final movement = buildStockMovement(
        _ref,
        productId: item.product.id,
        productName: item.product.name,
        type: StockMovementType.vente,
        quantite: -item.quantite,
        stockApres: _currentStock(item.product.id),
        reference: 'Ticket #${_reference(sale)}',
      );
      _ref.read(stockMovementsProvider.notifier).recordLocal(movement);
      movements.add(movement);
      stockDeltas[item.product.id] =
          (stockDeltas[item.product.id] ?? 0) - item.quantite;
    }

    double? creditDelta;
    if (modePaiement == ModePaiement.credit && effectiveClientId != null) {
      _ref
          .read(clientsProvider.notifier)
          .addCreditLocal(effectiveClientId, sale.total);
      creditDelta = sale.total;
    }

    unawaited(
      _ref
          .read(salesRepositoryProvider)
          ?.recordSaleBatch(
            sale: sale,
            stockDeltas: stockDeltas,
            movements: movements,
            creditClientId: effectiveClientId,
            creditDelta: creditDelta,
          ),
    );
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
    final oldQty = <String, double>{
      for (final l in original.lignes) l.product.id: l.quantite,
    };
    final newQty = <String, double>{
      for (final l in lignes) l.product.id: l.quantite,
    };
    final productNames = <String, String>{
      for (final l in [...original.lignes, ...lignes])
        l.product.id: l.product.name,
    };
    for (final id in {...oldQty.keys, ...newQty.keys}) {
      final delta = (oldQty[id] ?? 0) - (newQty[id] ?? 0);
      if (delta != 0) {
        _ref.read(productsProvider.notifier).adjustStock(id, delta);
        recordStockMovement(
          _ref,
          productId: id,
          productName: productNames[id] ?? id,
          type: StockMovementType.ajustement,
          quantite: delta,
          stockApres: _currentStock(id),
          reference: 'Ticket #${_reference(original)} modifié',
        );
      }
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

    if (original.modePaiement == ModePaiement.credit &&
        original.clientId != null) {
      _ref
          .read(clientsProvider.notifier)
          .addCredit(original.clientId!, -original.total);
    }
    if (updated.modePaiement == ModePaiement.credit &&
        updated.clientId != null) {
      _ref
          .read(clientsProvider.notifier)
          .addCredit(updated.clientId!, updated.total);
    }

    _ref.read(salesProvider.notifier).updateSale(updated);
  }

  static String _reference(Sale sale) => sale.id.length > 6
      ? sale.id.substring(sale.id.length - 6).toUpperCase()
      : sale.id.toUpperCase();

  double _currentStock(String productId) =>
      _ref.read(productsProvider).firstWhere((p) => p.id == productId).stock;

  /// Reverses a sale entirely: restores the stock it consumed, cancels the
  /// client credit it created (if any), then removes the record — but
  /// keeps a copy in the Corbeille (see [restoreSale]) rather than
  /// destroying it outright.
  void deleteSale(Sale sale, {required String motif}) {
    for (final l in sale.lignes) {
      _ref
          .read(productsProvider.notifier)
          .adjustStock(l.product.id, l.quantite);
      recordStockMovement(
        _ref,
        productId: l.product.id,
        productName: l.product.name,
        type: StockMovementType.ajustement,
        quantite: l.quantite,
        stockApres: _currentStock(l.product.id),
        reference: 'Ticket #${_reference(sale)} supprimé',
        motif: motif,
      );
    }
    if (sale.modePaiement == ModePaiement.credit && sale.clientId != null) {
      _ref
          .read(clientsProvider.notifier)
          .addCredit(sale.clientId!, -sale.total);
    }
    _ref.read(salesProvider.notifier).removeSale(sale.id);
    _ref.read(salesTrashProvider.notifier).add(sale);

    logActivity(
      _ref,
      category: ActivityCategory.tickets,
      impact: ActivityImpact.suppression,
      action: 'Ticket supprimé',
      targetName: 'Ticket #${_reference(sale)}',
      montant: sale.total,
      motif: motif,
    );
  }

  /// Brings a deleted ticket back from the Corbeille: reapplies the stock
  /// and client-credit effects it originally had (mirroring [checkout]),
  /// then puts the sale itself back with its original id.
  void restoreSale(Sale sale) {
    for (final l in sale.lignes) {
      _ref
          .read(productsProvider.notifier)
          .decrementStock(l.product.id, l.quantite);
      recordStockMovement(
        _ref,
        productId: l.product.id,
        productName: l.product.name,
        type: StockMovementType.ajustement,
        quantite: -l.quantite,
        stockApres: _currentStock(l.product.id),
        reference: 'Ticket #${_reference(sale)} restauré',
      );
    }
    if (sale.modePaiement == ModePaiement.credit && sale.clientId != null) {
      _ref.read(clientsProvider.notifier).addCredit(sale.clientId!, sale.total);
    }
    _ref.read(salesProvider.notifier).restore(sale);
    _ref.read(salesTrashProvider.notifier).removeById(sale.id);

    logActivity(
      _ref,
      category: ActivityCategory.tickets,
      impact: ActivityImpact.ajout,
      action: 'Ticket restauré',
      targetName: 'Ticket #${_reference(sale)}',
      montant: sale.total,
    );
  }
}

final saleServiceProvider = Provider<SaleService>((ref) => SaleService(ref));
