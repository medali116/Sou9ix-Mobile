import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/shared/features/activity/service/activity_log_repository.dart';
import 'package:sou9ix/shared/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';

final activityLogRepositoryProvider = Provider<ActivityLogRepository?>((ref) {
  final shopCode = ref.watch(shopCodeProvider);
  if (shopCode == null) return null;
  return ActivityLogRepository(FirebaseFirestore.instance, shopCode);
});

class ActivityLogNotifier extends StateNotifier<List<ActivityLogEntry>> {
  ActivityLogNotifier(this._repo) : super(const []) {
    final repo = _repo;
    if (repo != null) {
      _sub = repo.watchAll().listen((list) => state = list);
    }
  }

  final ActivityLogRepository? _repo;
  StreamSubscription<List<ActivityLogEntry>>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void log(ActivityLogEntry entry) {
    state = [entry, ...state];
    unawaited(_repo?.log(entry));
  }
}

final activityLogProvider =
    StateNotifierProvider<ActivityLogNotifier, List<ActivityLogEntry>>(
      (ref) => ActivityLogNotifier(ref.watch(activityLogRepositoryProvider)),
    );

/// Best-effort "which device is this" — real, not fabricated: Flutter
/// exposes this without needing platform channels or permissions.
String currentPlatformLabel() {
  if (kIsWeb) return 'Web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
}

/// Single entry point every provider logs through — keeps id generation,
/// the acting employee's name, and the device label consistent no matter
/// which screen triggered the action.
void logActivity(
  Ref ref, {
  required ActivityCategory category,
  required ActivityImpact impact,
  required String action,
  String? targetName,
  String? champ,
  String? ancienneValeur,
  String? nouvelleValeur,
  double? difference,
  String? motif,
  double? montant,
}) {
  ref
      .read(activityLogProvider.notifier)
      .log(
        ActivityLogEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}${category.index}',
          date: DateTime.now(),
          employeeName: ref.read(authProvider)?.nom ?? 'Inconnu',
          category: category,
          impact: impact,
          action: action,
          targetName: targetName,
          champ: champ,
          ancienneValeur: ancienneValeur,
          nouvelleValeur: nouvelleValeur,
          difference: difference,
          motif: motif,
          montant: montant,
          platform: currentPlatformLabel(),
        ),
      );
}

/// When the admin last opened the Journal d'activité — defaults to a week
/// ago so a fresh install already demonstrates the "away for a week, catch
/// up on what happened" scenario instead of showing 0 unread.
final activityLastSeenProvider = StateProvider<DateTime>(
  (ref) => DateTime.now().subtract(const Duration(days: 7)),
);

final unseenActivityCountProvider = Provider<int>((ref) {
  final lastSeen = ref.watch(activityLastSeenProvider);
  return ref
      .watch(activityLogProvider)
      .where((e) => e.date.isAfter(lastSeen))
      .length;
});

// ---- Journal filters ----

enum ActivityDateFilter { toutes, aujourdhui, semaine, mois }

extension ActivityDateFilterLabel on ActivityDateFilter {
  String get label => switch (this) {
    ActivityDateFilter.toutes => 'Toutes dates',
    ActivityDateFilter.aujourdhui => 'Aujourd\'hui',
    ActivityDateFilter.semaine => 'Cette semaine',
    ActivityDateFilter.mois => 'Ce mois',
  };
}

final activitySearchProvider = StateProvider<String>((ref) => '');
final activityCategoryFilterProvider = StateProvider<ActivityCategory?>(
  (ref) => null,
);
final activityEmployeeFilterProvider = StateProvider<String?>((ref) => null);
final activityDateFilterProvider = StateProvider<ActivityDateFilter>(
  (ref) => ActivityDateFilter.toutes,
);
final activitySensitiveOnlyProvider = StateProvider<bool>((ref) => false);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final activityEmployeeNamesProvider = Provider<List<String>>((ref) {
  final names = ref
      .watch(activityLogProvider)
      .map((e) => e.employeeName)
      .toSet()
      .toList();
  names.sort();
  return names;
});

/// The log after search + every active filter, newest first.
final filteredActivityLogProvider = Provider<List<ActivityLogEntry>>((ref) {
  final query = ref.watch(activitySearchProvider).trim().toLowerCase();
  final category = ref.watch(activityCategoryFilterProvider);
  final employee = ref.watch(activityEmployeeFilterProvider);
  final dateFilter = ref.watch(activityDateFilterProvider);
  final sensitiveOnly = ref.watch(activitySensitiveOnlyProvider);
  final now = DateTime.now();
  final startOfWeek = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));

  return ref.watch(activityLogProvider).where((e) {
    if (category != null && e.category != category) return false;
    if (employee != null && e.employeeName != employee) return false;
    if (sensitiveOnly && !e.impact.isSensitive) return false;
    switch (dateFilter) {
      case ActivityDateFilter.toutes:
        break;
      case ActivityDateFilter.aujourdhui:
        if (!_isSameDay(e.date, now)) return false;
      case ActivityDateFilter.semaine:
        if (e.date.isBefore(startOfWeek)) return false;
      case ActivityDateFilter.mois:
        if (e.date.year != now.year || e.date.month != now.month) return false;
    }
    if (query.isNotEmpty) {
      final haystack = '${e.targetName ?? ''} ${e.employeeName} ${e.action}'
          .toLowerCase();
      if (!haystack.contains(query)) return false;
    }
    return true;
  }).toList();
});

/// [filteredActivityLogProvider] bucketed into Aujourd'hui / Hier / Cette
/// semaine / Plus ancien, in that order — the journal's default,
/// chronological grouping (vs. the old fixed-by-category layout).
final activityDateGroupsProvider =
    Provider<List<(String, List<ActivityLogEntry>)>>((ref) {
      final entries = ref.watch(filteredActivityLogProvider);
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));

      String groupOf(ActivityLogEntry e) {
        if (_isSameDay(e.date, now)) return 'Aujourd\'hui';
        if (_isSameDay(e.date, yesterday)) return 'Hier';
        if (!e.date.isBefore(startOfWeek)) return 'Cette semaine';
        return 'Plus ancien';
      }

      const order = ['Aujourd\'hui', 'Hier', 'Cette semaine', 'Plus ancien'];
      final buckets = <String, List<ActivityLogEntry>>{};
      for (final e in entries) {
        (buckets[groupOf(e)] ??= []).add(e);
      }
      return [
        for (final label in order)
          if (buckets[label] != null) (label, buckets[label]!),
      ];
    });

class EmployeeActivityStats {
  final String employeeName;
  final int suppressions;
  final int modifications;
  final int paiements;
  final int ajouts;

  const EmployeeActivityStats({
    required this.employeeName,
    required this.suppressions,
    required this.modifications,
    required this.paiements,
    required this.ajouts,
  });

  int get total => suppressions + modifications + paiements + ajouts;

  /// Flags an employee whose recent activity leans heavily on deletions —
  /// a simple, transparent signal (not a black-box "score") an admin can
  /// use to decide whether to look closer.
  bool get attentionNeeded => suppressions >= 3 && suppressions * 2 >= total;
}

/// Per-employee breakdown of everything they're logged as having done —
/// feeds the journal's "Comportement des employés" summary.
final employeeActivityStatsProvider = Provider<List<EmployeeActivityStats>>((
  ref,
) {
  final byEmployee = <String, List<ActivityLogEntry>>{};
  for (final e in ref.watch(activityLogProvider)) {
    (byEmployee[e.employeeName] ??= []).add(e);
  }
  return byEmployee.entries
      .map(
        (entry) => EmployeeActivityStats(
          employeeName: entry.key,
          suppressions: entry.value
              .where((e) => e.impact == ActivityImpact.suppression)
              .length,
          modifications: entry.value
              .where((e) => e.impact == ActivityImpact.modification)
              .length,
          paiements: entry.value
              .where((e) => e.impact == ActivityImpact.paiement)
              .length,
          ajouts: entry.value
              .where((e) => e.impact == ActivityImpact.ajout)
              .length,
        ),
      )
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));
});
