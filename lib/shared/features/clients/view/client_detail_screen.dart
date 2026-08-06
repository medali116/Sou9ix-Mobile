import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/clients/model/client.dart';
import 'package:sou9ix/shared/features/clients/service/client_payment_receipt_service.dart';
import 'package:sou9ix/shared/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';
import 'package:sou9ix/shared/core/widgets/stat_card.dart';

enum _EntryType { vente, paiement, ajustement }

class _TimelineEntry {
  final _EntryType type;
  final double montant;
  final DateTime date;
  final String? reference;
  final PaymentMethod? modePaiement;
  final String? notes;

  const _TimelineEntry({
    required this.type,
    required this.montant,
    required this.date,
    this.reference,
    this.modePaiement,
    this.notes,
  });

  double get signedDelta => type == _EntryType.paiement ? -montant : montant;
}

/// Full profile for one karné client: contact info, current balance, and
/// two tabs — "Historique" (a single chronological feed of purchases and
/// payments, each with the running balance before/after) and "Tickets"
/// (every credit sale with its own paid/remaining status, since the running
/// balance alone can't tell an owner which specific invoices are still
/// open). Payments are allocated to tickets FIFO: the oldest open ticket is
/// settled first.
///
/// Balances are replayed *backward* from [Client.creditTotal] (the one
/// number guaranteed correct) rather than forward from an assumed zero,
/// since seeded/legacy clients can carry a starting balance with no
/// transaction behind it.
class ClientDetailScreen extends ConsumerWidget {
  final Client client;
  const ClientDetailScreen({super.key, required this.client});

  Future<void> _call(String phone) async {
    await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
  }

  Future<void> _whatsapp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    await launchUrl(
      Uri.parse('https://wa.me/$digits'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openContactMenu(BuildContext context, String phone) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            ListTile(
              leading: const Icon(Icons.call_rounded, color: AppColors.info),
              title: const Text('Appeler'),
              onTap: () => Navigator.pop(context, 'call'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              title: const Text('WhatsApp'),
              onTap: () => Navigator.pop(context, 'whatsapp'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copier le numéro'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'call':
        _call(phone);
      case 'whatsapp':
        _whatsapp(phone);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: phone));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text('Numéro copié'),
              ),
            );
        }
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    Client current,
  ) async {
    final nomCtrl = TextEditingController(text: current.nom);
    final telCtrl = TextEditingController(text: current.telephone);
    final adresseCtrl = TextEditingController(text: current.adresse);
    final notesCtrl = TextEditingController(text: current.notes);
    final limiteCtrl = TextEditingController(
      text: current.limiteCredit?.toStringAsFixed(3),
    );
    final formKey = GlobalKey<FormState>();
    final canDelete = current.creditTotal <= 0;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 14),
                  Text(
                    'Modifier le client',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nomCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom du client',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: adresseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Adresse (optionnel)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: limiteCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Limite de crédit (optionnel)',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      suffixText: 'DT',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optionnel)',
                      prefixIcon: Icon(Icons.sticky_note_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        final limite = double.tryParse(
                          limiteCtrl.text.trim().replaceAll(',', '.'),
                        );
                        ref
                            .read(clientsProvider.notifier)
                            .updateClient(
                              current.id,
                              nom: nomCtrl.text.trim(),
                              telephone: telCtrl.text.trim(),
                              adresse: adresseCtrl.text.trim(),
                              notes: notesCtrl.text.trim(),
                              limiteCredit: limite,
                            );
                        Navigator.pop(sheetContext, 'saved');
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: canDelete
                          ? () => Navigator.pop(sheetContext, 'delete')
                          : null,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.danger,
                      ),
                      label: const Text(
                        'Supprimer le client',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                      ),
                    ),
                  ),
                  if (!canDelete) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Ce client a un solde dû — soldez son karné avant de le supprimer.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == 'saved' && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Client mis à jour'),
          ),
        );
    } else if (result == 'delete' && context.mounted) {
      final motifCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Supprimer ce client ?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '« ${current.nom} » sera retiré du karné — cette action est réversible depuis la Corbeille.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: motifCtrl,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Motif (obligatoire)',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                    hintText: 'Ex. Client inactif',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: motifCtrl.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      );
      if (confirmed == true && context.mounted) {
        ref
            .read(clientsProvider.notifier)
            .removeClient(current.id, motif: motifCtrl.text.trim());
        Navigator.pop(context);
      }
    }
  }

  Future<void> _showReceiptSheet(
    BuildContext context,
    String nom,
    double montant,
    double soldeRestant,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Paiement enregistré',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                AppFormat.dt(montant),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Solde restant',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      AppFormat.dt(soldeRestant),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => clientPaymentReceiptService.print(
                        clientNom: nom,
                        montant: montant,
                        soldeRestant: soldeRestant,
                      ),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Imprimer reçu'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEncaisserFlow(
    BuildContext context,
    WidgetRef ref,
    Client current,
    List<Sale> creditSalesOldestFirst,
  ) async {
    final montantCtrl = TextEditingController(
      text: current.creditTotal.toStringAsFixed(3),
    );
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var mode = PaymentMethod.especes;

    final montant = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final entered =
              double.tryParse(montantCtrl.text.replaceAll(',', '.')) ?? 0;
          final previewSolde = (current.creditTotal - entered)
              .clamp(0, double.infinity)
              .toDouble();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SheetHandle(),
                      const SizedBox(height: 14),
                      Text(
                        'Encaisser un paiement',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Solde actuel : ${AppFormat.dt(current.creditTotal)}',
                        style: Theme.of(sheetContext).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: montantCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Montant reçu',
                          prefixIcon: Icon(Icons.payments_rounded),
                          suffixText: 'DT',
                        ),
                        validator: (v) {
                          final value = double.tryParse(
                            (v ?? '').replaceAll(',', '.'),
                          );
                          if (value == null || value <= 0) {
                            return 'Montant invalide';
                          }
                          if (value > current.creditTotal) {
                            return 'Le montant dépasse le solde restant.';
                          }
                          return null;
                        },
                      ),
                      if (entered > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            children: [
                              _confirmRow(
                                'Solde actuel',
                                AppFormat.dt(current.creditTotal),
                              ),
                              const SizedBox(height: 6),
                              _confirmRow(
                                'Vous allez payer',
                                AppFormat.dt(entered),
                              ),
                              const Divider(height: 18),
                              _confirmRow(
                                'Solde restant',
                                AppFormat.dt(previewSolde),
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Mode de paiement',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PaymentMethod.values.map((m) {
                          final selected = m == mode;
                          return ChoiceChip(
                            label: Text(m.label),
                            avatar: Icon(
                              m.icon,
                              size: 16,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            selected: selected,
                            onSelected: (_) => setSheetState(() => mode = m),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Notes',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex. Paiement partiel (optionnel)',
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            Navigator.pop(
                              sheetContext,
                              double.parse(
                                montantCtrl.text.replaceAll(',', '.'),
                              ),
                            );
                          },
                          child: const Text('Continuer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (montant == null || !context.mounted) return;

    final soldeRestant = (current.creditTotal - montant)
        .clamp(0, double.infinity)
        .toDouble();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Encaisser'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Client', current.nom),
            const SizedBox(height: 6),
            _confirmRow('Solde actuel', AppFormat.dt(current.creditTotal)),
            const SizedBox(height: 6),
            _confirmRow('Montant reçu', AppFormat.dt(montant)),
            const SizedBox(height: 6),
            _confirmRow('Mode', mode.label),
            const Divider(height: 18),
            _confirmRow(
              'Solde restant',
              AppFormat.dt(soldeRestant),
              bold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    ref
        .read(clientsProvider.notifier)
        .settle(
          current.id,
          montant,
          creditSalesOldestFirst: creditSalesOldestFirst,
          modePaiement: mode,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
    if (!context.mounted) return;
    await _showReceiptSheet(context, current.nom, montant, soldeRestant);
  }

  Widget _confirmRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: bold ? 16 : 14,
            color: bold ? AppColors.teal : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _groupLabel(DateTime date, DateTime now) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (sameDay(date, now)) return 'Aujourd\'hui';
    if (sameDay(date, now.subtract(const Duration(days: 1)))) return 'Hier';
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    if (!date.isBefore(startOfWeek)) return 'Cette semaine';
    return 'Plus ancien';
  }

  void _openTicketSheet(
    BuildContext context,
    Sale sale,
    double paid,
    double reste,
    List<(DateTime, double)> paiementsLies,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
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
                'Ticket #${sale.id.substring(sale.id.length - 6).toUpperCase()}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _confirmRow(
                'Date',
                DateFormat('dd/MM/yyyy · HH:mm').format(sale.dateHeure),
              ),
              const SizedBox(height: 14),
              Text(
                'Produits',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final l in sale.lignes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l.product.venduAuPoids
                              ? '${AppFormat.kg(l.quantite)} ${l.product.name}'
                              : '${l.quantite.toInt()} × ${l.product.name}',
                          style: Theme.of(sheetContext).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        AppFormat.dtShort(l.sousTotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 22),
              _confirmRow('Total', AppFormat.dt(sale.total), bold: true),
              const SizedBox(height: 14),
              Text(
                'Paiements liés',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (paiementsLies.isEmpty)
                const Text(
                  'Aucun',
                  style: TextStyle(color: AppColors.textFaint),
                )
              else
                for (final (date, montant) in paiementsLies)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy').format(date),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          AppFormat.dt(montant),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              if (reste > 0) ...[
                const Divider(height: 22),
                _confirmRow('Reste', AppFormat.dt(reste), bold: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    final current = clients.where((c) => c.id == client.id);
    final c = current.isEmpty ? client : current.first;

    final achats = ref
        .watch(salesProvider)
        .where((s) => s.clientId == c.id)
        .toList();
    final achatsOldestFirst = List.of(achats)
      ..sort((a, b) => a.dateHeure.compareTo(b.dateHeure));
    final achatsNewestFirst = List.of(achats)
      ..sort((a, b) => b.dateHeure.compareTo(a.dateHeure));

    final allocatedPerSale = <String, double>{};
    final allocationsPerSale = <String, List<(DateTime, double)>>{};
    for (final t in c.transactions) {
      for (final a in t.allocations) {
        allocatedPerSale[a.saleId] =
            (allocatedPerSale[a.saleId] ?? 0) + a.montant;
        (allocationsPerSale[a.saleId] ??= []).add((t.date, a.montant));
      }
    }

    final entries =
        <_TimelineEntry>[
          for (final s in achats)
            _TimelineEntry(
              type: _EntryType.vente,
              montant: s.total,
              date: s.dateHeure,
              reference:
                  'Ticket #${s.id.substring(s.id.length - 6).toUpperCase()}',
            ),
          for (final t in c.transactions)
            _TimelineEntry(
              type: t.type == ClientTransactionType.paiement
                  ? _EntryType.paiement
                  : _EntryType.ajustement,
              montant: t.montant,
              date: t.date,
              reference:
                  'Reçu #${t.id.substring(t.id.length - 6).toUpperCase()}',
              modePaiement: t.modePaiement,
              notes: t.notes,
            ),
        ]..sort(
          (a, b) => b.date.compareTo(a.date),
        ); // newest first — matches display order

    // Replay backward from the one number guaranteed correct (creditTotal),
    // so "solde avant/après" is right even for clients whose balance didn't
    // originate entirely from tracked transactions (e.g. seeded clients).
    var running = c.creditTotal;
    final timelineDesc = <(_TimelineEntry, double, double)>[];
    for (final e in entries) {
      final after = running;
      final before = after - e.signedDelta;
      timelineDesc.add((e, before, after));
      running = before;
    }

    final lastAchat = achats.isEmpty
        ? null
        : achats.map((s) => s.dateHeure).reduce((a, b) => a.isAfter(b) ? a : b);
    final paiementsOnly = c.transactions.where(
      (t) => t.type == ClientTransactionType.paiement,
    );
    final lastPaiement = paiementsOnly.isEmpty
        ? null
        : paiementsOnly
              .map((t) => t.date)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    final overLimit =
        c.limiteCredit != null && c.creditTotal >= c.limiteCredit!;
    final disponible = c.limiteCredit != null
        ? c.limiteCredit! - c.creditTotal
        : null;

    final now = DateTime.now();
    final lastActivity = [?lastAchat, ?lastPaiement].fold<DateTime?>(
      null,
      (max, d) => max == null || d.isAfter(max) ? d : max,
    );
    final isLate =
        c.creditTotal > 0 &&
        (lastActivity == null || now.difference(lastActivity).inDays > 30);

    return Scaffold(
      appBar: AppBar(
        title: Text(c.nom),
        actions: [
          IconButton(
            onPressed: () => _openEditSheet(context, ref, c),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.tealGradient,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.colored(AppColors.teal),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                child: Text(
                                  c.nom.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.telephone,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    if (c.adresse != null &&
                                        c.adresse!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 13,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              c.adresse!,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.85,
                                                ),
                                                fontSize: 12.5,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PressScale(
                                onTap: () => _call(c.telephone),
                                onLongPress: () =>
                                    _openContactMenu(context, c.telephone),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.call_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              PressScale(
                                onTap: () => _whatsapp(c.telephone),
                                onLongPress: () =>
                                    _openContactMenu(context, c.telephone),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (c.creditTotal > 0) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isLate
                                              ? AppColors.danger
                                              : AppColors.tealLight)
                                          .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  isLate ? 'En retard' : 'Client actif',
                                  style: TextStyle(
                                    color: isLate
                                        ? Colors.white
                                        : AppColors.tealLight,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              Text(
                                lastAchat != null
                                    ? 'Dernier achat : ${DateFormat('dd/MM/yyyy').format(lastAchat)}'
                                    : 'Aucun achat',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textFaint,
                                ),
                              ),
                              Text(
                                lastPaiement != null
                                    ? 'Dernier paiement : ${DateFormat('dd/MM/yyyy').format(lastPaiement)}'
                                    : 'Aucun paiement',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Crédit actuel',
                            value: AppFormat.dt(c.creditTotal),
                            icon: Icons.menu_book_rounded,
                            color: c.creditTotal > 0
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: overLimit ? 'Limite dépassée' : 'Disponible',
                            value: disponible != null
                                ? AppFormat.dt(disponible)
                                : '—',
                            icon: overLimit
                                ? Icons.error_outline_rounded
                                : Icons.account_balance_wallet_outlined,
                            color: disponible == null
                                ? AppColors.textSecondary
                                : (disponible <= 0
                                      ? AppColors.danger
                                      : AppColors.success),
                          ),
                        ),
                      ],
                    ),
                    if (c.limiteCredit != null) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final ratio = (c.creditTotal / c.limiteCredit!).clamp(
                            0.0,
                            1.0,
                          );
                          final barColor = overLimit
                              ? AppColors.danger
                              : (ratio >= 0.7
                                    ? AppColors.warning
                                    : AppColors.teal);
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: AppShadows.card,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Limite : ${AppFormat.dt(c.limiteCredit!)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    Text(
                                      '${(ratio * 100).round()}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: barColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 8,
                                    backgroundColor: AppColors.surfaceMuted,
                                    valueColor: AlwaysStoppedAnimation(
                                      barColor,
                                    ),
                                  ),
                                ),
                                if (overLimit) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Limite dépassée',
                                    style: TextStyle(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    if (c.creditTotal > 0) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openEncaisserFlow(
                            context,
                            ref,
                            c,
                            achatsOldestFirst,
                          ),
                          icon: const Icon(Icons.payments_rounded),
                          label: const Text('Encaisser un paiement'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                const TabBar(
                  labelColor: AppColors.teal,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.teal,
                  tabs: [
                    Tab(text: 'Historique'),
                    Tab(text: 'Tickets'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              // Tab 1 — Historique: the running-balance timeline.
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  if (timelineDesc.isEmpty)
                    const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Aucun mouvement',
                      message:
                          'Les ventes à crédit et les paiements\napparaîtront ici.',
                    )
                  else
                    ...() {
                      final widgets = <Widget>[];
                      String? lastGroup;
                      for (final tuple in timelineDesc) {
                        final (entry, before, after) = tuple;
                        final group = _groupLabel(entry.date, now);
                        if (group != lastGroup) {
                          if (lastGroup != null) {
                            widgets.add(const SizedBox(height: 4));
                          }
                          widgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4),
                              child: Text(
                                group,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textFaint,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          );
                          lastGroup = group;
                        }
                        widgets.add(
                          _TimelineTile(
                            entry: entry,
                            before: before,
                            after: after,
                          ),
                        );
                        widgets.add(const SizedBox(height: 10));
                      }
                      return widgets;
                    }(),
                  if (c.notes != null && c.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.card,
                      ),
                      child: Text(
                        c.notes!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ],
              ),
              // Tab 2 — Tickets: every credit sale with its own paid/remaining
              // status, since a running balance can't tell an owner which
              // specific invoices are still open.
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  if (achatsNewestFirst.isEmpty)
                    const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Aucun ticket',
                      message:
                          'Les ventes à crédit de ce client\napparaîtront ici.',
                    )
                  else
                    for (final sale in achatsNewestFirst)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TicketTile(
                          sale: sale,
                          paid: allocatedPerSale[sale.id] ?? 0,
                          onTap: () {
                            final double paid = allocatedPerSale[sale.id] ?? 0;
                            final reste = (sale.total - paid)
                                .clamp(0, sale.total)
                                .toDouble();
                            _openTicketSheet(
                              context,
                              sale,
                              paid,
                              reste,
                              allocationsPerSale[sale.id] ?? const [],
                            );
                          },
                        ),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.background, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

class _TicketTile extends StatelessWidget {
  final Sale sale;
  final double paid;
  final VoidCallback onTap;

  const _TicketTile({
    required this.sale,
    required this.paid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reste = (sale.total - paid).clamp(0, sale.total);
    final isPaid = reste <= 0;
    final isPartial = !isPaid && paid > 0;
    final color = isPaid
        ? AppColors.success
        : (isPartial ? AppColors.warning : AppColors.danger);
    final label = isPaid
        ? 'Payé'
        : (isPartial ? 'Partiellement payé' : 'Non payé');
    final icon = isPaid
        ? Icons.check_circle_rounded
        : (isPartial ? Icons.pending_rounded : Icons.cancel_rounded);

    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ticket #${sale.id.substring(sale.id.length - 6).toUpperCase()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(sale.dateHeure),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      isPartial
                          ? '$label · Reste ${AppFormat.dtShort(reste)}'
                          : label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              AppFormat.dt(sale.total),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final _TimelineEntry entry;
  final double before;
  final double after;

  const _TimelineTile({
    required this.entry,
    required this.before,
    required this.after,
  });

  @override
  Widget build(BuildContext context) {
    final isPaiement = entry.type == _EntryType.paiement;
    final color = isPaiement ? AppColors.success : AppColors.danger;
    final title = switch (entry.type) {
      _EntryType.vente => 'Vente',
      _EntryType.paiement => 'Paiement',
      _EntryType.ajustement => 'Ajustement de crédit',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(
                  isPaiement
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        if (entry.reference != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.reference!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textFaint,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('dd/MM/yyyy · HH:mm').format(entry.date),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Solde : ${AppFormat.dtShort(before)} → ${AppFormat.dtShort(after)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isPaiement ? '-' : '+'}${AppFormat.dtShort(entry.montant)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          if (entry.modePaiement != null ||
              (entry.notes != null && entry.notes!.isNotEmpty)) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (entry.modePaiement != null)
              Row(
                children: [
                  Icon(
                    entry.modePaiement!.icon,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    entry.modePaiement!.label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            if (entry.notes != null && entry.notes!.isNotEmpty) ...[
              if (entry.modePaiement != null) const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      entry.notes!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
