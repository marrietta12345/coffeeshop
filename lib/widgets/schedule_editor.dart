import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/operating_hours.dart';

/// Weekly opening-hours editor for owners: one row per day with an
/// open/closed switch and its opening & closing times. Turning a day on
/// asks for its times (or copies the last day set) — nothing is filled
/// in for the owner. A closing time earlier than the opening time means
/// the café closes after midnight.
class ScheduleEditor extends StatelessWidget {
  final OperatingHours value;
  final ValueChanged<OperatingHours> onChanged;

  const ScheduleEditor({super.key, required this.value, required this.onChanged});

  Future<int?> _pickTime(BuildContext context, {required String help, int? initial}) async {
    final picked = await showTimePicker(
      context: context,
      helpText: help,
      initialTime: initial == null
          ? const TimeOfDay(hour: 0, minute: 0)
          : TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryBrown)),
        child: child!,
      ),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  void _set(int weekday, DayHours? hours) {
    final days = Map<int, DayHours>.of(value.days);
    if (hours == null) {
      days.remove(weekday);
    } else {
      days[weekday] = hours;
    }
    onChanged(value.copyWith(days: days));
  }

  Future<void> _toggle(BuildContext context, int weekday, bool open) async {
    if (!open) return _set(weekday, null);
    // Reuse the most recently set day's hours, if any.
    DayHours? reference;
    for (var d = weekday - 1; d >= 1 && reference == null; d--) {
      reference = value.days[d];
    }
    for (var d = 7; d > weekday && reference == null; d--) {
      reference = value.days[d];
    }
    if (reference != null) return _set(weekday, reference);
    final day = OperatingHours.dayNames[weekday]!;
    final open0 = await _pickTime(context, help: '$day — opening time');
    if (open0 == null || !context.mounted) return;
    final close = await _pickTime(context, help: '$day — closing time');
    if (close == null) return;
    _set(weekday, DayHours(open0, close));
  }

  Future<void> _editTime(BuildContext context, int weekday, {required bool opening}) async {
    final hours = value.days[weekday]!;
    final day = OperatingHours.dayNames[weekday]!;
    final picked = await _pickTime(
      context,
      help: '$day — ${opening ? 'opening' : 'closing'} time',
      initial: opening ? hours.openMinute : hours.closeMinute,
    );
    if (picked == null) return;
    _set(weekday, opening ? DayHours(picked, hours.closeMinute) : DayHours(hours.openMinute, picked));
  }

  @override
  Widget build(BuildContext context) {
    int? firstSetDay;
    for (var d = 1; d <= 7 && firstSetDay == null; d++) {
      if (value.days.containsKey(d)) firstSetDay = d;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var weekday = 1; weekday <= 7; weekday++) _dayRow(context, weekday),
        // Shortcut: same hours every day (hidden once they already are).
        if (firstSetDay != null && !_sameEveryDay)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
              onPressed: () => onChanged(value.copyWith(days: {
                for (var d = 1; d <= 7; d++) d: value.days[firstSetDay]!,
              })),
              icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppColors.primaryBrown),
              label: Text(
                'Use ${OperatingHours.shortDayNames[firstSetDay]} hours for every day',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryBrown),
              ),
            ),
          ),
        const Text(
          'Open past midnight? Set a closing time earlier than the opening time (e.g. 6:00 PM – 2:00 AM).',
          style: TextStyle(fontSize: 11, color: AppColors.textGrey, height: 1.4),
        ),
      ],
    );
  }

  bool get _sameEveryDay => value.days.length == 7 && value.days.values.toSet().length == 1;

  Widget _dayRow(BuildContext context, int weekday) {
    final hours = value.days[weekday];
    final isOpen = hours != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 12, right: 6),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              OperatingHours.shortDayNames[weekday]!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
          Expanded(
            child: isOpen
                ? Row(
                    children: [
                      _TimeChip(
                        label: OperatingHours.formatTime(hours.openMinute),
                        onTap: () => _editTime(context, weekday, opening: true),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('–', style: TextStyle(color: AppColors.textGrey)),
                      ),
                      _TimeChip(
                        label: OperatingHours.formatTime(hours.closeMinute),
                        onTap: () => _editTime(context, weekday, opening: false),
                      ),
                    ],
                  )
                : const Text('Closed', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
          ),
          Switch(
            value: isOpen,
            onChanged: (open) => _toggle(context, weekday, open),
            activeTrackColor: AppColors.primaryBrown,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryBrown.withOpacity(0.3)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryBrown),
          ),
        ),
      ),
    );
  }
}
