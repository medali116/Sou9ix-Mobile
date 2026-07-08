import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/purchase_invoice.dart';
import '../models/purchase_invoice_line.dart';

class PurchaseInvoicesNotifier extends StateNotifier<List<PurchaseInvoice>> {
  PurchaseInvoicesNotifier() : super(_seed());

  static List<PurchaseInvoice> _seed() {
    final now = DateTime.now();
    return [
      PurchaseInvoice(
        id: 'ach1',
        date: now.subtract(const Duration(days: 2)),
        fournisseur: 'Grossiste Fruits Secs Sfax',
        montantPaye: 165.000,
        lignes: const [
          PurchaseInvoiceLine(
            productId: 'p2',
            productName: 'Amandes décortiquées',
            quantite: 10,
            venduAuPoids: true,
            prixAchatUnitaire: 16.500,
          ),
        ],
      ),
      PurchaseInvoice(
        id: 'ach2',
        date: now.subtract(const Duration(days: 1)),
        fournisseur: 'Torréfaction Ben Ali',
        montantPaye: 60.000,
        lignes: const [
          PurchaseInvoiceLine(
            productId: 'p6',
            productName: 'Café torréfié Arabica',
            quantite: 15,
            venduAuPoids: true,
            prixAchatUnitaire: 12.500,
          ),
          PurchaseInvoiceLine(
            productId: 'p7',
            productName: 'Café moulu Robusta',
            quantite: 5,
            venduAuPoids: true,
            prixAchatUnitaire: 9.800,
          ),
        ],
      ),
    ];
  }

  void add(PurchaseInvoice invoice) => state = [invoice, ...state];

  /// Records an additional payment against an invoice (partial or final) —
  /// clamped so it can never exceed the invoice's total.
  void recordPayment(String invoiceId, double montant) {
    state = [
      for (final i in state)
        if (i.id == invoiceId)
          i.copyWith(montantPaye: (i.montantPaye + montant).clamp(0, i.montantTotal))
        else
          i,
    ];
  }
}

final purchaseInvoicesProvider =
    StateNotifierProvider<PurchaseInvoicesNotifier, List<PurchaseInvoice>>(
  (ref) => PurchaseInvoicesNotifier(),
);

final totalUnpaidPurchasesProvider = Provider<double>((ref) {
  final list = ref.watch(purchaseInvoicesProvider);
  return list.fold(0.0, (sum, i) => sum + i.montantRestant);
});

final unsettledInvoicesProvider = Provider<List<PurchaseInvoice>>((ref) {
  return ref.watch(purchaseInvoicesProvider).where((i) => !i.soldee).toList();
});
