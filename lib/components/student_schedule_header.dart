import 'package:flutter/material.dart';

import '../theme/vd_tokens.dart';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class StudentScheduleHeader extends StatelessWidget {
  final List<DateTime> weekDays;
  final String weekLabel;
  final DateTime selectedDate;
  final DateTime today;
  final ScrollController chipScroll;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onSelectDate;

  const StudentScheduleHeader({
    super.key,
    required this.weekDays,
    required this.weekLabel,
    required this.selectedDate,
    required this.today,
    required this.chipScroll,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [context.vd.primary, context.vd.accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back + title
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(
                Icons.arrow_back_ios,
                color: context.vd.onPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Lịch học',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.vd.onPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Week navigator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onPrevWeek,
              child: Icon(
                Icons.chevron_left,
                color: context.vd.onPrimary,
                size: 28,
              ),
            ),
            Text(
              weekLabel,
              style: TextStyle(
                color: context.vd.onPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: onNextWeek,
              child: Icon(
                Icons.chevron_right,
                color: context.vd.onPrimary,
                size: 28,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Day chips
        SizedBox(
          height: 84,
          child: ListView.builder(
            controller: chipScroll,
            scrollDirection: Axis.horizontal,
            itemCount: weekDays.length,
            itemBuilder: (context, i) {
              final day = weekDays[i];
              final isSelected = _sameDay(day, selectedDate);
              final isToday = _sameDay(day, today);
              return GestureDetector(
                onTap: () => onSelectDate(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.vd.surface
                        : context.vd.surface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][day.weekday -
                            1],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? context.vd.primary
                              : context.vd.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? context.vd.primary
                              : context.vd.onPrimary,
                        ),
                      ),
                      if (isToday)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.vd.primary
                                : context.vd.surface,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
