import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../components/skeleton.dart';

class _Semester {
  final int id;
  final String ten;
  const _Semester({required this.id, required this.ten});
}

class GvQuanLyLopScreen extends StatefulWidget {
  const GvQuanLyLopScreen({super.key});

  @override
  State<GvQuanLyLopScreen> createState() => _GvQuanLyLopScreenState();
}

class _GvQuanLyLopScreenState extends State<GvQuanLyLopScreen> {
  List<_Semester> _semesters = [];
  _Semester? _selected;
  List<Map<String, dynamic>> _lops = [];
  bool _loadingHocKy = true;
  bool _loadingLops = false;
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
      final sems = data
          .map((e) => _Semester(id: e['id'] as int, ten: e['ten'] as String? ?? ''))
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      if (!mounted) return;
      setState(() { _semesters = sems; _loadingHocKy = false; });
      if (sems.isNotEmpty) await _fetchLops(sems.first);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingHocKy = false; _error = e.toString(); });
    }
  }

  Future<void> _fetchLops(_Semester sem) async {
    setState(() { _selected = sem; _loadingLops = true; _error = null; });
    try {
      final data = await ApiService.getGvDanhSachLop(sem.id);
      if (!mounted) return;
      setState(() {
        _lops = data.map((e) => e as Map<String, dynamic>).toList();
        _loadingLops = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingLops = false; _error = e.toString(); });
    }
  }

  void _retry() {
    if (_semesters.isEmpty) {
      _fetchHocKy();
    } else if (_selected != null) {
      _fetchLops(_selected!);
    } else {
      _fetchHocKy();
    }
  }

  void _showDetail(Map<String, dynamic> lop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: _LopDetailSheet(lop: lop),
      ),
    );
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
                    const Expanded(
                      child: Text(
                        'Quản lý lớp',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (!_loadingHocKy && !_loadingLops && _lops.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_lops.length} lớp',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
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
                        onChanged: (s) { if (s != null) _fetchLops(s); },
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
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Colors.grey),
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
                    : _loadingLops
                        ? skeletonList()
                        : _lops.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.manage_accounts_outlined,
                                        size: 64, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('Không có lớp',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                itemCount: _lops.length,
                                itemBuilder: (ctx, i) => _LopCard(
                                  lop: _lops[i],
                                  index: i + 1,
                                  onTap: () => _showDetail(_lops[i]),
                                ),
                              ),
          ),
        ],
      )),
    );
  }
}

// ── Lop Card ─────────────────────────────────────────
class _LopCard extends StatelessWidget {
  final Map<String, dynamic> lop;
  final int index;
  final VoidCallback onTap;
  const _LopCard(
      {required this.lop, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final monHoc = lop['monHoc'] as Map<String, dynamic>? ?? {};
    final ma = lop['ma']?.toString() ?? '';
    final mhten = monHoc['ten']?.toString() ?? '';
    final mhma = monHoc['ma']?.toString() ?? '';
    final sotinchi = monHoc['sotinchi'] as int? ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            // Số thứ tự
            // Container(
            //   width: 44,
            //   alignment: Alignment.center,
            //   padding: const EdgeInsets.symmetric(vertical: 20),
            //   decoration: BoxDecoration(
            //     color: const Color(0xFFE65100).withValues(alpha: 0.08),
            //     borderRadius:
            //         const BorderRadius.horizontal(left: Radius.circular(14)),
            //   ),
            //   child: Text(
            //     '$index',
            //     style: const TextStyle(
            //         fontSize: 15,
            //         fontWeight: FontWeight.bold,
            //         color: Color(0xFFE65100)),
            //   ),
            // ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mã - Tên
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                        children: [
                          TextSpan(
                            text: mhma,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE65100)),
                          ),
                          const TextSpan(text: ' · '),
                          TextSpan(
                            text: mhten,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ma,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF444444)),
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),
                    // Footer: tín chỉ + trạng thái
                    Row(
                      children: [
                        if (sotinchi > 0) ...[
                          const Icon(Icons.school_outlined,
                              size: 13, color: Color(0xFF555555)),
                          const SizedBox(width: 4),
                          Text('$sotinchi tín chỉ',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF555555))),
                          const SizedBox(width: 12),
                        ],
                        // Container(
                        //   padding: const EdgeInsets.symmetric(
                        //       horizontal: 8, vertical: 2),
                        //   decoration: BoxDecoration(
                        //     color: moLop
                        //         ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                        //         : Colors.grey.withValues(alpha: 0.12),
                        //     borderRadius: BorderRadius.circular(20),
                        //   ),
                        //   child: Text(
                        //     moLop ? 'Đang mở' : 'Đã đóng',
                        //     style: TextStyle(
                        //       fontSize: 11,
                        //       fontWeight: FontWeight.w600,
                        //       color: moLop
                        //           ? const Color(0xFF4CAF50)
                        //           : Colors.grey,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right,
                  color: Colors.grey, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail Bottom Sheet ───────────────────────────────
class _LopDetailSheet extends StatefulWidget {
  final Map<String, dynamic> lop;
  const _LopDetailSheet({required this.lop});

  @override
  State<_LopDetailSheet> createState() => _LopDetailSheetState();
}

class _LopDetailSheetState extends State<_LopDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Map<String, dynamic>> _hocViens = [];
  bool _loadingHV = false;
  String? _hvError;

  List<Map<String, dynamic>> _buoiHocs = [];
  List<Map<String, dynamic>> _tongHops = [];
  bool _loadingDD = false;
  String? _ddError;
  int _ddSubTab = 0; // 0 = buổi học, 1 = tổng hợp

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _hocViens.isEmpty && !_loadingHV && _hvError == null) {
        _loadHocViens();
      }
      if (_tabController.index == 2 && _buoiHocs.isEmpty && !_loadingDD && _ddError == null) {
        _loadDiemDanh();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHocViens() async {
    final lopId = widget.lop['id'] as int? ?? 0;
    setState(() { _loadingHV = true; _hvError = null; });
    try {
      final data = await ApiService.getGvDanhSachHocVien(lopId);
      if (mounted) {
        setState(() {
          _hocViens = data.map((e) => e as Map<String, dynamic>).toList();
          _loadingHV = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingHV = false; _hvError = e.toString(); });
    }
  }

  Future<void> _loadDiemDanh() async {
    final lopId = widget.lop['id'] as int? ?? 0;
    setState(() { _loadingDD = true; _ddError = null; });
    try {
      final results = await Future.wait([
        ApiService.getGvDanhSachBuoiHoc(lopId),
        ApiService.getGvDanhSachTongHop(lopId),
      ]);
      if (mounted) {
        setState(() {
          _buoiHocs = results[0].map((e) => e as Map<String, dynamic>).toList();
          _tongHops = results[1].map((e) => e as Map<String, dynamic>).toList();
          _loadingDD = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingDD = false; _ddError = e.toString(); });
    }
  }

  void _showBuoiDetail(Map<String, dynamic> buoi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: _BuoiDetailSheet(buoi: buoi),
      ),
    );
  }

  static String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return iso; }
  }

  static String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.contains('T')) {
      try {
        final dt = DateTime.parse(raw);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final monHoc = widget.lop['monHoc'] as Map<String, dynamic>? ?? {};
    final ma = widget.lop['ma']?.toString() ?? '';
    final mhten = monHoc['ten']?.toString() ?? '';
    final mhma = monHoc['ma']?.toString() ?? '';
    final sotinchi = monHoc['sotinchi'] as int? ?? 0;
    final sotinchilt = monHoc['sotinchilt'] as int? ?? 0;
    final sotinchith = monHoc['sotinchith'] as int? ?? 0;
    final cc = widget.lop['phantramcc'] as int? ?? 0;
    final gk = widget.lop['phantramgk'] as int? ?? 0;
    final ck = widget.lop['phantramck'] as int? ?? 0;
    //final moLop = widget.lop['molopyn'] as bool? ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header: tên môn + badge trạng thái
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mhten,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(mhma,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE65100),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                // Container(
                //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                //   decoration: BoxDecoration(
                //     color: moLop
                //         ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                //         : Colors.grey.withValues(alpha: 0.12),
                //     borderRadius: BorderRadius.circular(20),
                //   ),
                //   child: Text(
                //     moLop ? 'Đang mở' : 'Đã đóng',
                //     style: TextStyle(
                //       fontSize: 12,
                //       fontWeight: FontWeight.w600,
                //       color: moLop ? const Color(0xFF4CAF50) : Colors.grey,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // TabBar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFE65100),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFE65100),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Thông tin'),
              Tab(text: 'Danh sách'),
              Tab(text: 'Điểm danh'),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: Thông tin ──
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    _DetailRow(icon: Icons.class_outlined, label: 'Mã lớp', value: ma),
                    const SizedBox(height: 12),
                    if (sotinchi > 0) ...[
                      _DetailRow(
                        icon: Icons.school_outlined,
                        label: 'Tín chỉ',
                        value: '$sotinchi TC'
                            '${sotinchilt > 0 ? '  (LT: $sotinchilt' : ''}'
                            '${sotinchith > 0 ? ' · TH: $sotinchith' : ''}'
                            '${sotinchilt > 0 ? ')' : ''}',
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.bar_chart, size: 18, color: Color(0xFFE65100)),
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 90,
                          child: Text('Tỷ lệ điểm',
                              style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
                        ),
                        Expanded(child: _ScoreDonut(cc: cc, gk: gk, ck: ck)),
                      ],
                    ),
                  ],
                ),

                // ── Tab 2: Danh sách học viên ──
                _loadingHV
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                    : _hvError != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(_hvError!,
                                    style: const TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _loadHocViens,
                                  child: const Text('Thử lại',
                                      style: TextStyle(color: Color(0xFFE65100))),
                                ),
                              ],
                            ),
                          )
                        : _hocViens.isEmpty
                            ? const Center(
                                child: Text('Không có học viên',
                                    style: TextStyle(color: Colors.grey)),
                              )
                            : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.people_outline,
                                          size: 15, color: Color(0xFFE65100)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Tổng: ${_hocViens.length} sinh viên',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFE65100)),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                itemCount: _hocViens.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1, color: Color(0xFFF5F5F5)),
                                itemBuilder: (_, i) {
                                  final hv = _hocViens[i]['hocVien'] as Map<String, dynamic>? ?? {};
                                  final ho = hv['ho']?.toString() ?? '';
                                  final ten = hv['ten']?.toString() ?? '';
                                  final fullName = '$ho $ten'.trim();
                                  final mshv = hv['mshv']?.toString() ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(0xFFE65100)
                                              .withValues(alpha: 0.1),
                                          child: Text(
                                            '${i + 1}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFE65100)),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(fullName,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 2),
                                              Text(mshv,
                                                  style: const TextStyle(
                                                      fontSize: 12, color: Color(0xFF555555))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                                ),
                              ],
                            ),

                // ── Tab 3: Điểm danh ──
                _loadingDD
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                    : _ddError != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(_ddError!,
                                    style: const TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _loadDiemDanh,
                                  child: const Text('Thử lại',
                                      style: TextStyle(color: Color(0xFFE65100))),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Sub-tab toggle
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      _SubTabBtn(
                                        label: 'Buổi học',
                                        selected: _ddSubTab == 0,
                                        onTap: () => setState(() => _ddSubTab = 0),
                                      ),
                                      _SubTabBtn(
                                        label: 'Tổng hợp',
                                        selected: _ddSubTab == 1,
                                        onTap: () => setState(() => _ddSubTab = 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: _ddSubTab == 0
                                    ? (_buoiHocs.isEmpty
                                        ? const Center(
                                            child: Text('Chưa có buổi điểm danh',
                                                style: TextStyle(color: Colors.grey)),
                                          )
                                        : ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                            itemCount: _buoiHocs.length,
                                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                                            itemBuilder: (_, i) {
                                              final b = _buoiHocs[i];
                                              final ngay = _fmtDate(b['ngay']?.toString());
                                              final tbd = b['thoigianbd']?.toString() ?? '';
                                              final tkt = _fmtTime(b['thoigiankt']?.toString());
                                              final siso = b['siso'] as int? ?? 0;
                                              final hiendien = b['hiendien'] as int? ?? 0;
                                              final daDiemDanh = (b['dadiemdanh'] as int? ?? 0) == 1;
                                              final pct = siso > 0 ? hiendien / siso : 0.0;
                                              return GestureDetector(
                                              onTap: () => _showBuoiDetail(b),
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: const [
                                                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.calendar_today,
                                                                  size: 13, color: Color(0xFFE65100)),
                                                              const SizedBox(width: 5),
                                                              Text(ngay,
                                                                  style: const TextStyle(
                                                                      fontSize: 14,
                                                                      fontWeight: FontWeight.bold)),
                                                              const SizedBox(width: 8),
                                                              Text('$tbd – $tkt',
                                                                  style: const TextStyle(
                                                                      fontSize: 12, color: Color(0xFF555555))),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Row(
                                                            children: [
                                                              Text('$hiendien / $siso hiện diện',
                                                                  style: const TextStyle(
                                                                      fontSize: 13, color: Color(0xFF444444))),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 6),
                                                          ClipRRect(
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: LinearProgressIndicator(
                                                              value: pct,
                                                              minHeight: 5,
                                                              backgroundColor: Colors.grey[200],
                                                              color: pct >= 0.8
                                                                  ? const Color(0xFF4CAF50)
                                                                  : pct >= 0.5
                                                                      ? const Color(0xFFFF9800)
                                                                      : Colors.red,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: daDiemDanh
                                                            ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                                                            : Colors.grey.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        daDiemDanh ? 'Đã ĐD' : 'Chưa ĐD',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: daDiemDanh
                                                              ? const Color(0xFF4CAF50)
                                                              : Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ));
                                            },
                                          ))
                                    : (_tongHops.isEmpty
                                        ? const Center(
                                            child: Text('Chưa có dữ liệu',
                                                style: TextStyle(color: Colors.grey)),
                                          )
                                        : ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                            itemCount: _tongHops.length,
                                            separatorBuilder: (_, _) =>
                                                const Divider(height: 1, color: Color(0xFFF5F5F5)),
                                            itemBuilder: (_, i) {
                                              final t = _tongHops[i];
                                              final ho = t['ho']?.toString() ?? '';
                                              final ten = t['ten']?.toString() ?? '';
                                              final fullName = '$ho $ten'.trim();
                                              final mshv = t['mshv']?.toString() ?? '';
                                              final tongSo = t['tongsobuoi'] as int? ?? 0;
                                              final hiendien = t['sobuoihiendien'] as int? ?? 0;
                                              final pct = tongSo > 0 ? hiendien / tongSo : 0.0;
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 18,
                                                      backgroundColor: const Color(0xFFE65100)
                                                          .withValues(alpha: 0.1),
                                                      child: Text('${i + 1}',
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: Color(0xFFE65100))),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(fullName,
                                                              style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w600)),
                                                          const SizedBox(height: 2),
                                                          Text(mshv,
                                                              style: const TextStyle(
                                                                  fontSize: 12, color: Colors.grey)),
                                                          const SizedBox(height: 4),
                                                          ClipRRect(
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: LinearProgressIndicator(
                                                              value: pct,
                                                              minHeight: 4,
                                                              backgroundColor: Colors.grey[200],
                                                              color: pct >= 0.8
                                                                  ? const Color(0xFF4CAF50)
                                                                  : pct >= 0.5
                                                                      ? const Color(0xFFFF9800)
                                                                      : Colors.red,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text('$hiendien/$tongSo',
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFFE65100))),
                                                  ],
                                                ),
                                              );
                                            },
                                          )),
                              ),
                            ],
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFFE65100)),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              softWrap: true),
        ),
      ],
    );
  }
}

// ── Buổi Detail Sheet ────────────────────────────────
class _BuoiDetailSheet extends StatefulWidget {
  final Map<String, dynamic> buoi;
  const _BuoiDetailSheet({required this.buoi});

  @override
  State<_BuoiDetailSheet> createState() => _BuoiDetailSheetState();
}

class _BuoiDetailSheetState extends State<_BuoiDetailSheet> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = widget.buoi;
    setState(() { _loading = true; _error = null; });
    try {
      final ngayRaw = b['ngay']?.toString() ?? '';
      final ngay = ngayRaw.length >= 10 ? ngayRaw.substring(0, 10) : ngayRaw;
      final tkt = _fmtTime(b['thoigiankt']?.toString());
      final data = await ApiService.postDiemDanhDanhSach(
        tkbid: b['tkbid'].toString(),
        lopid: b['lmhid'].toString(),
        phongid: b['phongid'].toString(),
        ngay: ngay,
        thoigianbd: b['thoigianbd']?.toString() ?? '',
        thoigiankt: tkt,
      );
      if (mounted) {
        setState(() {
          _students = data.map((e) => e as Map<String, dynamic>).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  static String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.contains('T')) {
      try {
        final dt = DateTime.parse(raw);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.buoi;
    final ngay = _LopDetailSheetState._fmtDate(b['ngay']?.toString());
    final tbd = b['thoigianbd']?.toString() ?? '';
    final tkt = _fmtTime(b['thoigiankt']?.toString());
    final siso = b['siso'] as int? ?? 0;

    final present = _students.where((s) {
      final v = s['hiendienyn'];
      return v == true || v == 1;
    }).length;
    final absent = _students.length - present;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ngay,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$tbd – $tkt',
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                if (!_loading && _error == null) ...[
                  _StatPill(label: 'Có mặt', value: present, color: const Color(0xFF4CAF50)),
                  const SizedBox(width: 8),
                  _StatPill(label: 'Vắng', value: absent, color: Colors.red),
                ] else ...[
                  Text('Sĩ số: $siso',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Thử lại',
                                  style: TextStyle(color: Color(0xFFE65100))),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: _students.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFF5F5F5)),
                        itemBuilder: (_, i) {
                          final s = _students[i];
                          final ho = s['ho']?.toString() ?? '';
                          final ten = s['ten']?.toString() ?? '';
                          final fullName = '$ho $ten'.trim();
                          final mshv = s['mshv']?.toString() ?? '';
                          final present = s['hiendienyn'] == true || s['hiendienyn'] == 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: present
                                      ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: present
                                              ? const Color(0xFF4CAF50)
                                              : Colors.red)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(fullName,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(mshv,
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: present
                                        ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                                        : Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    present ? 'Có mặt' : 'Vắng',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: present
                                          ? const Color(0xFF4CAF50)
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 4),
          Text('$value',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _SubTabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SubTabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE65100) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreDonut extends StatelessWidget {
  final int cc, gk, ck;
  const _ScoreDonut({required this.cc, required this.gk, required this.ck});

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[
      if (cc > 0)
        PieChartSectionData(
            value: cc.toDouble(),
            color: const Color(0xFF2196F3),
            title: '',
            radius: 20),
      if (gk > 0)
        PieChartSectionData(
            value: gk.toDouble(),
            color: const Color(0xFFFF9800),
            title: '',
            radius: 20),
      if (ck > 0)
        PieChartSectionData(
            value: ck.toDouble(),
            color: const Color(0xFF9C27B0),
            title: '',
            radius: 20),
    ];
    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
          value: 1, color: Colors.grey[300]!, title: '', radius: 20));
    }

    return Row(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: PieChart(PieChartData(
            sections: sections,
            centerSpaceRadius: 24,
            sectionsSpace: 2,
            startDegreeOffset: -90,
          )),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendItem(color: const Color(0xFF2196F3), label: 'Chuyên cần', value: '$cc%'),
            const SizedBox(height: 5),
            _LegendItem(color: const Color(0xFFFF9800), label: 'Giữa kỳ', value: '$gk%'),
            const SizedBox(height: 5),
            _LegendItem(color: const Color(0xFF9C27B0), label: 'Cuối kỳ', value: '$ck%'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label, value;
  const _LegendItem({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
