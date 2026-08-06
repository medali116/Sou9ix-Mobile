import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/trash_provider.dart';
import 'package:sou9ix/shared/features/clients/model/client.dart';
import 'package:sou9ix/shared/features/clients/service/clients_repository.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';

List<Client> _buildMockClients() => [
  Client(
    id: 'c1',
    nom: 'Mohamed Trabelsi',
    telephone: '+216 20 123 456',
    creditTotal: 45.500,
    dernierAchat: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Client(
    id: 'c2',
    nom: 'Amira Ben Salah',
    telephone: '+216 22 987 654',
    creditTotal: 0,
    dernierAchat: DateTime.now().subtract(const Duration(days: 3)),
  ),
  Client(
    id: 'c3',
    nom: 'Sami Gharbi',
    telephone: '+216 55 741 258',
    creditTotal: 128.000,
    dernierAchat: DateTime.now().subtract(const Duration(hours: 6)),
  ),
  Client(
    id: 'c4',
    nom: 'Café Central',
    telephone: '+216 71 456 789',
    creditTotal: 260.750,
    dernierAchat: DateTime.now().subtract(const Duration(days: 2)),
    limiteCredit: 300,
  ),
];

final clientsRepositoryProvider = Provider<ClientsRepository?>((ref) {
  final shopCode = ref.watch(shopCodeProvider);
  if (shopCode == null) return null;
  return ClientsRepository(FirebaseFirestore.instance, shopCode);
});

class ClientsNotifier extends StateNotifier<List<Client>> {
  ClientsNotifier(this._ref, this._repo) : super(_buildMockClients()) {
    unawaited(_init());
  }

  final Ref _ref;
  final ClientsRepository? _repo;
  StreamSubscription<List<Client>>? _sub;

  Future<void> _init() async {
    final repo = _repo;
    if (repo == null) return;
    await repo.bootstrapIfEmpty(state);
    _sub = repo.watchAll().listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Brings a client back from the Corbeille.
  void restore(Client client) {
    state = [...state, client];
    unawaited(_repo?.upsert(client));
  }

  /// Registers a new client on the fly (e.g. from the checkout screen when
  /// a credit customer isn't in the karné yet) and returns it so the caller
  /// can immediately select it.
  Client addClient({required String nom, required String telephone}) {
    final client = Client(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nom: nom,
      telephone: telephone,
      creditTotal: 0,
      dernierAchat: DateTime.now(),
    );
    state = [...state, client];
    logActivity(
      _ref,
      category: ActivityCategory.clients,
      impact: ActivityImpact.ajout,
      action: 'Nouveau client',
      targetName: client.nom,
    );
    unawaited(_repo?.upsert(client));
    return client;
  }

  /// Adds (or, with a negative [montant], reverses) credit on a client's
  /// karné as a *side effect of a sale* (see [SaleService]) — clamped at 0
  /// like [settle]. Deliberately not logged as a [ClientTransaction]: the
  /// [Sale] record itself is the timeline entry for this change.
  Future<void> addCredit(String clientId, double montant) async {
    final updated = addCreditLocal(clientId, montant);
    if (updated != null) await _repo?.upsert(updated);
  }

  /// Same optimistic local mutation as [addCredit], without the persist
  /// call — used by [SaleService.checkout], which persists the credit
  /// delta as part of one combined [SalesRepository.recordSaleBatch]
  /// write instead of one write per client. Returns the updated client
  /// (or null if [clientId] wasn't found) purely for callers that don't
  /// already track it.
  Client? addCreditLocal(String clientId, double montant) {
    Client? updated;
    state = [
      for (final c in state)
        if (c.id == clientId)
          (updated = c.copyWith(
            creditTotal: (c.creditTotal + montant).clamp(0, double.infinity),
          ))
        else
          c,
    ];
    return updated;
  }

  /// Manual credit adjustment from the "Ajouter crédit" action — unlike
  /// [addCredit], this has no [Sale] behind it, so it's logged as an
  /// [ClientTransactionType.ajustement] to keep the client's timeline
  /// complete.
  Future<void> addManualCredit(
    String clientId,
    double montant, {
    String? notes,
  }) async {
    Client? updated;
    state = [
      for (final c in state)
        if (c.id == clientId)
          (updated = c.copyWith(
            creditTotal: (c.creditTotal + montant).clamp(0, double.infinity),
            transactions: [
              ...c.transactions,
              ClientTransaction(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                type: ClientTransactionType.ajustement,
                montant: montant,
                date: DateTime.now(),
                notes: notes,
              ),
            ],
          ))
        else
          c,
    ];
    if (updated != null) await _repo?.upsert(updated);
  }

  /// Records a payment collected against a client's karné — clamps the
  /// balance at 0 and logs a [ClientTransaction] so it shows up in their
  /// timeline (unlike [addCredit], which isn't itself a payment).
  ///
  /// [creditSalesOldestFirst] — that client's credit [Sale]s, oldest first —
  /// is used to allocate the payment FIFO: the oldest unpaid/partially-paid
  /// ticket is settled first, then the next, until the payment is used up.
  /// Any leftover past the last tracked ticket (e.g. a legacy balance with
  /// no ticket behind it) is simply not tied to a specific ticket.
  Future<void> settle(
    String clientId,
    double montant, {
    List<Sale> creditSalesOldestFirst = const [],
    PaymentMethod? modePaiement,
    String? notes,
  }) async {
    Client? updated;
    state = [
      for (final c in state)
        if (c.id == clientId)
          (updated = c.copyWith(
            creditTotal: (c.creditTotal - montant).clamp(0, double.infinity),
            transactions: [
              ...c.transactions,
              ClientTransaction(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                type: ClientTransactionType.paiement,
                montant: montant,
                date: DateTime.now(),
                modePaiement: modePaiement,
                notes: notes,
                allocations: _allocateFifo(c, montant, creditSalesOldestFirst),
              ),
            ],
          ))
        else
          c,
    ];
    final client = state.where((c) => c.id == clientId);
    logActivity(
      _ref,
      category: ActivityCategory.clients,
      impact: ActivityImpact.paiement,
      action: 'Paiement client',
      targetName: client.isEmpty ? null : client.first.nom,
      montant: montant,
      motif: notes,
    );
    if (updated != null) await _repo?.upsert(updated);
  }

  List<PaymentAllocation> _allocateFifo(
    Client c,
    double montant,
    List<Sale> creditSalesOldestFirst,
  ) {
    final alreadyPaid = <String, double>{};
    for (final t in c.transactions) {
      for (final a in t.allocations) {
        alreadyPaid[a.saleId] = (alreadyPaid[a.saleId] ?? 0) + a.montant;
      }
    }

    var remaining = montant;
    final allocations = <PaymentAllocation>[];
    for (final sale in creditSalesOldestFirst) {
      if (remaining <= 0) break;
      final saleRemaining = sale.total - (alreadyPaid[sale.id] ?? 0);
      if (saleRemaining <= 0) continue;
      final toApply = remaining < saleRemaining ? remaining : saleRemaining;
      allocations.add(PaymentAllocation(saleId: sale.id, montant: toApply));
      remaining -= toApply;
    }
    return allocations;
  }

  Future<void> updateClient(
    String id, {
    required String nom,
    required String telephone,
    String? adresse,
    String? notes,
    double? limiteCredit,
  }) async {
    final matches = state.where((c) => c.id == id);
    final old = matches.isEmpty ? null : matches.first;
    Client? updated;
    state = [
      for (final c in state)
        if (c.id == id)
          (updated = c.copyWith(
            nom: nom,
            telephone: telephone,
            adresse: adresse,
            notes: notes,
            limiteCredit: limiteCredit,
          ))
        else
          c,
    ];
    if (old != null) {
      if (old.nom != nom) {
        logActivity(
          _ref,
          category: ActivityCategory.clients,
          impact: ActivityImpact.modification,
          action: 'Client modifié',
          targetName: nom,
          champ: 'Nom',
          ancienneValeur: old.nom,
          nouvelleValeur: nom,
        );
      }
      if (old.telephone != telephone) {
        logActivity(
          _ref,
          category: ActivityCategory.clients,
          impact: ActivityImpact.modification,
          action: 'Client modifié',
          targetName: nom,
          champ: 'Téléphone',
          ancienneValeur: old.telephone,
          nouvelleValeur: telephone,
        );
      }
      if (old.adresse != adresse) {
        logActivity(
          _ref,
          category: ActivityCategory.clients,
          impact: ActivityImpact.modification,
          action: 'Client modifié',
          targetName: nom,
          champ: 'Adresse',
          ancienneValeur: old.adresse ?? '—',
          nouvelleValeur: adresse ?? '—',
        );
      }
    }
    if (updated != null) await _repo?.upsert(updated);
  }

  Future<void> removeClient(String id, {required String motif}) async {
    final matches = state.where((c) => c.id == id);
    final client = matches.isEmpty ? null : matches.first;
    state = state.where((c) => c.id != id).toList();
    if (client != null) {
      _ref.read(clientsTrashProvider.notifier).add(client);
      logActivity(
        _ref,
        category: ActivityCategory.clients,
        impact: ActivityImpact.suppression,
        action: 'Client supprimé',
        targetName: client.nom,
        motif: motif,
      );
    }
    await _repo?.remove(id);
  }
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>(
  (ref) => ClientsNotifier(ref, ref.watch(clientsRepositoryProvider)),
);

final totalCreditProvider = Provider<double>((ref) {
  final clients = ref.watch(clientsProvider);
  return clients.fold(0, (total, c) => total + c.creditTotal);
});
