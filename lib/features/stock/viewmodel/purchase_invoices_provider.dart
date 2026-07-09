import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice_line.dart';

class PurchaseInvoicesNotifier extends StateNotifier<List<PurchaseInvoice>> {
  PurchaseInvoicesNotifier() : super(_seed());

  static List<PurchaseInvoice> _seed() {
    final now = DateTime.now();
    return [
      PurchaseInvoice(
        id: 'ach1',
        date: now.subtract(const Duration(days: 2)),
        fournisseurId: 'f1',
        fournisseurNom: 'Grossiste Fruits Secs Sfax',
        paiements: [
          PurchaseInvoicePayment(
            id: 'pay1',
            montant: 165.000,
            date: now.subtract(const Duration(days: 2)),
            modePaiement: PurchasePaymentMethod.especes,
          ),
        ],
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
        fournisseurId: 'f2',
        fournisseurNom: 'Torréfaction Ben Ali',
        paiements: [
          PurchaseInvoicePayment(
            id: 'pay2',
            montant: 35.000,
            date: now.subtract(const Duration(days: 1)),
            modePaiement: PurchasePaymentMethod.especes,
          ),
          PurchaseInvoicePayment(
            id: 'pay3',
            montant: 25.000,
            date: now.subtract(const Duration(hours: 6)),
            modePaiement: PurchasePaymentMethod.virement,
          ),
        ],
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
  /// clamped so a single payment can never exceed what's still owed.
  void recordPayment(
    String invoiceId,
    double montant, {
    PurchasePaymentMethod? modePaiement,
  }) {
    state = [
      for (final i in state)
        if (i.id == invoiceId)
          i.copyWith(
            paiements: [
              ...i.paiements,
              PurchaseInvoicePayment(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                montant: montant.clamp(0, i.montantRestant),
                date: DateTime.now(),
                modePaiement: modePaiement,
              ),
            ],
          )
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

final supplierInvoicesProvider = Provider.family<List<PurchaseInvoice>, String>(
  (ref, supplierId) {
    return ref
        .watch(purchaseInvoicesProvider)
        .where((i) => i.fournisseurId == supplierId)
        .toList();
  },
);
