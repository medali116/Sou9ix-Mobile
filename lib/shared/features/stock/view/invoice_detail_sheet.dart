import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';

enum _EventKind { creation, paiement }

class _TimelineRow {
  final _EventKind kind;
  final DateTime date;
  final double montant;
  final String? reference;
  final PurchasePaymentMethod? mode;
  final double resteApres;

  const _TimelineRow({
    required this.kind,
    required this.date,
    required this.montant,
    required this.resteApres,
    this.reference,
    this.mode,
  });
}

/// Full picture of a supplier invoice: its products and — most
/// importantly — a chronological "Facture créée → Paiement → Reste → ...
/// → Soldée" timeline, so an owner can see exactly when and how much was
/// paid on each installment without doing the math themselves.
void showInvoiceDetailSheet(BuildContext context, PurchaseInvoice invoice) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _InvoiceDetailSheet(invoice: invoice),
  );
}

class _InvoiceDetailSheet extends StatelessWidget {
  final PurchaseInvoice invoice;
  const _InvoiceDetailSheet({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final paiementsAsc = List.of(invoice.paiements)
      ..sort((a, b) => a.date.compareTo(b.date));

    var running = invoice.montantTotal;
    final rows = <_TimelineRow>[
      _TimelineRow(
        kind: _EventKind.creation,
        date: invoice.date,
        montant: invoice.montantTotal,
        resteApres: running,
      ),
    ];
    for (final p in paiementsAsc) {
      running = (running - p.montant).clamp(0, double.infinity).toDouble();
      rows.add(
        _TimelineRow(
          kind: _EventKind.paiement,
          date: p.date,
          montant: p.montant,
          reference: p.reference,
          mode: p.modePaiement,
          resteApres: running,
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 14),
            Text(
              'Facture #${invoice.reference}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy').format(invoice.date),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (invoice.lignes.isNotEmpty) ...[
              Text(
                'Produits',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final l in invoice.lignes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${l.quantite.toStringAsFixed(l.venduAuPoids ? 3 : 0)} ${l.unite} ${l.productName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        AppFormat.dtShort(l.montant),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 26),
            ],
            Text(
              'Historique des paiements',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final r in rows) ...[
              _EventTile(row: r),
              if (r != rows.last) const SizedBox(height: 10),
            ],
            const Divider(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summary('Facture', AppFormat.dt(invoice.montantTotal)),
                _summary(
                  'Payé',
                  AppFormat.dt(invoice.montantPaye),
                  color: AppColors.success,
                ),
                invoice.soldee
                    ? _summary('Statut', 'Soldée ✅', color: AppColors.success)
                    : _summary(
                        'Reste',
                        AppFormat.dt(invoice.montantRestant),
                        color: AppColors.danger,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(
    String label,
    String value, {
    Color color = AppColors.textPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final _TimelineRow row;
  const _EventTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final isCreation = row.kind == _EventKind.creation;
    final color = isCreation ? AppColors.info : AppColors.success;
    final soldee = row.resteApres <= 0.001;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCreation ? Icons.description_outlined : Icons.payments_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isCreation
                            ? 'Facture créée'
                            : 'Paiement${row.reference != null ? ' #${row.reference}' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      '${isCreation ? '' : '-'}${AppFormat.dtShort(row.montant)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd/MM/yyyy · HH:mm').format(row.date),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textFaint,
                  ),
                ),
                if (row.mode != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        row.mode!.icon,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        row.mode!.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  soldee
                      ? 'Facture soldée ✅'
                      : 'Reste : ${AppFormat.dtShort(row.resteApres)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: soldee ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
