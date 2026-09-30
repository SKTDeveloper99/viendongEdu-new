import 'package:flutter/material.dart';
import '../models/crm_teacher_profile.dart' show CrmSemester;
import '../services/crm_teacher_api.dart';
import '../services/crm_session_guard.dart';
import '../components/skeleton.dart';
import '../theme/vd_tokens.dart';

typedef _Semester = CrmSemester;

// Thứ tự ngày trong tuần theo ngayma
const _dayOrder = {'2': 0, '3': 1, '4': 2, '5': 3, '6': 4, '7': 5, '8': 6};

int _dayIndex(String ngayma) =>
    _dayOrder[ngayma.trim()] ?? 99;

class GvLopHocScreen extends StatefulWidget {
  const GvLopHocScreen({super.key});

  @override
  State<GvLopHocScreen> createState() => _GvLopHocScreenState();
}

class _GvLopHocScreenState extends State<GvLopHocScreen> {
  List<_Semester> _semesters = [];
  _Semester? _selected;
  // grouped: ngayten → list of items
  List<({String ngayten, List<Map<String, dynamic>> items})> _grouped = [];
  bool _loadingHocKy = true;
  bool _loadingClasses = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHocKy();
  }

  Future<void> _fetchHocKy() async {
    setState(() { _loadingHocKy = true; _error = null; });
    try {
      final data = await CrmTeacherApi.semesters();
      final sems = [...data]..sort((a, b) => b.id.compareTo(a.id));
      if (!mounted) return;
      setState(() { _semesters = sems; _loadingHocKy = false; });
      final def = await CrmTeacherApi.defaultSemester(
        sems,
        (s) => s.ma,
        (s) => s.ngayBatDau,
      );
      if (!mounted) return;
      if (def != null) await _fetchClasses(def);
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (!mounted) return;
      setState(() { _loadingHocKy = false; _error = e.toString(); });
    }
  }

  Future<void> _fetchClasses(_Semester sem) async {
    setState(() { _selected = sem; _loadingClasses = true; _error = null; });
    try {
      final data = await CrmTeacherApi.scheduleForSemester(sem.id.toString());
      if (!mounted) return;

      // Dedup theo (lmhid + ngayma + tietbd + phongma) — tránh trùng y chang
      final seen = <String>{};
      final rows = <Map<String, dynamic>>[];
      for (final e in data) {
        final m = e.toJson();
        final key =
            '${m['lmhid']}_${(m['ngayma'] as String? ?? '').trim()}_${m['tietbd']}_${m['phongten']}';
        if (seen.add(key)) rows.add(m);
      }

      // Group theo ngayma, sort thứ tự ngày
      final Map<String, List<Map<String, dynamic>>> map = {};
      for (final r in rows) {
        final ngayten = r['ngayten'] as String? ?? '';
        map.putIfAbsent(ngayten, () => []).add(r);
      }

      // Sort từng ngày theo tgbatdau
      for (final list in map.values) {
        list.sort((a, b) =>
            (a['tgbatdau'] as String? ?? '').compareTo(b['tgbatdau'] as String? ?? ''));
      }

      // Sort các ngày theo thứ tự Thứ 2 → Chủ nhật
      final entries = map.entries.toList()
        ..sort((a, b) {
          final ngaymaA = rows
              .firstWhere((r) => r['ngayten'] == a.key,
                  orElse: () => {'ngayma': ''})['ngayma'] as String? ??
              '';
          final ngaymaB = rows
              .firstWhere((r) => r['ngayten'] == b.key,
                  orElse: () => {'ngayma': ''})['ngayma'] as String? ??
              '';
          return _dayIndex(ngaymaA).compareTo(_dayIndex(ngaymaB));
        });
      setState(() {
        _grouped = entries
            .map((e) => (ngayten: e.key, items: e.value))
            .toList();
        _loadingClasses = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (!mounted) return;
      setState(() { _loadingClasses = false; _error = e.toString(); });
    }
  }

  void _retry() {
    if (_semesters.isEmpty) {
      _fetchHocKy();
    } else if (_selected != null) {
      _fetchClasses(_selected!);
    } else {
      _fetchHocKy();
    }
  }

  // Flatten grouped data thành list widget items (header + cards)
  List<Widget> _buildItems() {
    final items = <Widget>[];
    for (final group in _grouped) {
      items.add(_DayHeader(
        ngayten: group.ngayten,
        count: group.items.length,
      ));
      for (final d in group.items) {
        items.add(_LopCard(data: d));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _grouped.isEmpty;

    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(top: false, child: Column(
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.arrow_back_ios,
                          color: context.vd.onPrimary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lớp học',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.vd.onPrimary,
                      ),
                    ),
                  ],
                ),
                if (!_loadingHocKy && _semesters.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: context.vd.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_Semester>(
                        value: _selected,
                        dropdownColor: context.vd.surface,
                        borderRadius: BorderRadius.circular(14),
                        iconEnabledColor: context.vd.primary,
                        icon: const Icon(Icons.expand_more_rounded, size: 20),
                        isDense: true,
                        style: TextStyle(color: context.vd.ink, fontSize: 13, fontWeight: FontWeight.w500),
                        selectedItemBuilder: (_) => _semesters.map((s) => Center(
                          child: Text(s.ten, style: TextStyle(color: context.vd.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                        )).toList(),
                        items: _semesters.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.ten),
                        )).toList(),
                        onChanged: (s) { if (s != null) _fetchClasses(s); },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loadingHocKy
                ? skeletonList()
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: context.vd.inkFaint),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: TextStyle(color: context.vd.inkFaint),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _retry,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: context.vd.primary),
                              child: Text('Thử lại',
                                  style: TextStyle(color: context.vd.onPrimary)),
                            ),
                          ],
                        ),
                      )
                    : _loadingClasses
                        ? skeletonList()
                        : isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.class_outlined,
                                        size: 64, color: context.vd.inkFaint),
                                    SizedBox(height: 12),
                                    Text('Không có lớp học',
                                        style: TextStyle(color: context.vd.inkFaint)),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  if (_selected != null) await _fetchClasses(_selected!);
                                },
                                color: context.vd.primary,
                                child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                children: _buildItems(),
                              ),
                            ),
          ),
        ],
      )),
    );
  }
}

// ── Day Header ────────────────────────────────────────
class _DayHeader extends StatelessWidget {
  final String ngayten;
  final int count;
  const _DayHeader({required this.ngayten, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: context.vd.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ngayten,
              style: TextStyle(
                color: context.vd.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count lớp',
            style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 1, color: context.vd.hairline),
          ),
        ],
      ),
    );
  }
}

// ── Lop Card ─────────────────────────────────────────
class _LopCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LopCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final mhten = data['mhten']?.toString() ?? '';
    final lmhma = data['lmhma']?.toString() ?? '';
    final sotinchi = data['sotinchi'] as int? ?? 0;
    final phongten = data['phongten']?.toString() ?? '';
    final tietbd = data['tietbd']?.toString() ?? '';
    final tgbd = data['tgbatdau']?.toString() ?? '';
    final tgkt = data['tgketthuc']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: context.vd.shadow, blurRadius: 5, offset: Offset(0, 2))
        ],
        border: Border(
            left: BorderSide(color: context.vd.primary, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            // Giờ
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(tgbd,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.vd.primary)),
                Text(tgkt,
                    style: TextStyle(
                        fontSize: 12, color: context.vd.inkFaint)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.vd.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tietbd,
                      style: TextStyle(
                          fontSize: 10,
                          color: context.vd.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 52, color: context.vd.hairline),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(mhten,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (sotinchi > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                context.vd.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$sotinchi TC',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.vd.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (phongten.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.room,
                            size: 13, color: context.vd.primary),
                        const SizedBox(width: 4),
                        Text(phongten,
                            style: TextStyle(
                                fontSize: 12, color: context.vd.inkFaint)),
                      ],
                    ),
                  if (lmhma.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.class_outlined,
                              size: 13, color: context.vd.primary),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(lmhma,
                              style: TextStyle(
                                  fontSize: 12, color: context.vd.inkFaint),
                              softWrap: true),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
