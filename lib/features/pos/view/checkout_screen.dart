import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/pos/view/discount_editor_sheet.dart';
import 'package:sou9ix/features/pos/viewmodel/cart_provider.dart';
import 'package:sou9ix/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/features/pos/viewmodel/pending_sale_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/features/sales/service/sale_service.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late ModePaiement _mode;
  String? _clientId;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    // If a client was attached via "Scanner client" on the Caisse screen,
    // preselect them here and default straight to crédit (karné) payment.
    final pendingClientId = ref.read(pendingClientProvider);
    _clientId = pendingClientId;
    _mode = pendingClientId != null ? ModePaiement.credit : ModePaiement.especes;
  }

  Future<void> _confirmer() async {
    final items = ref.read(cartProvider);
    if (items.isEmpty) return;
    if (_mode == ModePaiement.credit && _clientId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sélectionnez un client pour le crédit')));
      return;
    }

    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 700));

    final sale = ref.read(saleServiceProvider).checkout(
          lignes: items,
          modePaiement: _mode,
          clientId: _clientId,
          employeeId: ref.read(activeEmployeeProvider),
          discount: ref.read(cartDiscountProvider),
        );
    ref.read(cartProvider.notifier).clear();
    ref.read(cartDiscountProvider.notifier).state = const Discount.none();
    ref.read(pendingClientProvider.notifier).state = null;

    if (!mounted) return;
    context.pushReplacement('/receipt', extra: sale);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final total = ref.watch(cartTotalProvider);
    final ticketDiscount = ref.watch(cartDiscountProvider);
    final clients = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Encaissement')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${items.length} article${items.length > 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text(AppFormat.dt(subtotal), style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PressScale(
                      onTap: () async {
                        final result = await DiscountEditorSheet.show(
                          context,
                          title: 'Remise sur le ticket',
                          initial: ticketDiscount,
                        );
                        if (result != null) {
                          ref.read(cartDiscountProvider.notifier).state = result;
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sell_outlined, size: 15, color: AppColors.teal),
                          const SizedBox(width: 4),
                          Text(
                            ticketDiscount.isNone ? 'Ajouter une remise' : 'Remise ticket',
                            style: const TextStyle(
                                color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    if (!ticketDiscount.isNone)
                      Text(
                        ticketDiscount.label(AppFormat.dtShort),
                        style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total à payer', style: Theme.of(context).textTheme.titleMedium),
                    Text(AppFormat.dt(total), style: Theme.of(context).textTheme.displaySmall),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0),
          const SizedBox(height: 24),
          Text('Mode de paiement', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PaymentOption(
                  label: 'Espèces',
                  icon: Icons.payments_rounded,
                  selected: _mode == ModePaiement.especes,
                  onTap: () => setState(() => _mode = ModePaiement.especes),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentOption(
                  label: 'Carte',
                  icon: Icons.credit_card_rounded,
                  selected: _mode == ModePaiement.carte,
                  onTap: () => setState(() => _mode = ModePaiement.carte),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentOption(
                  label: 'Crédit',
                  icon: Icons.menu_book_rounded,
                  selected: _mode == ModePaiement.credit,
                  onTap: () => setState(() => _mode = ModePaiement.credit),
                ),
              ),
            ],
          ),
          if (_mode == ModePaiement.credit) ...[
            const SizedBox(height: 20),
            Text('Client (karné)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...clients.map((c) {
              final selected = c.id == _clientId;
              return PressScale(
                onTap: () => setState(() => _clientId = c.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.teal.withValues(alpha: 0.08) : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: selected ? AppColors.teal : AppColors.border,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                        foregroundColor: AppColors.goldDark,
                        child: Text(c.nom.substring(0, 1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.nom, style: Theme.of(context).textTheme.titleMedium),
                            Text('Solde dû : ${AppFormat.dt(c.creditTotal)}',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: selected ? AppColors.teal : AppColors.textFaint,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _processing ? null : _confirmer,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_processing ? 'Traitement…' : 'Confirmer & encaisser'),
            ),
          ).animate(target: _processing ? 1 : 0, onPlay: (c) => c.repeat()).shimmer(
                duration: 1100.ms,
                color: Colors.white.withValues(alpha: 0.45),
              ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.teal : AppColors.border),
          boxShadow: selected ? AppShadows.colored(AppColors.teal) : AppShadows.card,
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : AppColors.textSecondary, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
