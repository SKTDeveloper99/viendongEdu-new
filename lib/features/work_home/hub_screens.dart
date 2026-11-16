import 'package:flutter/material.dart';

import '../../components/next_up_card.dart';
import '../../core/crm_web/crm_web_target.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../nhom/small_group_screens.dart';
import '../teacher_home/next_up.dart';
import '../teacher_home/teacher_home_view_model.dart';
import '../teacher_home/widgets/my_day_card.dart';
import '../teacher_home/widgets/schedule_section.dart';
import '../teacher_home/widgets/week_strip.dart';
import '../work/piece_screen.dart';
import '../work/work_api.dart';
import 'home_prefs.dart';
import 'home_widgets.dart';

Future<void> openWeekPage(BuildContext context) async {
  await HomePrefs.setLichLast('week');
  if (!context.mounted) return;
  await Navigator.pushNamed(context, const CrmTarget.week().routeName);
}

/// Lịch for a teacher (or an account that is both): "Lịch tuần trường" is the
/// first row; then Lịch dạy with the week strip; then Lịch thi and Danh sách thi.
class LichScreen extends StatefulWidget {
  final TeacherHomeViewModel vm;
  final bool openWeekFirst;
  const LichScreen({super.key, required this.vm, this.openWeekFirst = false});

  @override
  State<LichScreen> createState() => _LichScreenState();
}

class _LichScreenState extends State<LichScreen> {
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    if (widget.openWeekFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openWeekPage(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final vm = widget.vm;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Lịch')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            HubRow(
              icon: Icons.event_note,
              title: 'Lịch tuần trường',
              subtitle: 'Lịch công tác tuần, Triển khai',
              onTap: () => openWeekPage(context),
            ),
            const SizedBox(height: 4),
            Text(
              'LỊCH DẠY',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: vd.inkMuted,
              ),
            ),
            WeekStrip(
              today: vm.today,
              selected: vm.selectedDay,
              dotStartsFor: vm.dotStartsFor,
              onSelect: (d) {
                HomePrefs.setLichLast('teach');
                vm.selectDay(d);
              },
            ),
            ScheduleSection(
              now: vm.now,
              day: vm.viewingToday ? null : vm.selectedDay,
              classes: vm.shownClasses,
              loading: vm.shownLoading,
              failed: vm.shownFailed,
              expanded: _expanded,
              staleAt: vm.viewingToday ? vm.scheduleStaleAt : null,
              onToggle: () => setState(() => _expanded = !_expanded),
              onRetry: vm.viewingToday ? vm.loadOverview : vm.reloadSelectedDay,
            ),
            const SizedBox(height: 12),
            HubRow(
              icon: Icons.calendar_month,
              title: 'Lịch dạy cả tuần',
              onTap: () => Navigator.pushNamed(context, '/gv_schedule'),
            ),
            const SizedBox(height: 8),
            Text(
              'LỊCH THI',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: vd.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            HubRow(
              icon: Icons.assignment_outlined,
              title: 'Lịch thi',
              onTap: () => Navigator.pushNamed(context, '/gv_lichthi'),
            ),
            HubRow(
              icon: Icons.how_to_reg_outlined,
              title: 'Danh sách thi',
              onTap: () => Navigator.pushNamed(context, '/gv_danh_sach_thi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lớp: today's classes and attendance, Lớp của tôi, Sinh viên, Ngày làm việc.
class LopScreen extends StatelessWidget {
  final TeacherHomeViewModel vm;
  final bool studentLookup;
  const LopScreen({super.key, required this.vm, this.studentLookup = false});

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Lớp')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (!vm.scheduleLoading && !vm.scheduleFailed)
              NextUpCard(
                state: vm.upNext,
                emptyText: teacherNextUpEmpty,
                showClassCode: true,
                onAttendance: () =>
                    Navigator.pushNamed(context, '/ems_attendance_gv'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              child: ScheduleSection(
                now: vm.now,
                day: null,
                classes: vm.todayClasses,
                loading: vm.scheduleLoading,
                failed: vm.scheduleFailed,
                expanded: true,
                staleAt: vm.scheduleStaleAt,
                onToggle: () {},
                onRetry: vm.loadOverview,
              ),
            ),
            const MyDayCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  HubRow(
                    icon: Icons.fact_check_outlined,
                    title: 'Điểm danh',
                    onTap: () =>
                        Navigator.pushNamed(context, '/ems_attendance_gv'),
                  ),
                  HubRow(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Lớp của tôi',
                    onTap: () => Navigator.pushNamed(context, '/gv_quanly_lop'),
                  ),
                  HubRow(
                    icon: Icons.groups_outlined,
                    title: 'Sinh viên của tôi',
                    onTap: () => Navigator.pushNamed(context, '/gv_sinh_vien'),
                  ),
                  if (studentLookup)
                    HubRow(
                      icon: Icons.person_search_outlined,
                      title: 'Tra cứu sinh viên',
                      onTap: () => Navigator.pushNamed(
                        context,
                        const CrmTarget.students().routeName,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VanPhongScreen extends StatelessWidget {
  final bool congVan;
  const VanPhongScreen({super.key, required this.congVan});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.vd.bg,
    appBar: AppBar(title: const Text('Văn phòng')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (congVan)
          HubRow(
            icon: Icons.description_outlined,
            title: 'Công văn',
            onTap: () => Navigator.pushNamed(
              context,
              const CrmTarget.congVan().routeName,
            ),
          ),
        HubRow(
          icon: Icons.edit_note,
          title: 'Nhật ký làm việc',
          onTap: () =>
              Navigator.pushNamed(context, const CrmTarget.workLog().routeName),
        ),
      ],
    ),
  );
}

class ThemScreen extends StatelessWidget {
  const ThemScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.vd.bg,
    appBar: AppBar(title: const Text('Thêm')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HubRow(
          icon: Icons.language,
          title: 'Viva',
          subtitle: 'Mọi trang Viva còn lại',
          onTap: () =>
              Navigator.pushNamed(context, const CrmTarget.viva().routeName),
        ),
      ],
    ),
  );
}

/// "+ Giao việc": a new piece of work to one or more people.
class GiveTaskScreen extends StatefulWidget {
  const GiveTaskScreen({super.key});

  @override
  State<GiveTaskScreen> createState() => _GiveTaskScreenState();
}

class _GiveTaskScreenState extends State<GiveTaskScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  Map<String, String> _people = {};
  DateTime? _due;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final r = await EmsApiService.sendMap(
        'POST',
        '/v1/tasks',
        body: {
          'title': _title.text.trim(),
          if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
          if (_due != null) 'due_at': _due!.toUtc().toIso8601String(),
          'assignee_user_ids': _people.keys.toList(),
          'requires_review': true,
        },
      );
      if (!mounted) return;
      showSuccessSnack(context, 'Đã giao việc cho ${_people.length} người.');
      final id = (r['task'] as Map?)?['id']?.toString();
      if (id != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PieceScreen(taskId: id)),
        );
      } else {
        Navigator.pop(context);
      }
    } on EmsException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _people.isNotEmpty && _title.text.trim().isNotEmpty && !_busy;
    return Scaffold(
      backgroundColor: context.vd.bg,
      appBar: AppBar(title: const Text('Giao việc')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Việc cần làm',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mô tả (không bắt buộc)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final r = await Navigator.push<Map<String, String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => const PeoplePicker(title: 'Giao cho ai?'),
                ),
              );
              if (r != null) setState(() => _people = {..._people, ...r});
            },
            icon: const Icon(Icons.person_add_alt),
            label: Text(
              _people.isEmpty ? 'Chọn người nhận' : _people.values.join(', '),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
                initialDate: now.add(const Duration(days: 2)),
              );
              if (d != null)
                setState(() => _due = DateTime(d.year, d.month, d.day, 17));
            },
            icon: const Icon(Icons.event),
            label: Text(
              _due == null ? 'Chọn hạn' : dueLabel(_due!.toIso8601String()),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: ok ? _send : null,
            child: Text(_busy ? 'Đang giao…' : 'Giao việc'),
          ),
        ],
      ),
    );
  }
}
