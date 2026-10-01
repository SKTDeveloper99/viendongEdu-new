import 'package:flutter/material.dart';
import '../services/crm_teacher_api.dart';
import '../services/crm_session_guard.dart';
import '../components/skeleton.dart';
import '../features/teacher_attendance/schedule_card.dart';
import '../core/school_calendar.dart';
import '../models/crm_teacher_class.dart';
import '../theme/vd_tokens.dart';

class GvScheduleScreen extends StatefulWidget {
  final SchoolCalendar? calendar;
  final Future<List<CrmScheduleSlot>> Function(String date)? loadSchedule;

  const GvScheduleScreen({super.key, this.calendar, this.loadSchedule});
  @override
  State<GvScheduleScreen> createState() => _GvScheduleScreenState();
}

class _GvScheduleScreenState extends State<GvScheduleScreen> {
  late final SchoolCalendar _calendar;
  late DateTime _selectedDate;
  late DateTime _currentMonday;
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  String? _error;
  final ScrollController _chipScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _calendar = widget.calendar ?? SchoolCalendar();
    _selectedDate = _calendar.today;
    _currentMonday = _findMonday(_selectedDate);
    _fetch(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _chipScroll.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_chipScroll.hasClients) return;
    final weekDays = _weekDays;
    int index = weekDays.indexWhere(
      (d) => _fmtDate(d) == _fmtDate(_selectedDate),
    );
    if (index == -1) return;
    const chipWidth = 60.0;
    const chipMargin = 8.0;
    final chipOffset = index * (chipWidth + chipMargin);
    final viewport = _chipScroll.position.viewportDimension;
    final center = (chipOffset - viewport / 2 + chipWidth / 2).clamp(
      0.0,
      _chipScroll.position.maxScrollExtent,
    );
    _chipScroll.animateTo(
      center,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _fetch(DateTime date) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dateStr = SchoolCalendar.isoDate(date);
      final data = await (widget.loadSchedule ?? CrmTeacherApi.scheduleForDate)(
        dateStr,
      );
      if (!mounted) return;
      setState(() {
        _classes = data.map((e) => e.toJson()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  DateTime _findMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _currentMonday.add(Duration(days: i)));
  String _fmtDate(DateTime d) => SchoolCalendar.isoDate(d);

  void _prevWeek() {
    setState(
      () => _currentMonday = _currentMonday.subtract(const Duration(days: 7)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _nextWeek() {
    setState(
      () => _currentMonday = _currentMonday.add(const Duration(days: 7)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _selectDate(DateTime date) {
    final selected = SchoolCalendar.dateOnly(date);
    setState(() => _selectedDate = selected);
    _fetch(selected);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: context.vd.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _currentMonday = _findMonday(picked));
      _selectDate(picked);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vd.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickDate,
        backgroundColor: context.vd.primary,
        icon: Icon(Icons.calendar_month, color: context.vd.onPrimary, size: 20),
        label: Text(
          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
          style: TextStyle(color: context.vd.onPrimary, fontSize: 13),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.vd.primary, context.vd.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        'Lịch dạy',
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
                        onTap: _prevWeek,
                        child: Icon(
                          Icons.chevron_left,
                          color: context.vd.onPrimary,
                          size: 28,
                        ),
                      ),
                      Text(
                        () {
                          final s = _currentMonday;
                          final e = _currentMonday.add(const Duration(days: 6));
                          return '${s.day}/${s.month} – ${e.day}/${e.month}/${e.year}';
                        }(),
                        style: TextStyle(
                          color: context.vd.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: _nextWeek,
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
                      controller: _chipScroll,
                      scrollDirection: Axis.horizontal,
                      itemCount: _weekDays.length,
                      itemBuilder: (context, i) {
                        final day = _weekDays[i];
                        final isSelected =
                            _fmtDate(day) == _fmtDate(_selectedDate);
                        final isToday =
                            _fmtDate(day) == _fmtDate(_calendar.today);
                        return GestureDetector(
                          key: ValueKey('schedule-day-${_fmtDate(day)}'),
                          onTap: () => _selectDate(day),
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
                                  [
                                    'T2',
                                    'T3',
                                    'T4',
                                    'T5',
                                    'T6',
                                    'T7',
                                    'CN',
                                  ][day.weekday - 1],
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
                                    key: ValueKey(
                                      'schedule-today-${_fmtDate(day)}',
                                    ),
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
            ),

            // ── Content ──
            Expanded(
              child: _loading
                  ? skeletonList()
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: context.vd.inkFaint,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(color: context.vd.inkFaint),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _fetch(_selectedDate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.vd.primary,
                            ),
                            child: Text(
                              'Thử lại',
                              style: TextStyle(color: context.vd.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _classes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: context.vd.inkFaint,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Không có lịch dạy',
                            style: TextStyle(color: context.vd.inkFaint),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _fetch(_selectedDate),
                      color: context.vd.primary,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _classes.length,
                        itemBuilder: (ctx, i) => ScheduleCard(
                          data: _classes[i],
                          date: _fmtDate(_selectedDate),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
