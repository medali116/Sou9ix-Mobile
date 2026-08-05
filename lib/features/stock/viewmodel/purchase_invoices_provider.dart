import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/service/purchase_invoices_repository.dart';

class PurchaseInvoicesNotifier extends StateNotifier<List<PurchaseInvoice>> {
  PurchaseInvoicesNotifier(
    this._ref, {
    required String? shopCode,
    PurchaseInvoicesRepository? repository,
  }) : _repo = shopCode == null
           ? null
           : (repository ?? PurchaseInvoicesRepository(shopCode: shopCode)),
       super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((invoices) => state = invoices);
    }
  }

  final Ref _ref;
  final PurchaseInvoicesRepository? _repo;
  StreamSubscription<List<PurchaseInvoice>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void add(PurchaseInvoice invoice) {
    state = [invoice, ...state];
    _repo?.upsert(invoice);
  }

  /// Records an additional payment against an invoice (partial or final) —
  /// clamped so a single payment can never exceed what's still owed.
  void recordPayment(
    String invoiceId,
    double montant, {
    PurchasePaymentMethod? modePaiement,
  }) {
    PurchaseInvoice? updated;
    state = [
      for (final i in state)
        if (i.id == invoiceId)
          (updated = i.copyWith(
            paiements: [
              ...i.paiements,
              PurchaseInvoicePayment(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                montant: montant.clamp(0, i.montantRestant),
                date: DateTime.now(),
                modePaiement: modePaiement,
              ),
            ],
          ))
        else
          i,
    ];
    if (updated != null) _repo?.upsert(updated);
    final matches = state.where((i) => i.id == invoiceId);
    logActivity(
      _ref,
      category: ActivityCategory.fournisseurs,
      impact: ActivityImpact.paiement,
      action: 'Paiement fournisseur',
      targetName: matches.isEmpty ? null : matches.first.fournisseurNom,
      montant: montant,
    );
  }
}

final purchaseInvoicesProvider =
    StateNotifierProvider<PurchaseInvoicesNotifier, List<PurchaseInvoice>>(
      (ref) => PurchaseInvoicesNotifier(
        ref,
        shopCode: ref.watch(currentShopCodeProvider),
      ),
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
