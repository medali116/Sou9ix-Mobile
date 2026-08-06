import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/clients/model/client.dart';
import 'package:sou9ix/shared/features/clients/service/client_export_service.dart';
import 'package:sou9ix/shared/features/clients/service/client_payment_receipt_service.dart';
import 'package:sou9ix/shared/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';

enum _Filter { tous, avecCredit, solde }

extension on _Filter {
  String get label => switch (this) {
    _Filter.tous => 'Tous',
    _Filter.avecCredit => 'Avec crédit',
    _Filter.solde => 'Soldé',
  };
}

enum _Sort { montantDesc, nomAsc, dernierPaiement }

extension on _Sort {
  String get label => switch (this) {
    _Sort.montantDesc => 'Plus grand crédit',
    _Sort.nomAsc => 'Nom',
    _Sort.dernierPaiement => 'Dernier paiement',
  };

  IconData get icon => switch (this) {
    _Sort.montantDesc => Icons.arrow_downward_rounded,
    _Sort.nomAsc => Icons.sort_by_alpha_rounded,
    _Sort.dernierPaiement => Icons.history_rounded,
  };
}

/// Debt-tier color used app-wide on this screen: green (nothing owed) up to
/// red (a significant balance), so risk reads at a glance without needing
/// to parse the exact figure.
Color _riskColor(double amount) {
  if (amount <= 0) return AppColors.success;
  if (amount <= 50) return AppColors.warning;
  if (amount <= 150) return AppColors.goldDark;
  return AppColors.danger;
}

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _query = '';
  _Filter _filter = _Filter.avecCredit;
  _Sort _sort = _Sort.montantDesc;

  DateTime? _lastActivity(List<Sale> sales, String clientId) {
    final clientSales = sales.where((s) => s.clientId == clientId);
    if (clientSales.isEmpty) return null;
    return clientSales
        .map((s) => s.dateHeure)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  DateTime? _lastPayment(Client c) {
    final paiements = c.transactions.where(
      (t) => t.type == ClientTransactionType.paiement,
    );
    if (paiements.isEmpty) return null;
    return paiements.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Future<void> _openSortSheet() async {
    final result = await showModalBottomSheet<_Sort>(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Trier',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final s in _Sort.values)
              ListTile(
                leading: Icon(
                  s.icon,
                  color: _sort == s ? AppColors.teal : AppColors.textSecondary,
                ),
                title: Text(
                  s.label,
                  style: TextStyle(
                    fontWeight: _sort == s ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                trailing: _sort == s
                    ? const Icon(Icons.check_rounded, color: AppColors.teal)
                    : null,
                onTap: () => Navigator.pop(context, s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _sort = result);
  }

  Future<void> _openAddClientSheet() async {
    final nomCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
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
            child: Form(
              key: formKey,
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        ref
                            .read(clientsProvider.notifier)
                            .addClient(
                              nom: nomCtrl.text.trim(),
                              telephone: telCtrl.text.trim(),
                            );
                        Navigator.pop(sheetContext, true);
                      },
                      child: const Text('Ajouter le client'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Client ajouté'),
          ),
        );
    }
  }

  Future<void> _showReceiptSheet(
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

  Future<void> _openEncaisserSheet(Client c) async {
    final montantCtrl = TextEditingController(
      text: c.creditTotal.toStringAsFixed(3),
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
          final previewSolde = (c.creditTotal - entered)
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
                        'Encaisser — ${c.nom}',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Solde actuel : ${AppFormat.dt(c.creditTotal)}',
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
                          if (value > c.creditTotal) {
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
                                AppFormat.dt(c.creditTotal),
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
    if (montant == null || !mounted) return;

    final soldeRestant = (c.creditTotal - montant)
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
            _confirmRow('Client', c.nom),
            const SizedBox(height: 6),
            _confirmRow('Solde actuel', AppFormat.dt(c.creditTotal)),
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
    if (confirmed != true || !mounted) return;

    final creditSalesOldestFirst =
        ref.read(salesProvider).where((s) => s.clientId == c.id).toList()
          ..sort((a, b) => a.dateHeure.compareTo(b.dateHeure));

    ref
        .read(clientsProvider.notifier)
        .settle(
          c.id,
          montant,
          creditSalesOldestFirst: creditSalesOldestFirst,
          modePaiement: mode,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
    if (!mounted) return;
    await _showReceiptSheet(c.nom, montant, soldeRestant);
  }

  Future<void> _openAddCreditSheet(Client c) async {
    final montantCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
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
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 14),
                  Text(
                    'Ajouter du crédit — ${c.nom}',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: montantCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Montant à ajouter',
                      prefixIcon: Icon(Icons.payments_rounded),
                      suffixText: 'DT',
                    ),
                    validator: (v) {
                      final value = double.tryParse(
                        (v ?? '').replaceAll(',', '.'),
                      );
                      return (value == null || value <= 0)
                          ? 'Montant invalide'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
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
                        ref
                            .read(clientsProvider.notifier)
                            .addManualCredit(
                              c.id,
                              double.parse(
                                montantCtrl.text.replaceAll(',', '.'),
                              ),
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            );
                        Navigator.pop(sheetContext, true);
                      },
                      child: const Text('Ajouter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Crédit ajouté'),
          ),
        );
    }
  }

  Future<void> _confirmDelete(Client c) async {
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
                '« ${c.nom} » sera retiré du karné — cette action est réversible depuis la Corbeille.',
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
    if (confirmed == true) {
      ref
          .read(clientsProvider.notifier)
          .removeClient(c.id, motif: motifCtrl.text.trim());
    }
  }

  Future<void> _openActionsMenu(Client c) async {
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
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Voir détails'),
              onTap: () => Navigator.pop(context, 'details'),
            ),
            if (c.creditTotal > 0)
              ListTile(
                leading: const Icon(
                  Icons.payments_outlined,
                  color: AppColors.success,
                ),
                title: const Text('Encaisser'),
                onTap: () => Navigator.pop(context, 'encaisser'),
              ),
            ListTile(
              leading: const Icon(Icons.add_card_outlined),
              title: const Text('Ajouter crédit'),
              onTap: () => Navigator.pop(context, 'credit'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Supprimer',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'details':
        context.push('/clients/detail', extra: c);
      case 'encaisser':
        _openEncaisserSheet(c);
      case 'credit':
        _openAddCreditSheet(c);
      case 'edit':
        context.push('/clients/detail', extra: c);
      case 'delete':
        _confirmDelete(c);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    await launchUrl(uri);
  }

  Future<void> _whatsapp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openExportSheet(List<Client> clients) async {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Exporter',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.danger,
              ),
              title: const Text('Exporter en PDF'),
              subtitle: Text(
                '${clients.length} client${clients.length > 1 ? 's' : ''} — vue actuelle',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                clientExportService.exportPdf(clients);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.table_chart_outlined,
                color: AppColors.success,
              ),
              title: const Text('Exporter en Excel (CSV)'),
              subtitle: Text(
                '${clients.length} client${clients.length > 1 ? 's' : ''} — vue actuelle',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                clientExportService.exportCsv(clients);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allClients = ref.watch(clientsProvider);
    final totalCredit = ref.watch(totalCreditProvider);
    final sales = ref.watch(salesProvider);
    final withCredit = allClients.where((c) => c.creditTotal > 0).toList();

    var clients = List.of(allClients);
    switch (_filter) {
      case _Filter.tous:
        break;
      case _Filter.avecCredit:
        clients = clients.where((c) => c.creditTotal > 0).toList();
      case _Filter.solde:
        clients = clients.where((c) => c.creditTotal <= 0).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      clients = clients
          .where(
            (c) =>
                c.nom.toLowerCase().contains(q) ||
                c.telephone.replaceAll(' ', '').contains(q.replaceAll(' ', '')),
          )
          .toList();
    }
    switch (_sort) {
      case _Sort.montantDesc:
        clients.sort((a, b) => b.creditTotal.compareTo(a.creditTotal));
      case _Sort.nomAsc:
        clients.sort((a, b) => a.nom.compareTo(b.nom));
      case _Sort.dernierPaiement:
        clients.sort((a, b) {
          final da = _lastPayment(a) ?? DateTime(2000);
          final db = _lastPayment(b) ?? DateTime(2000);
          return db.compareTo(da);
        });
    }

    final average = withCredit.isEmpty
        ? 0.0
        : withCredit.fold<double>(0, (sum, c) => sum + c.creditTotal) /
              withCredit.length;
    Client? topDebtor;
    for (final c in withCredit) {
      if (topDebtor == null || c.creditTotal > topDebtor.creditTotal) {
        topDebtor = c;
      }
    }

    // How long the longest-standing active balance has been outstanding —
    // approximated from each indebted client's earliest credit sale, since
    // balances aren't tracked per-invoice.
    int? oldestCreditDays;
    for (final c in withCredit) {
      DateTime? firstSale;
      for (final s in sales.where((s) => s.clientId == c.id)) {
        if (firstSale == null || s.dateHeure.isBefore(firstSale)) {
          firstSale = s.dateHeure;
        }
      }
      if (firstSale != null) {
        final days = DateTime.now().difference(firstSale).inDays;
        if (oldestCreditDays == null || days > oldestCreditDays) {
          oldestCreditDays = days;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients & crédit'),
        actions: [
          IconButton(
            onPressed: () => _openExportSheet(clients),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Exporter',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.inkGradient,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL CRÉDIT CLIENT (KARNÉ)',
                              style: TextStyle(
                                color: AppColors.tealLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppFormat.dt(totalCredit),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${withCredit.length} client${withCredit.length > 1 ? 's' : ''} avec solde dû',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.functions_rounded,
                        label: 'Moyenne',
                        value: AppFormat.dtShort(average),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.priority_high_rounded,
                        label: topDebtor?.nom ?? 'Plus gros débiteur',
                        value: topDebtor != null
                            ? AppFormat.dtShort(topDebtor.creditTotal)
                            : '—',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.hourglass_bottom_rounded,
                        label: 'Plus ancien crédit',
                        value: oldestCreditDays != null
                            ? '$oldestCreditDays j'
                            : '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un client...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            for (final f in _Filter.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(f.label),
                                  selected: _filter == f,
                                  onSelected: (_) =>
                                      setState(() => _filter = f),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PressScale(
                      onTap: _openSortSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (clients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Aucun client',
                      message: 'Aucun résultat pour ces filtres.',
                    ),
                  )
                else
                  ...clients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final c = entry.value;
                    final lastActivity = _lastActivity(sales, c.id);
                    final lastPaiement = _lastPayment(c);
                    final overLimit =
                        c.limiteCredit != null &&
                        c.creditTotal >= c.limiteCredit!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Slidable(
                        key: ValueKey(c.id),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: c.creditTotal > 0 ? 0.72 : 0.48,
                          children: [
                            if (c.creditTotal > 0)
                              SlidableAction(
                                onPressed: (_) => _openEncaisserSheet(c),
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                icon: Icons.payments_rounded,
                                label: 'Encaisser',
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            SlidableAction(
                              onPressed: (_) => _call(c.telephone),
                              backgroundColor: AppColors.info,
                              foregroundColor: Colors.white,
                              icon: Icons.call_rounded,
                              label: 'Appeler',
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            SlidableAction(
                              onPressed: (_) => _whatsapp(c.telephone),
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              icon: Icons.chat_rounded,
                              label: 'WhatsApp',
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ],
                        ),
                        child: PressScale(
                          onTap: () =>
                              context.push('/clients/detail', extra: c),
                          child: Container(
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
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.teal
                                          .withValues(alpha: 0.12),
                                      foregroundColor: AppColors.tealDark,
                                      child: Text(
                                        c.nom.substring(0, 1),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.nom,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.telephone,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _riskColor(
                                              c.creditTotal,
                                            ).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: _riskColor(
                                                    c.creditTotal,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                c.creditTotal > 0
                                                    ? 'Crédit'
                                                    : 'À jour',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _riskColor(
                                                    c.creditTotal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppFormat.dt(c.creditTotal),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: _riskColor(c.creditTotal),
                                          ),
                                        ),
                                      ],
                                    ),
                                    PressScale(
                                      onTap: () => _openActionsMenu(c),
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.more_vert_rounded,
                                          color: AppColors.textFaint,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      lastActivity != null
                                          ? Icons.shopping_bag_outlined
                                          : Icons.remove_shopping_cart_outlined,
                                      size: 13,
                                      color: AppColors.textFaint,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      lastActivity != null
                                          ? 'Dernier achat ${DateFormat('dd/MM/yyyy').format(lastActivity)}'
                                          : 'Aucun achat à crédit',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textFaint,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.payments_outlined,
                                      size: 13,
                                      color: AppColors.textFaint,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      lastPaiement != null
                                          ? 'Dernier paiement ${DateFormat('dd/MM/yyyy').format(lastPaiement)}'
                                          : 'Aucun paiement',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textFaint,
                                      ),
                                    ),
                                  ],
                                ),
                                if (overLimit) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 12,
                                          color: AppColors.danger,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Limite atteinte (${AppFormat.dtShort(c.limiteCredit!)})',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.danger,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(
                      duration: 220.ms,
                      delay: (18 * index).ms,
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddClientSheet,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, color: AppColors.teal, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
