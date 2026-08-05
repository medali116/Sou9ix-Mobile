import 'package:flutter/material.dart';

enum ClientTransactionType { paiement, ajustement }

enum PaymentMethod { especes, carte, virement }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.especes:
        return 'Espèces';
      case PaymentMethod.carte:
        return 'Carte';
      case PaymentMethod.virement:
        return 'Virement';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.especes:
        return Icons.payments_rounded;
      case PaymentMethod.carte:
        return Icons.credit_card_rounded;
      case PaymentMethod.virement:
        return Icons.account_balance_rounded;
    }
  }
}

/// How much of a [ClientTransactionType.paiement] was applied against one
/// specific credit [Sale] (ticket), so each ticket's paid/remaining amount
/// can be tracked individually instead of only a running total.
class PaymentAllocation {
  final String saleId;
  final double montant;

  const PaymentAllocation({required this.saleId, required this.montant});

  Map<String, dynamic> toMap() => {'saleId': saleId, 'montant': montant};

  factory PaymentAllocation.fromMap(Map<String, dynamic> map) =>
      PaymentAllocation(
        saleId: map['saleId'] as String,
        montant: (map['montant'] as num).toDouble(),
      );
}

/// A non-sale balance change on a client's karné: either a payment
/// collected ([ClientTransactionType.paiement], subtracts from the
/// balance) or a manual credit adjustment
/// ([ClientTransactionType.ajustement], adds to it). A credit *sale* is
/// deliberately not tracked here — it's already a [Sale] record, which is
/// the source of truth for "Vente" entries in the client's timeline.
class ClientTransaction {
  final String id;
  final ClientTransactionType type;
  final double montant;
  final DateTime date;
  final PaymentMethod? modePaiement;
  final String? notes;

  /// For a [ClientTransactionType.paiement], which ticket(s) it was applied
  /// to (oldest-first / FIFO) — empty when the payment covered a balance
  /// with no tracked tickets behind it (e.g. a legacy/seeded balance).
  final List<PaymentAllocation> allocations;

  const ClientTransaction({
    required this.id,
    required this.type,
    required this.montant,
    required this.date,
    this.modePaiement,
    this.notes,
    this.allocations = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'montant': montant,
    'date': date.toIso8601String(),
    'modePaiement': modePaiement?.name,
    'notes': notes,
    'allocations': allocations.map((a) => a.toMap()).toList(),
  };

  factory ClientTransaction.fromMap(Map<String, dynamic> map) =>
      ClientTransaction(
        id: map['id'] as String,
        type: ClientTransactionType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => ClientTransactionType.ajustement,
        ),
        montant: (map['montant'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        modePaiement: map['modePaiement'] == null
            ? null
            : PaymentMethod.values.firstWhere(
                (m) => m.name == map['modePaiement'],
                orElse: () => PaymentMethod.especes,
              ),
        notes: map['notes'] as String?,
        allocations:
            (map['allocations'] as List<dynamic>?)
                ?.map((a) => PaymentAllocation.fromMap(a as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class Client {
  final String id;
  final String nom;
  final String telephone;
  final double creditTotal;
  final DateTime dernierAchat;
  final String? adresse;
  final String? notes;
  final double? limiteCredit;
  final List<ClientTransaction> transactions;

  const Client({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.creditTotal,
    required this.dernierAchat,
    this.adresse,
    this.notes,
    this.limiteCredit,
    this.transactions = const [],
  });

  Client copyWith({
    String? nom,
    String? telephone,
    double? creditTotal,
    String? adresse,
    String? notes,
    double? limiteCredit,
    List<ClientTransaction>? transactions,
  }) => Client(
    id: id,
    nom: nom ?? this.nom,
    telephone: telephone ?? this.telephone,
    creditTotal: creditTotal ?? this.creditTotal,
    dernierAchat: dernierAchat,
    adresse: adresse ?? this.adresse,
    notes: notes ?? this.notes,
    limiteCredit: limiteCredit ?? this.limiteCredit,
    transactions: transactions ?? this.transactions,
  );

  Map<String, dynamic> toMap() => {
    'nom': nom,
    'telephone': telephone,
    'creditTotal': creditTotal,
    'dernierAchat': dernierAchat.toIso8601String(),
    'adresse': adresse,
    'notes': notes,
    'limiteCredit': limiteCredit,
    'transactions': transactions.map((t) => t.toMap()).toList(),
  };

  factory Client.fromMap(String id, Map<String, dynamic> map) => Client(
    id: id,
    nom: map['nom'] as String,
    telephone: map['telephone'] as String,
    creditTotal: (map['creditTotal'] as num).toDouble(),
    dernierAchat: DateTime.parse(map['dernierAchat'] as String),
    adresse: map['adresse'] as String?,
    notes: map['notes'] as String?,
    limiteCredit: (map['limiteCredit'] as num?)?.toDouble(),
    transactions:
        (map['transactions'] as List<dynamic>?)
            ?.map((t) => ClientTransaction.fromMap(t as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}
