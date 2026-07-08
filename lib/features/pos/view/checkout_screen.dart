import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/clients/model/client.dart';
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
import 'package:sou9ix/core/widgets/sheet_handle.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late ModePaiement _mode;
  String? _clientId;
  bool _processing = false;
  final _clientSearchCtrl = TextEditingController();
  String _clientQuery = '';
  final _montantRecuCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // If a client was attached via "Scanner client" on the Caisse screen,
    // preselect them here and default straight to crédit (karné) payment.
    final pendingClientId = ref.read(pendingClientProvider);
    _clientId = pendingClientId;
    _mode = pendingClientId != null
        ? ModePaiement.credit
        : ModePaiement.especes;
    _montantRecuCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _clientSearchCtrl.dispose();
    _montantRecuCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmer() async {
    final items = ref.read(cartProvider);
    if (items.isEmpty) return;
    if (_mode == ModePaiement.credit && _clientId == null) return;

    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 700));

    final sale = ref
        .read(saleServiceProvider)
        .checkout(
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

  Future<void> _openNewClientSheet() async {
    final nomCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final created = await showModalBottomSheet<Client>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 14),
                Text(
                  'Nouveau client',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nomCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Nom du client'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Téléphone'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final nom = nomCtrl.text.trim();
                      if (nom.isEmpty) return;
                      final client = ref
                          .read(clientsProvider.notifier)
                          .addClient(nom: nom, telephone: telCtrl.text.trim());
                      Navigator.pop(sheetContext, client);
                    },
                    child: const Text('Ajouter le client'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (created != null) {
      setState(() {
        _clientId = created.id;
        _clientQuery = '';
        _clientSearchCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final total = ref.watch(cartTotalProvider);
    final ticketDiscount = ref.watch(cartDiscountProvider);
    final clients = ref.watch(clientsProvider);

    Client? selectedClient;
    if (_clientId != null) {
      final matches = clients.where((c) => c.id == _clientId);
      selectedClient = matches.isEmpty ? null : matches.first;
    }

    final filteredClients = _clientQuery.isEmpty
        ? clients
        : clients.where((c) {
            final q = _clientQuery.toLowerCase();
            final phone = c.telephone.replaceAll(' ', '').toLowerCase();
            return c.nom.toLowerCase().contains(q) ||
                phone.contains(q.replaceAll(' ', ''));
          }).toList();

    final needsClient = _mode == ModePaiement.credit && _clientId == null;

    final montantRecu =
        double.tryParse(_montantRecuCtrl.text.replaceAll(',', '.')) ?? 0;
    final rendu = (montantRecu - total).clamp(0, double.infinity);

    final canConfirm = !_processing && items.isNotEmpty && !needsClient;

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
                    Text(
                      '${items.length} article${items.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      AppFormat.dt(subtotal),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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
                          ref.read(cartDiscountProvider.notifier).state =
                              result;
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sell_outlined,
                            size: 15,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ticketDiscount.isNone
                                ? 'Ajouter une remise'
                                : 'Remise ticket',
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!ticketDiscount.isNone)
                      Text(
                        ticketDiscount.label(AppFormat.dtShort),
                        style: const TextStyle(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total à payer',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      AppFormat.dt(total),
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0),
          const SizedBox(height: 24),
          Text(
            'Mode de paiement',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
          if (_mode != ModePaiement.credit) ...[
            const SizedBox(height: 20),
            Text(
              'Montant reçu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _montantRecuCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: '0.000',
                suffixText: 'DT',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rendu',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    AppFormat.dt(rendu),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: rendu > 0
                          ? AppColors.success
                          : AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_mode == ModePaiement.credit) ...[
            const SizedBox(height: 20),
            Text(
              'Client (karné)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _clientSearchCtrl,
                    onChanged: (v) => setState(() => _clientQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un client...',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PressScale(
                  onTap: _openNewClientSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.teal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppColors.teal,
                          size: 18,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Nouveau',
                          style: TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (needsClient) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sélectionnez un client pour une vente à crédit.',
                        style: TextStyle(
                          color: AppColors.goldDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (filteredClients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Aucun client trouvé.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...filteredClients.map((c) {
                final selected = c.id == _clientId;
                return PressScale(
                  onTap: () => setState(() => _clientId = c.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: selected ? AppColors.success : AppColors.border,
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.gold.withValues(
                            alpha: 0.18,
                          ),
                          foregroundColor: AppColors.goldDark,
                          child: Text(c.nom.substring(0, 1)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.nom,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              _DebtBadge(amount: c.creditTotal),
                            ],
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: selected
                              ? AppColors.success
                              : AppColors.textFaint,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            if (selectedClient != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Ancienne dette',
                      value: AppFormat.dt(selectedClient.creditTotal),
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Nouvelle vente',
                      value: AppFormat.dt(total),
                    ),
                    const Divider(height: 22),
                    _SummaryRow(
                      label: 'Nouvelle dette',
                      value: AppFormat.dt(selectedClient.creditTotal + total),
                      bold: true,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child:
              SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: canConfirm ? _confirmer : null,
                      icon: _processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _processing
                            ? 'Traitement…'
                            : 'Encaisser ${AppFormat.dt(total)}',
                      ),
                    ),
                  )
                  .animate(
                    target: _processing ? 1 : 0,
                    onPlay: (c) => c.repeat(),
                  )
                  .shimmer(
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
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
          ),
          boxShadow: selected
              ? AppShadows.colored(AppColors.teal)
              : AppShadows.card,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.textSecondary,
              size: 22,
            ),
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

/// Small colored-dot pill replacing the plain "Solde dû : X DT" text so a
/// client's debt status reads at a glance — red when they owe money, green
/// when their karné is clear.
class _DebtBadge extends StatelessWidget {
  final double amount;
  const _DebtBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    final hasDebt = amount > 0;
    final color = hasDebt ? AppColors.danger : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            hasDebt ? 'Dette : ${AppFormat.dt(amount)}' : 'Aucune dette',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontSize: bold ? 14.5 : 13.5,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            fontSize: bold ? 16 : 13.5,
            color: bold ? AppColors.goldDark : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
