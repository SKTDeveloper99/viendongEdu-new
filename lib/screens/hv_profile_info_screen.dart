import 'package:flutter/material.dart';
import '../models/crm_student_profile.dart';
import '../services/crm_student_api.dart';

// READ-ONLY display screen (bot A3 slice). Editing profile fields / changing
// password from this screen belongs to another bot — the edit action below
// deliberately calls nothing new.
// TODO(A4): wire the edit action to the real profile-update endpoint.
class HvProfileInfoScreen extends StatefulWidget {
  const HvProfileInfoScreen({super.key});

  @override
  State<HvProfileInfoScreen> createState() => _HvProfileInfoScreenState();
}

class _HvProfileInfoScreenState extends State<HvProfileInfoScreen> {
  CrmStudentProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // GET /api/student/me — thay `user/info` (`ApiService.getUserInfo`, IMS).
  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await CrmStudentApi.me();
      if (!mounted) return;
      setState(() { _profile = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;

    final fullName = p?.fullName.isNotEmpty == true
        ? p!.fullName
        : '${p?.lastName ?? ''} ${p?.firstName ?? ''}'.trim();
    final mssv = p?.mssv.isNotEmpty == true ? p!.mssv : '–';
    final malop = p?.classCode ?? '–';
    final khoahoc = p?.khoaDisplay ?? '–';
    final ngaysinh = _fmtDate(p?.dateOfBirth);
    final email = p?.email ?? '–';
    final sdt = p?.phone ?? '–';
    // CRM's `students` table has a `cccd` column, but the /api/student/me
    // repo query (repositories/portals-student-portal-repo.js#getStudent)
    // does not select it — the endpoint simply has no CCCD field to hand
    // back. Shown as "—" rather than guessed; documented in
    // docs/ims_to_crm_student_academic_map.md.
    const cmnd = '—';
    // CRM models only ONE ngành level (no separate "chuyên ngành" tier the
    // old IMS hierarchy had) — same gap, documented rather than guessed.
    const chuyenNganhTen = '—';
    final nganhTen = p?.nganhName?.isNotEmpty == true ? p!.nganhName! : '–';
    final heDaoTaoTen = p?.programName?.isNotEmpty == true ? p!.programName! : '–';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
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
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFE65100)))
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
                                onPressed: _fetch,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE65100)),
                                child: const Text('Thử lại',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          color: const Color(0xFFE65100),
                          child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: [
                            _Section(title: 'Thông tin cơ bản', children: [
                              _InfoRow(icon: Icons.person_outline, label: 'Họ tên', value: fullName),
                              _InfoRow(icon: Icons.badge_outlined, label: 'MSSV', value: mssv),
                              _InfoRow(icon: Icons.cake_outlined, label: 'Ngày sinh', value: ngaysinh),
                              _InfoRow(icon: Icons.credit_card_outlined, label: 'CCCD', value: cmnd),
                            ]),
                            const SizedBox(height: 12),
                            _Section(title: 'Liên hệ', children: [
                              _InfoRow(icon: Icons.phone_outlined, label: 'Số điện thoại', value: sdt),
                              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: email),
                            ]),
                            const SizedBox(height: 12),
                            _Section(title: 'Học vụ', children: [
                              _InfoRow(icon: Icons.group_outlined, label: 'Lớp', value: malop),
                              _InfoRow(icon: Icons.school_outlined, label: 'Khóa học', value: khoahoc),
                              _InfoRow(icon: Icons.menu_book_outlined, label: 'Chuyên ngành', value: chuyenNganhTen),
                              _InfoRow(icon: Icons.account_balance_outlined, label: 'Ngành', value: nganhTen),
                              _InfoRow(icon: Icons.workspace_premium_outlined, label: 'Hệ đào tạo', value: heDaoTaoTen),
                            ]),
                          ],
                        ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100))),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(height: 1, indent: 48, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFE65100)),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
