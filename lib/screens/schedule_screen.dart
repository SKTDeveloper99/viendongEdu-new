import '../components/skeleton.dart';
import '../components/student_notices.dart';
import '../core/schedule/unmarked_session.dart';
import '../components/schedule_exam_card.dart';
import '../components/exam_load_warning.dart';
import '../models/crm_student_exams.dart';
import 'stale_note.dart';
import 'package:flutter/material.dart';
import '../models/crm_student_schedule.dart';
import '../services/app_session.dart';
import '../services/crm_student_api.dart';
import '../services/ems_api_service.dart';
import '../services/crm_session_guard.dart';
import '../data/api/attendance_api.dart';
import '../theme/vd_tokens.dart';
import '../components/student_schedule_header.dart';
import '../components/student_schedule_card.dart';
import '../components/unscheduled_subjects.dart';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _currentMonday;
  late DateTime _selectedDate;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  // Load all schedule slots once; cache the occurrences by calendar day.
  List<CrmScheduleItem>? _fullSchedule;
  CrmStudentScheduleView _view = const CrmStudentScheduleView();
  bool _scheduleFailed = false;
  String? _scheduleError;
  final Map<String, List<CrmScheduleItem>> _cache = {};
  bool _loading = false;
  DateTime? _staleAt;
  List<CrmStudentExam> _exams = [];
  bool _examsLoading = true;
  bool _examsFailed = false;
  DateTime? _examsStaleAt;

  Future<void> _fetchExams() async {
    setState(() => _examsLoading = true);
    try {
      final r = await CrmStudentApi.examsCached();
      if (!mounted) return;
      setState(() {
        _exams = r.data.exams;
        _examsFailed = false;
        _examsStaleAt = r.fresh ? null : r.savedAt;
      });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (mounted) setState(() => _examsFailed = true);
    } finally {
      if (mounted) setState(() => _examsLoading = false);
    }
  }

  // Attendance is read from EMS; schedule and exam details come from CRM.
  final Map<String, EmsStudentMark> _emsByKey = {};
  bool _emsLoaded = false;
  bool _marksLoading = true;
  bool _marksFailed = false;
  bool _marksDenied = false;

  static String _markKey(String sectionCode, String date, [String? hhmm]) =>
      '$sectionCode|$date|${hhmm ?? ''}';

  Future<void> _loadEmsMarks({bool force = false}) async {
    if (_emsLoaded && !force) return;
    if (mounted) setState(() => _marksLoading = true);
    if (!AppSession.instance.hasEms) {
      await AppSession.instance.refreshEmsToken(force: force);
      if (!mounted || !AppSession.instance.hasEms) return;
    }
    try {
      final marks = await AttendanceApi.myAttendance(limit: 400);
      if (!mounted) return;
      setState(() {
        _emsByKey.clear();
        for (final m in marks) {
          final code = m.sectionCode ?? '';
          final date = m.sessionDate ?? '';
          if (code.isEmpty || date.isEmpty) continue;
          final hhmm = _startFromSessionKey(m.sessionKey) ?? m.startTime;
          // EMS thắng IMS cho cùng một buổi; không bao giờ ngược lại.
          void put(String k) {
            final cur = _emsByKey[k];
            if (cur == null || (cur.source != 'ems' && m.source == 'ems')) {
              _emsByKey[k] = m;
            }
          }

          put(_markKey(code, date));
          if (hhmm != null) put(_markKey(code, date, hhmm));
        }
        _emsLoaded = true;
        _marksLoading = false;
        _marksFailed = false;
        _marksDenied = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() {
        _emsByKey.clear();
        _emsLoaded = false;
        _marksLoading = false;
        _marksFailed = true;
        _marksDenied = e is EmsException && e.statusCode == 403;
      });
    }
  }

  /// `43371:07-30:2026-09-11` → `07:30`. Khoá IMS (`ims:<id>`) → null.
  static String? _startFromSessionKey(String? key) {
    if (key == null) return null;
    final parts = key.split(':');
    if (parts.length < 3) return null;
    final m = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(parts[1]);
    return m == null ? null : '${m.group(1)}:${m.group(2)}';
  }

  String _statusFor(CrmScheduleItem data, String date) {
    if (_marksLoading) return 'loading';
    if (_marksDenied) return 'denied';
    if (_marksFailed) return 'unavailable';
    final code = data.sectionCode;
    final start = (data.startTime ?? '').trim();
    final hhmm = start.length >= 5 ? start.substring(0, 5) : null;
    final m =
        (hhmm != null ? _emsByKey[_markKey(code, date, hhmm)] : null) ??
        _emsByKey[_markKey(code, date)];
    final known = switch (m?.status) {
      'present' || 'late' => 'present',
      'absent' => 'absent',
      'excused' => 'excused',
      _ => null,
    };
    // No mark row (or an unmarked one): say what that means for this date.
    return known ??
        unmarkedSessionOn(sessionDay(date) ?? _now(), _now()).statusKey;
  }

  final ScrollController _chipScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = _now();
    _currentMonday = _findMonday(now);
    _selectedDate = now;
    _fetchDate(now);
    _fetchExams();
    _loadEmsMarks();
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

  DateTime _findMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _currentMonday.add(Duration(days: i)));

  Future<void> _fetchDate(DateTime date) async {
    final key = _fmtDate(date);
    if (_cache.containsKey(key)) return; // đã có cache

    setState(() {
      _loading = true;
      _scheduleFailed = false;
      _scheduleError = null;
    });
    try {
      if (_fullSchedule == null) {
        final r = await CrmStudentApi.scheduleViewCached();
        if (!mounted) return;
        _fullSchedule = r.data.schedule;
        _view = r.data;
        _staleAt = r.fresh ? null : r.savedAt;
      }
      if (!mounted) return;
      setState(() {
        _cache[key] = _fullSchedule!.where((s) => s.occursOn(date)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() {
        _scheduleFailed = true;
        _scheduleError = crmErrorMessage(e);
        _view = const CrmStudentScheduleView();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _fetchDate(date);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _prevWeek() {
    setState(() {
      _currentMonday = _currentMonday.subtract(const Duration(days: 7));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _nextWeek() {
    setState(() {
      _currentMonday = _currentMonday.add(const Duration(days: 7));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
      // The app theme already carries light and dark pickers; forcing
      // ColorScheme.light here made it glare in dark mode.
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentMonday = _findMonday(picked);
      });
      _fetchDate(picked);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _weekDays;
    final start = _currentMonday;
    final end = _currentMonday.add(const Duration(days: 6));
    final weekLabel =
        '${start.day}/${start.month} – ${end.day}/${end.month}/${end.year}';
    final key = _fmtDate(_selectedDate);
    final classes = _cache[key] ?? <CrmScheduleItem>[];
    final exams = _exams.where((e) => e.occursOn(_selectedDate)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

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
            StudentScheduleHeader(
              examDays: _exams
                  .map((e) => e.examDate)
                  .whereType<DateTime>()
                  .toList(),
              weekDays: weekDays,
              weekLabel: weekLabel,
              selectedDate: _selectedDate,
              today: _now(),
              chipScroll: _chipScroll,
              onPrevWeek: _prevWeek,
              onNextWeek: _nextWeek,
              onSelectDate: _selectDate,
            ),

            if (_staleAt != null) StaleNote(_staleAt!),
            if (_examsStaleAt != null) StaleNote(_examsStaleAt!),
            StudentNoticeList(
              notices: _view.notices,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            ),
            Expanded(
              child: _loading || _examsLoading
                  ? skeletonList(accentColor: context.vd.primary)
                  : RefreshIndicator(
                      color: context.vd.primary,
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          if (_examsFailed)
                            ExamLoadWarning(
                              onRetry: _scheduleFailed ? _refresh : _fetchExams,
                            ),
                          for (final exam in exams)
                            ScheduleExamCard(exam: exam),
                          if (_scheduleFailed) ...[
                            Text(
                              _scheduleError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.vd.inkMuted),
                            ),
                            if (!_examsFailed)
                              TextButton(
                                onPressed: _refresh,
                                child: const Text('Thử lại'),
                              ),
                          ],
                          if (!_scheduleFailed &&
                              !_examsFailed &&
                              classes.isEmpty &&
                              exams.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: _emptyDay(context),
                            ),
                          for (final data in classes)
                            StudentScheduleCard(
                              data: data,
                              status: _statusFor(data, key),
                            ),
                          if (_view.chuaCoLich.isNotEmpty)
                            UnscheduledSubjects(sections: _view.chuaCoLich),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    _cache.clear();
    _fullSchedule = null;
    await Future.wait([
      _fetchDate(_selectedDate),
      _fetchExams(),
      _loadEmsMarks(force: true),
    ]);
  }

  Widget _emptyDay(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.event_available, size: 64, color: context.vd.inkFaint),
      const SizedBox(height: 12),
      Text('Không có lịch học', style: TextStyle(color: context.vd.inkFaint)),
    ],
  );
}
