import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/admin/features/activity/service/activity_export_service.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';

/// Full audit trail — chronological by default (Aujourd'hui/Hier/Cette
/// semaine/Plus ancien), filterable by category/employé/date, searchable,
/// and topped with a "Comportement des employés" summary so an admin can
/// spot unusual patterns (a cashier with a lot of deletions) without
/// reading every line.
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the journal is what "catches up" the unread badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityLastSeenProvider.notifier).state = DateTime.now();
    });
  }

  Future<void> _openExportSheet(List<ActivityLogEntry> entries) async {
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
                '${entries.length} entrée${entries.length > 1 ? 's' : ''} — vue actuelle',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                activityExportService.exportPdf(entries);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.table_chart_outlined,
                color: AppColors.success,
              ),
              title: const Text('Exporter en Excel (CSV)'),
              subtitle: Text(
                '${entries.length} entrée${entries.length > 1 ? 's' : ''} — vue actuelle',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                activityExportService.exportCsv(entries);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openDetailSheet(ActivityLogEntry entry) {
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: entry.impact.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      entry.impact.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: entry.impact.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.action,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              if (entry.targetName != null) ...[
                const SizedBox(height: 2),
                Text(
                  entry.targetName!,
                  style: Theme.of(sheetContext).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 18),
              if (entry.isFieldChange) ...[
                _detailRow(sheetContext, 'Avant', entry.ancienneValeur!),
                const SizedBox(height: 10),
                _detailRow(sheetContext, 'Après', entry.nouvelleValeur!),
                if (entry.difference != null) ...[
                  const SizedBox(height: 10),
                  _detailRow(
                    sheetContext,
                    'Différence',
                    '${entry.difference! > 0 ? '+' : ''}${entry.difference!.toStringAsFixed(3)}',
                    color: entry.difference! >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ],
                const Divider(height: 26),
              ],
              if (entry.montant != null) ...[
                _detailRow(
                  sheetContext,
                  'Montant',
                  AppFormat.dt(entry.montant!),
                ),
                const SizedBox(height: 10),
              ],
              _detailRow(sheetContext, 'Employé', entry.employeeName),
              const SizedBox(height: 10),
              _detailRow(
                sheetContext,
                'Date',
                DateFormat('dd/MM/yyyy · HH:mm').format(entry.date),
              ),
              if (entry.platform != null) ...[
                const SizedBox(height: 10),
                _detailRow(sheetContext, 'Appareil', entry.platform!),
              ],
              if (entry.motif != null && entry.motif!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _detailRow(sheetContext, 'Motif', entry.motif!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(activityDateGroupsProvider);
    final filtered = ref.watch(filteredActivityLogProvider);
    final employeeStats = ref.watch(employeeActivityStatsProvider);
    final categoryFilter = ref.watch(activityCategoryFilterProvider);
    final employeeFilter = ref.watch(activityEmployeeFilterProvider);
    final dateFilter = ref.watch(activityDateFilterProvider);
    final sensitiveOnly = ref.watch(activitySensitiveOnlyProvider);
    final employeeNames = ref.watch(activityEmployeeNamesProvider);
    final hasAny = groups.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d\'activité'),
        actions: [
          IconButton(
            onPressed: () => _openExportSheet(filtered),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Exporter',
          ),
          IconButton(
            onPressed: () => context.push('/trash'),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Corbeille',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            onChanged: (v) =>
                ref.read(activitySearchProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Rechercher un produit, un employé, un ticket...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tous'),
                    selected: categoryFilter == null,
                    onSelected: (_) =>
                        ref
                                .read(activityCategoryFilterProvider.notifier)
                                .state =
                            null,
                  ),
                ),
                for (final c in ActivityCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: categoryFilter == c,
                      onSelected: (_) =>
                          ref
                                  .read(activityCategoryFilterProvider.notifier)
                                  .state =
                              c,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DropdownPill<String?>(
                  icon: Icons.person_outline_rounded,
                  value: employeeFilter,
                  hint: 'Employé',
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tous les employés'),
                    ),
                    for (final name in employeeNames)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (v) =>
                      ref.read(activityEmployeeFilterProvider.notifier).state =
                          v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownPill<ActivityDateFilter>(
                  icon: Icons.calendar_today_outlined,
                  value: dateFilter,
                  hint: 'Date',
                  items: [
                    for (final d in ActivityDateFilter.values)
                      DropdownMenuItem(value: d, child: Text(d.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(activityDateFilterProvider.notifier).state = v;
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: sensitiveOnly,
            onChanged: (v) =>
                ref.read(activitySensitiveOnlyProvider.notifier).state = v,
            activeThumbColor: AppColors.teal,
            title: const Text(
              'Actions sensibles uniquement',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Suppressions et modifications',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
          if (employeeStats.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Comportement des employés',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: employeeStats.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _EmployeeStatCard(stats: employeeStats[index]),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (!hasAny)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'Aucune activité',
                message: 'Aucun résultat pour ces filtres.',
              ),
            )
          else
            for (final (label, entries) in groups) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textFaint,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              for (var i = 0; i < entries.length; i++)
                _TimelineRow(
                  entry: entries[i],
                  isLast: i == entries.length - 1,
                  onTap: () => _openDetailSheet(entries[i]),
                ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _DropdownPill<T> extends StatelessWidget {
  final IconData icon;
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownPill({
    required this.icon,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeStatCard extends StatelessWidget {
  final EmployeeActivityStats stats;
  const _EmployeeStatCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: stats.attentionNeeded
            ? AppColors.danger.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: stats.attentionNeeded
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stats.employeeName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (stats.attentionNeeded)
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: AppColors.danger,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _statLine('Suppressions', stats.suppressions, AppColors.danger),
          _statLine('Modifications', stats.modifications, AppColors.info),
          _statLine('Paiements', stats.paiements, AppColors.warning),
        ],
      ),
    );
  }

  Widget _statLine(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textFaint),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final ActivityLogEntry entry;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineRow({
    required this.entry,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry.impact.color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PressScale(
                onTap: onTap,
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
                              entry.impact.label,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.action,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(entry.date),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textFaint,
                            ),
                          ),
                          if (entry.montant != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              AppFormat.dtShort(entry.montant!),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (entry.targetName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          entry.targetName!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (entry.isFieldChange) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              entry.ancienneValeur!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 11,
                                color: AppColors.textFaint,
                              ),
                            ),
                            Text(
                              entry.nouvelleValeur!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        entry.employeeName,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
