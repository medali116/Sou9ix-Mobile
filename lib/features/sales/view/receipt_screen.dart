import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/sales/service/ticket_pdf_service.dart';
import 'package:sou9ix/features/settings/viewmodel/company_settings_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  final Sale sale;

  const ReceiptScreen({super.key, required this.sale});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  static const _autoReturnSeconds = 3;

  bool _printing = false;
  Timer? _autoReturnTimer;
  int _secondsLeft = _autoReturnSeconds;
  bool _autoReturnActive = true;

  Sale get sale => widget.sale;

  @override
  void initState() {
    super.initState();
    // Lets a cashier chain sales quickly — the receipt clears itself after a
    // beat unless they're still doing something with it (printing) or tap
    // the cancel button below.
    _autoReturnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) context.go('/app');
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
    super.dispose();
  }

  void _cancelAutoReturn() {
    _autoReturnTimer?.cancel();
    if (mounted) setState(() => _autoReturnActive = false);
  }

  Future<void> _printOrShare() async {
    _cancelAutoReturn();
    setState(() => _printing = true);
    try {
      final settings = ref.read(companySettingsProvider);
      await ticketPdfService.printOrShare(
        sale,
        nomTicket: settings.ticketName,
        logoBytes: settings.logoBytes,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy · HH:mm').format(sale.dateHeure);
    final companySettings = ref.watch(companySettingsProvider);

    double? clientNewDebt;
    if (sale.modePaiement == ModePaiement.credit && sale.clientId != null) {
      final matches = ref
          .watch(clientsProvider)
          .where((c) => c.id == sale.clientId);
      if (matches.isNotEmpty) clientNewDebt = matches.first.creditTotal;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 28),
            Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.success,
                    size: 44,
                  ),
                )
                .animate()
                .scale(duration: 450.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 200.ms),
            const SizedBox(height: 16),
            Text(
              'Vente enregistrée',
              style: Theme.of(context).textTheme.headlineMedium,
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 4),
            Text(
              'Ticket #${sale.id.substring(sale.id.length - 6).toUpperCase()}',
              style: Theme.of(context).textTheme.bodyMedium,
            ).animate().fadeIn(delay: 200.ms),
            if (clientNewDebt != null) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dette du client mise à jour',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Nouveau solde : ${AppFormat.dt(clientNewDebt)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 220.ms),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            if (companySettings.logoBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                                child: Image.memory(
                                  companySettings.logoBytes!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Text(
                                companySettings.ticketName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: AppColors.teal),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              'Épicerie El Baraka — La Marsa',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              dateStr,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _DashedDivider(),
                      const SizedBox(height: 12),
                      if (sale.lignes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Détails de vente indisponibles pour cette démo.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        ...sale.lignes.map(
                          (l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    l.discount.isNone
                                        ? l.product.name
                                        : '${l.product.name} (${l.discount.label((v) => v.toStringAsFixed(2))})',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    l.product.venduAuPoids
                                        ? AppFormat.kg(l.quantite)
                                        : '× ${l.quantite.toInt()}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    AppFormat.dtShort(l.sousTotal),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      const _DashedDivider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mode de paiement',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            sale.modePaiement.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (!sale.discount.isNone) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sous-total',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              AppFormat.dtShort(sale.sousTotal),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Remise',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              sale.discount.label(AppFormat.dtShort),
                              style: const TextStyle(
                                color: AppColors.goldDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total TTC',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            AppFormat.dt(sale.total),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Merci de votre visite !',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: QrImageView(
                          data: sale.id,
                          size: 64,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 250.ms, duration: 350.ms).slideY(begin: 0.06, end: 0),
            ),
            if (_autoReturnActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Retour automatique dans ${_secondsLeft}s',
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _cancelAutoReturn,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Annuler le retour automatique',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _printing ? null : _printOrShare,
                      icon: _printing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(
                        _printing ? 'Préparation…' : 'Imprimer / PDF',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _cancelAutoReturn();
                        context.go('/app');
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nouvelle vente'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / 8).floor();
          return Row(
            children: List.generate(
              count,
              (_) => Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.border,
                  margin: const EdgeInsets.only(right: 4),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
