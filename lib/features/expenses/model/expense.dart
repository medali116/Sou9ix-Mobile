import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sou9ix/features/clients/model/client.dart' show PaymentMethod;

enum ExpenseCategory {
  loyer,
  steg,
  sonede,
  internet,
  salaires,
  nettoyage,
  fournitures,
  transport,
  maintenance,
  autre,
}

extension ExpenseCategoryLabel on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.loyer:
        return 'Loyer';
      case ExpenseCategory.steg:
        return 'STEG';
      case ExpenseCategory.sonede:
        return 'SONEDE';
      case ExpenseCategory.internet:
        return 'Internet';
      case ExpenseCategory.salaires:
        return 'Salaires';
      case ExpenseCategory.nettoyage:
        return 'Nettoyage';
      case ExpenseCategory.fournitures:
        return 'Fournitures';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.maintenance:
        return 'Maintenance';
      case ExpenseCategory.autre:
        return 'Autre';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.loyer:
        return Icons.home_work_outlined;
      case ExpenseCategory.steg:
        return Icons.bolt_rounded;
      case ExpenseCategory.sonede:
        return Icons.water_drop_outlined;
      case ExpenseCategory.internet:
        return Icons.wifi_rounded;
      case ExpenseCategory.salaires:
        return Icons.people_outline_rounded;
      case ExpenseCategory.nettoyage:
        return Icons.cleaning_services_outlined;
      case ExpenseCategory.fournitures:
        return Icons.shopping_bag_outlined;
      case ExpenseCategory.transport:
        return Icons.local_shipping_outlined;
      case ExpenseCategory.maintenance:
        return Icons.build_outlined;
      case ExpenseCategory.autre:
        return Icons.inventory_2_outlined;
    }
  }
}

class Expense {
  final String id;
  final String label;
  final double montant;
  final ExpenseCategory categorie;
  final DateTime date;
  final String? description;
  final Uint8List? photoBytes;
  final bool paye;
  final bool recurrente;
  final String? ajouteePar;

  /// How the expense left the business — defaults to espèces since that's
  /// the overwhelming majority case for day-to-day shop expenses, and it's
  /// what lets a cash-register session's reconciliation know which
  /// expenses actually came out of the till.
  final PaymentMethod modePaiement;

  const Expense({
    required this.id,
    required this.label,
    required this.montant,
    required this.categorie,
    required this.date,
    this.description,
    this.photoBytes,
    this.paye = true,
    this.recurrente = false,
    this.ajouteePar,
    this.modePaiement = PaymentMethod.especes,
  });

  Expense copyWith({
    String? id,
    String? label,
    double? montant,
    ExpenseCategory? categorie,
    DateTime? date,
    String? description,
    Uint8List? photoBytes,
    bool? paye,
    bool? recurrente,
    String? ajouteePar,
    PaymentMethod? modePaiement,
  }) => Expense(
    id: id ?? this.id,
    label: label ?? this.label,
    montant: montant ?? this.montant,
    categorie: categorie ?? this.categorie,
    date: date ?? this.date,
    description: description ?? this.description,
    photoBytes: photoBytes ?? this.photoBytes,
    paye: paye ?? this.paye,
    recurrente: recurrente ?? this.recurrente,
    ajouteePar: ajouteePar ?? this.ajouteePar,
    modePaiement: modePaiement ?? this.modePaiement,
  );

  Map<String, dynamic> toMap() => {
    'libelle': label,
    'montant': montant,
    'categorie': categorie.name,
    'date': date.toIso8601String(),
    'description': description,
    'photo': photoBytes == null ? null : base64Encode(photoBytes!),
    'paye': paye,
    'recurrente': recurrente,
    'ajouteePar': ajouteePar,
    'modePaiement': modePaiement.name,
  };

  factory Expense.fromMap(String id, Map<String, dynamic> map) => Expense(
    id: id,
    label: (map['libelle'] ?? map['label']) as String,
    montant: (map['montant'] as num).toDouble(),
    categorie: ExpenseCategory.values.firstWhere(
      (c) => c.name == map['categorie'],
      orElse: () => ExpenseCategory.autre,
    ),
    date: DateTime.parse(map['date'] as String),
    description: map['description'] as String?,
    photoBytes: (map['photo'] ?? map['photoBytes']) == null
        ? null
        : base64Decode((map['photo'] ?? map['photoBytes']) as String),
    paye: map['paye'] as bool? ?? true,
    recurrente: map['recurrente'] as bool? ?? false,
    ajouteePar: map['ajouteePar'] as String?,
    modePaiement: PaymentMethod.values.firstWhere(
      (m) => m.name == map['modePaiement'],
      orElse: () => PaymentMethod.especes,
    ),
  );
}
