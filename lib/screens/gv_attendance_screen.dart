import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/zk_api_service.dart';
import '../utils/snack.dart';

const _notiBase = 'https://noti-backend-eight.vercel.app';

String _vnSort(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[àáảãạăắặằẳẵâấầẩẫậ]'), 'a')
    .replaceAll(RegExp(r'[èéẻẽẹêếềểễệ]'), 'e')
    .replaceAll(RegExp(r'[ìíỉĩị]'), 'i')
    .replaceAll(RegExp(r'[òóỏõọôốồổỗộơớờởỡợ]'), 'o')
    .replaceAll(RegExp(r'[ùúủũụưứừửữự]'), 'u')
    .replaceAll(RegExp(r'[ỳýỷỹỵ]'), 'y')
    .replaceAll(RegExp(r'[đ]'), 'dz');

class GvAttendanceScreen extends StatefulWidget {
  final String subject;
  final String classCode;
  final String ngay;
  final List<dynamic> students;
  final Map<String, dynamic> tkbParams;

  const GvAttendanceScreen({
    super.key,
    required this.subject,
    required this.classCode,
    required this.ngay,
    required this.students,
    required this.tkbParams,
  });

  @override
  State<GvAttendanceScreen> createState() => _GvAttendanceScreenState();
}

class _GvAttendanceScreenState extends State<GvAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<int, bool> _attendance;
  late List<Map<String, dynamic>> _sorted;
  bool _saving = false;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sorted = widget.students.map((s) => s as Map<String, dynamic>).toList()
      ..sort((a, b) {
        final ta = _vnSort('${a['ten'] ?? ''} ${a['ho'] ?? ''}');
        final tb = _vnSort('${b['ten'] ?? ''} ${b['ho'] ?? ''}');
        return ta.compareTo(tb);
      });
    _attendance = {
      for (final s in _sorted)
        s['hocvienid'] as int: s['hiendienyn'] as bool? ?? false,
    };

    // GV bấm nút "Đồng bộ từ máy ZKTeco" để đồng bộ thủ công
    // (Không tự động sync nữa để tránh nút lưu bị xoay liên tục)

  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _present =>
      _sorted.where((s) => _attendance[s['hocvienid'] as int] == true).toList();
  List<Map<String, dynamic>> get _absent =>
      _sorted.where((s) => _attendance[s['hocvienid'] as int] != true).toList();

  void _toggle(int hocvienid) =>
      setState(() => _attendance[hocvienid] = !(_attendance[hocvienid] ?? false));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final hocviens = _sorted.map((m) {
        final id = m['hocvienid'] as int;
        return {
          'hocvienid': id,
          'mshv': m['mshv'] ?? '',
          'ho': m['ho'] ?? '',
          'ten': m['ten'] ?? '',
          'hinhanh': m['hinhanh'],
          'diemdanhid': m['diemdanhid'],
          'hiendienyn': _attendance[id] ?? false,
        };
      }).toList();

      await ApiService.postDiemDanhLuu(
        tkb: widget.tkbParams,
        hocviens: hocviens,
      );

      if (widget.classCode.contains('CD15')) {
        await ApiService.sendSMS(
          subject: widget.tkbParams,
          classData: hocviens,
        );
      }

      if (!mounted) return;
      showSuccessSnack(context, 'Lưu điểm danh thành công');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Gửi push notification cho sinh viên vừa được phát hiện qua ZKTeco
  Future<void> _sendAttendanceNotification(
      List<Map<String, dynamic>> newlyPresentStudents) async {
    if (newlyPresentStudents.isEmpty) return;
    try {
      final subject = widget.subject;
      final ngay = widget.ngay;
      final tokens = newlyPresentStudents
          .map((s) => {'hocVienId': s['hocvienid'].toString()})
          .toList();

      await http
          .post(
            Uri.parse('$_notiBase/api/notifications/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': '✅ Điểm danh thành công',
              'msg': 'Bạn đã được ghi nhận CÓ MẶT buổi học $subject ngày $ngay.',
              'tokens': tokens,
              'data': {
                'type': 'attendance',
                'status': 'present',
                'monhoc': subject,
                'ngay': ngay,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[ZKTeco] Đã gửi noti cho ${newlyPresentStudents.length} sinh viên vừa quét mặt');
    } catch (e) {
      debugPrint('[ZKTeco] Gửi noti lỗi: $e');
    }
  }

  Future<void> _showZkSettings() async {
    final savedIp = await ZkApiService.getSavedIp();
    final ip = savedIp.isEmpty ? '192.168.1.201' : savedIp;
    final ctrl = TextEditingController(text: ip);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cấu hình IP ZKTeco'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'IP máy chủ ZKFaceAPI (ví dụ: 192.168.1.201)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              await ZkApiService.saveIp(ctrl.text.trim());
              if (!c.mounted) return;
              Navigator.pop(c);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncZkFace({bool silent = false}) async {
    final ip = await ZkApiService.getSavedIp();
    if (ip.isEmpty) {
      if (silent) return; // Nếu chạy tự động ngầm thì bỏ qua, không hiện popup
      if (!mounted) return;
      showErrorSnack(context, 'Vui lòng cấu hình IP máy chủ ZKTeco trước!');
      return _showZkSettings();
    }

    setState(() => _saving = true);
    try {
      final logs = await ZkApiService.getLogs(ip);
      final studentsFromZk = await ZkApiService.getStudents(ip);

      // Lọc log theo ngày của lớp học (widget.ngay) hoặc hôm nay
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final todayLogs = logs.where((l) => l['timestamp'].toString().startsWith(todayStr)).toList();

      // 1. Tạo Map PIN -> MSSV & PIN -> Tên từ ZKFaceAPI Database
      final pinToMssv = <String, String>{};
      final pinToName = <String, String>{};

      for (final u in studentsFromZk) {
        final pinStr = u['pin']?.toString().trim() ?? '';
        final mssvStr = u['mssv']?.toString().trim().toLowerCase() ?? '';
        final nameStr = _vnSort(u['name'] ?? '').replaceAll(' ', '');

        if (pinStr.isNotEmpty) {
          if (mssvStr.isNotEmpty) pinToMssv[pinStr] = mssvStr;
          if (nameStr.isNotEmpty) pinToName[pinStr] = nameStr;
        }
      }

      // 2. Thu thập danh sách MSSV và Tên đã quét mặt hôm nay
      final Set<String> presentMssvs = {};
      final Set<String> presentNames = {};

      for (final l in todayLogs) {
        final pin = l['pin']?.toString().trim() ?? '';
        final mssv = pinToMssv[pin];
        final name = pinToName[pin];

        if (mssv != null && mssv.isNotEmpty) presentMssvs.add(mssv);
        if (name != null && name.isNotEmpty) presentNames.add(name);
      }

      // 3. So khớp ƯU TIÊN THEO MSSV (mshv), nếu chưa có MSSV thì so khớp theo Tên
      int matchCount = 0;
      final List<Map<String, dynamic>> newlyMatched = []; // sinh viên mới quét (chưa được điểm danh trước đó)
      setState(() {
        for (final s in _sorted) {
          final mshv = s['mshv']?.toString().trim().toLowerCase() ?? '';
          final ho = s['ho']?.toString() ?? '';
          final ten = s['ten']?.toString() ?? '';
          final fullName = _vnSort('$ho $ten').replaceAll(' ', '');

          bool isMatched = false;

          // Ưu tiên 1: Khớp chính xác theo MSSV
          if (mshv.isNotEmpty && presentMssvs.contains(mshv)) {
            isMatched = true;
          }

          // Ưu tiên 2: Khớp theo Tên (nếu không có hoặc chưa khớp MSSV)
          if (!isMatched && fullName.isNotEmpty) {
            for (final zkName in presentNames) {
              if (zkName.isNotEmpty && (zkName.contains(fullName) || fullName.contains(zkName))) {
                isMatched = true;
                break;
              }
            }
          }

          // Chỉ đánh dấu và gửi noti cho sinh viên CHƯA được điểm danh (mới phát hiện lần này)
          if (isMatched && _attendance[s['hocvienid']] != true) {
            _attendance[s['hocvienid']] = true;
            matchCount++;
            newlyMatched.add(s); // lưu lại để gửi push notification
          }
        }
      });


      if (!mounted) return;
      if (matchCount == 0) {
        if (!silent) {
          if (todayLogs.isEmpty) {
            showErrorSnack(context, 'Chưa có lượt quét nào trong hôm nay (kiểm tra lại giờ trên máy chấm công có đúng ngày $todayStr không).');
          } else {
            final foundCount = presentMssvs.length;
            showErrorSnack(context, 'Có ${todayLogs.length} lượt quét ($foundCount MSSV), nhưng không khớp sinh viên nào trong lớp này.', duration: const Duration(seconds: 5));
          }
        }
      } else {
        showSuccessSnack(context, '🎉 Đã tự động điểm danh $matchCount sinh viên theo MSSV từ máy quét ZKTeco!');
        // Gửi push notification ngay cho sinh viên vừa được phát hiện
        _sendAttendanceNotification(newlyMatched).ignore();
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        showErrorSnack(context, 'Lỗi ZKTeco: $e');
      } else {
        debugPrint('Lỗi ngầm ZKTeco: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = _present;
    final absent = _absent;
    final total = _sorted.length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(20)),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.subject,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.classCode,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _showZkSettings,
                        child: const Icon(Icons.settings, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w400, fontSize: 13),
                    tabs: [
                      Tab(text: 'Danh sách (${present.length} / $total)'),
                      Tab(text: 'Vắng (${absent.length})'),
                    ],
                  ),
                ],
              ),
            ),

            // ── Tab content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _StudentList(
                    students: _sorted,
                    attendance: _attendance,
                    onTap: _toggle,
                  ),
                  _StudentList(
                    students: absent,
                    attendance: _attendance,
                    onTap: _toggle,
                  ),
                ],
              ),
            ),

            // ── Save button ──
            if (_sorted.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _syncZkFace,
                        icon: const Icon(Icons.face_retouching_natural),
                        label: const Text('Đồng bộ từ máy điểm danh FaceID', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE65100),
                          side: const BorderSide(color: Color(0xFFE65100), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, color: Colors.white),
                        label: const Text(
                          'Lưu điểm danh',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
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

// ── Student List ──────────────────────────────────────────
class _StudentList extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  final Map<int, bool> attendance;
  final void Function(int hocvienid) onTap;

  const _StudentList({
    required this.students,
    required this.attendance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Không có sinh viên vắng',
                style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: students.length,
      itemBuilder: (_, i) {
        final s = students[i];
        final id = s['hocvienid'] as int;
        final present = attendance[id] ?? false;
        final ho = s['ho']?.toString() ?? '';
        final ten = s['ten']?.toString() ?? '';
        final name = '$ho $ten'.trim().isEmpty ? '–' : '$ho $ten'.trim();
        final mssv = s['mshv']?.toString() ?? '';
        final color = present
            ? const Color(0xFF4CAF50)
            : const Color(0xFFF44336);

        return GestureDetector(
          onTap: () => onTap(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: present ? const Color(0xFFE8F5E9) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: present
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFEEEEEE),
                width: present ? 1.5 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      if (mssv.isNotEmpty)
                        Text(mssv,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(
                  present
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: present
                      ? const Color(0xFF4CAF50)
                      : Colors.grey[400],
                  size: 26,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

