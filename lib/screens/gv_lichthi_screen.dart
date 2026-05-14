import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../components/skeleton.dart';

class _Semester {
  final int id;
  final String ten;
  final String ngayBatDau;
  final String ngayKetThuc;
  const _Semester({
    required this.id,
    required this.ten,
    required this.ngayBatDau,
    required this.ngayKetThuc,
  });
}

class GvLichThiScreen extends StatefulWidget {
  const GvLichThiScreen({super.key});

  @override
  State<GvLichThiScreen> createState() => _GvLichThiScreenState();
}

class _GvLichThiScreenState extends State<GvLichThiScreen> {
  List<_Semester> _semesters = [];
  _Semester? _selected;
  List<Map<String, dynamic>> _exams = [];
  bool _loadingHocKy = true;
  bool _loadingExams = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHocKy();
  }

  Future<void> _fetchHocKy() async {
    setState(() { _loadingHocKy = true; _error = null; });
    try {
      final data = await ApiService.getHocKy();
      final sems = data.map((e) {
        return _Semester(
          id: e['id'] as int,
          ten: e['ten'] as String? ?? '',
          ngayBatDau: e['ngaybatdau'] as String? ?? '',
          ngayKetThuc: e['ngayketthuc'] as String? ?? '',
        );
      }).toList();
      sems.sort((a, b) => b.id.compareTo(a.id));
      if (!mounted) return;
      setState(() {
        _semesters = sems;
        _loadingHocKy = false;
      });
      if (sems.isNotEmpty) await _fetchExams(sems.first);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingHocKy = false; _error = e.toString(); });
    }
  }

  Future<void> _fetchExams(_Semester sem) async {
    setState(() { _selected = sem; _loadingExams = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getGvLichThi(sem.ngayBatDau, sem.ngayKetThuc),
        ApiService.getGvDanhSachLop(sem.id),
      ]);
      if (!mounted) return;

      final lopMap = {
        for (final e in results[1].cast<Map<String, dynamic>>())
          e['id'] as int: e,
      };

      final list = results[0]
          .map((e) => e as Map<String, dynamic>)
          .where((e) => lopMap.containsKey(e['lopId'] as int?))
          .map((e) {
            final lop = lopMap[e['lopId'] as int]!;
            final monHoc = lop['monHoc'] as Map<String, dynamic>? ?? {};
            return {
              ...e,
              '_tenMon': monHoc['ten']?.toString() ?? '',
              '_maLop': lop['ma']?.toString() ?? '',
            };
          })
          .toList();

      list.sort((a, b) {
        final da = a['ngayThi'] as String? ?? '';
        final db = b['ngayThi'] as String? ?? '';
        return da.compareTo(db);
      });
      setState(() {
        _exams = list;
        _loadingExams = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingExams = false; _error = e.toString(); });
    }
  }

  void _retry() {
    if (_semesters.isEmpty) {
      _fetchHocKy();
    } else if (_selected != null) {
      _fetchExams(_selected!);
    } else {
      _fetchHocKy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(top: false, child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
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
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Lịch thi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (!_loadingHocKy && _semesters.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_Semester>(
                        value: _selected,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        iconEnabledColor: const Color(0xFFE65100),
                        icon: const Icon(Icons.expand_more_rounded, size: 20),
                        isDense: true,
                        style: const TextStyle(color: Color(0xFF333333), fontSize: 13, fontWeight: FontWeight.w500),
                        selectedItemBuilder: (_) => _semesters.map((s) => Center(
                          child: Text(s.ten, style: const TextStyle(color: Color(0xFFE65100), fontSize: 13, fontWeight: FontWeight.w600)),
                        )).toList(),
                        items: _semesters.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.ten),
                        )).toList(),
                        onChanged: (s) { if (s != null && s.id != _selected?.id) _fetchExams(s); },
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
                            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _retry,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE65100)),
                              child: const Text('Thử lại',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _loadingExams
                        ? skeletonList()
                        : _exams.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.event_busy, size: 64, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('Không có lịch thi',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  if (_selected != null) await _fetchExams(_selected!);
                                },
                                color: const Color(0xFFE65100),
                                child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                itemCount: _exams.length,
                                itemBuilder: (ctx, i) => _ExamCard(data: _exams[i]),
                              ),
                            ),
          ),
        ],
      )),
    );
  }
}

// ── Exam Card ─────────────────────────────────────────────
class _ExamCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ExamCard({required this.data});

  @override
  State<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<_ExamCard> {
  bool _expanded = false;

  String _formatDate(String? raw) {
    if (raw == null || raw.length < 10) return raw ?? '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return raw.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final tenMon = d['_tenMon']?.toString() ?? '';
    final maLop = d['_maLop']?.toString() ?? '';
    final displayName = tenMon.isNotEmpty ? tenMon : (d['maNhom']?.toString() ?? '');
    final loaiThi = d['loaiThi']?.toString() ?? '';
    final ngayThi = _formatDate(d['ngayThi'] as String?);
    final gioBatDau = d['gioBatDau']?.toString() ?? '';
    final thoiGian = d['thoiGian'] as int? ?? 0;
    final siSo = d['siSo'] as int? ?? 0;
    final hinhThuc = d['hinhThuc']?.toString() ?? '';
    final cb1 = d['canBoCoiThi1']?.toString().trim() ?? '';
    final cb2 = d['canBoCoiThi2']?.toString().trim() ?? '';
    final ghiChu = d['ghiChu']?.toString().trim() ?? '';

    final loaiColor = loaiThi.contains('Giữa')
        ? const Color(0xFF2196F3)
        : const Color(0xFFE65100);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            // ── Summary row ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: loaiColor,
                      borderRadius:
                          const BorderRadius.horizontal(left: Radius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(displayName,
                                        style: const TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.bold)),
                                    if (maLop.isNotEmpty)
                                      Text(maLop,
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.grey),
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (loaiThi.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: loaiColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(loaiThi,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: loaiColor)),
                                ),
                              const SizedBox(width: 6),
                              Icon(
                                _expanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 13, color: Color(0xFFE65100)),
                              const SizedBox(width: 4),
                              Text(ngayThi,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              if (gioBatDau.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.access_time,
                                    size: 13, color: Color(0xFFE65100)),
                                const SizedBox(width: 4),
                                Text(gioBatDau,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                              if (thoiGian > 0) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.timer_outlined,
                                    size: 13, color: Color(0xFFE65100)),
                                const SizedBox(width: 4),
                                Text('$thoiGian phút',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded detail ──
            if (_expanded) ...[
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: [
                    if (siSo > 0)
                      _DetailRow(icon: Icons.people_outline,
                          label: 'Sĩ số', value: '$siSo sinh viên'),
                    if (hinhThuc.isNotEmpty)
                      _DetailRow(icon: Icons.description_outlined,
                          label: 'Hình thức', value: hinhThuc),
                    if (cb1.isNotEmpty)
                      _DetailRow(icon: Icons.person_outline,
                          label: 'CB coi thi 1', value: cb1),
                    if (cb2.isNotEmpty)
                      _DetailRow(icon: Icons.person_outline,
                          label: 'CB coi thi 2', value: cb2),
                    if (ghiChu.isNotEmpty)
                      _DetailRow(icon: Icons.notes,
                          label: 'Ghi chú', value: ghiChu),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE65100)),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

