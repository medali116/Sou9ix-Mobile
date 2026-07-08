import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/stock/model/draft_invoice_line.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice_line.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';

/// Encapsulates receiving a supplier invoice: every staged line either
/// restocks an existing product or creates a brand-new one, then the
/// invoice itself (with whatever has been paid so far) is recorded —
/// keeping the catalogue and the invoice history in lockstep.
class PurchaseService {
  PurchaseService(this._ref);

  final Ref _ref;

  PurchaseInvoice receiveInvoice({
    required List<DraftInvoiceLine> lines,
    Supplier? supplier,
    Uint8List? photoBytes,
    required double montantPaye,
  }) {
    final invoiceLines = <PurchaseInvoiceLine>[];
    for (final line in lines) {
      if (line.existingProduct != null) {
        _ref.read(productsProvider.notifier).restock(
              line.existingProduct!.id,
              line.quantite,
              nouveauPrixAchat: line.prixAchatUnitaire,
            );
        invoiceLines.add(PurchaseInvoiceLine(
          productId: line.existingProduct!.id,
          productName: line.existingProduct!.name,
          quantite: line.quantite,
          venduAuPoids: line.venduAuPoids,
          prixAchatUnitaire: line.prixAchatUnitaire,
        ));
      } else {
        final product = line.newProductDraft!;
        _ref.read(productsProvider.notifier).upsert(product);
        invoiceLines.add(PurchaseInvoiceLine(
          productId: product.id,
          productName: product.name,
          quantite: line.quantite,
          venduAuPoids: line.venduAuPoids,
          prixAchatUnitaire: line.prixAchatUnitaire,
        ));
      }
    }

    final invoice = PurchaseInvoice(
      id: 'ach${DateTime.now().microsecondsSinceEpoch}',
      date: DateTime.now(),
      fournisseurId: supplier?.id,
      fournisseurNom: supplier?.nom,
      photoBytes: photoBytes,
      lignes: invoiceLines,
      montantPaye: montantPaye.clamp(0, double.infinity),
    );
    _ref.read(purchaseInvoicesProvider.notifier).add(invoice);
    return invoice;
  }
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) => PurchaseService(ref));
