import 'package:flutter/material.dart';

import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

const _monthNames = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

const _monthNamesShort = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _shortLabel(DateTime d) => '${d.day} ${_monthNamesShort[d.month - 1]}';

/// Opens a compact, French, app-themed bottom sheet for picking a date
/// range — used instead of Flutter's stock full-screen [showDateRangePicker]
/// dialog so the calendar matches the rest of Sou9ix's bottom-sheet chrome
/// (teal accent, rounded card, French month/weekday names) instead of the
/// default Material English full-screen picker.
Future<DateTimeRange?> showAppDateRangeSheet(
  BuildContext context, {
  DateTimeRange? initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DateRangeSheet(
      initialRange: initialRange,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _DateRangeSheet extends StatefulWidget {
  final DateTimeRange? initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DateRangeSheet({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  late DateTime _displayedMonth;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    final range = widget.initialRange;
    _start = range != null ? _dateOnly(range.start) : null;
    _end = range != null ? _dateOnly(range.end) : null;
    final anchor = _end ?? _start ?? DateTime.now();
    _displayedMonth = DateTime(anchor.year, anchor.month);
  }

  bool get _canGoPrevMonth {
    final prev = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    return !prev.isBefore(
      DateTime(widget.firstDate.year, widget.firstDate.month),
    );
  }

  bool get _canGoNextMonth {
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    return !next.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month));
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
      );
    });
  }

  void _onDayTap(DateTime day) {
    setState(() {
      if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _end = _start;
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  List<DateTime?> _buildMonthCells() {
    final firstOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final leading = firstOfMonth.weekday - 1; // Monday-first week
    return [
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_displayedMonth.year, _displayedMonth.month, d),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final start = _start;
    final end = _end;
    final rangeLabel = start == null
        ? 'Aucune date sélectionnée'
        : end == null
        ? _shortLabel(start)
        : '${_shortLabel(start)} → ${_shortLabel(end)}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sélectionner une période',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rangeLabel,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: _canGoPrevMonth ? () => _changeMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _canGoNextMonth ? () => _changeMonth(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: List.generate(7, (i) {
                final isWeekend = i >= 5;
                return Expanded(
                  child: Center(
                    child: Text(
                      _weekdayLabels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isWeekend
                            ? AppColors.textFaint
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _MonthGrid(
                cells: _buildMonthCells(),
                today: today,
                start: start,
                end: end,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                onTap: _onDayTap,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (start != null && end != null)
                        ? () => Navigator.pop(
                            context,
                            DateTimeRange(start: start, end: end),
                          )
                        : null,
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final List<DateTime?> cells;
  final DateTime today;
  final DateTime? start;
  final DateTime? end;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onTap;

  const _MonthGrid({
    required this.cells,
    required this.today,
    required this.start,
    required this.end,
    required this.firstDate,
    required this.lastDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemBuilder: (context, index) {
        final day = cells[index];
        if (day == null) return const SizedBox.shrink();

        final isToday = _sameDay(day, today);
        final isStart = start != null && _sameDay(day, start!);
        final isEnd = end != null && _sameDay(day, end!);
        final inRange =
            start != null &&
            end != null &&
            day.isAfter(start!) &&
            day.isBefore(end!);
        final isEdge = isStart || isEnd;
        final highlighted = isEdge || inRange;
        final disabled = day.isBefore(firstDate) || day.isAfter(lastDate);
        final isWeekend =
            day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (highlighted)
                Positioned.fill(
                  child: Container(
                    color: AppColors.teal.withValues(alpha: 0.12),
                  ),
                ),
              InkWell(
                onTap: disabled ? null : () => onTap(day),
                customBorder: const CircleBorder(),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEdge ? AppColors.teal : null,
                    border: isToday && !isEdge
                        ? Border.all(color: AppColors.teal, width: 1.4)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isEdge || isToday
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: disabled
                            ? AppColors.textFaint.withValues(alpha: 0.5)
                            : isEdge
                            ? Colors.white
                            : isWeekend
                            ? AppColors.textFaint
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
