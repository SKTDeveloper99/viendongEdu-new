import 'package:flutter/material.dart';
import '../models/crm_teacher_profile.dart';

/// Chỉ hiển thị — CHỈ ĐỌC. Sửa thông tin cá nhân là việc của một đợt khác
/// (TODO(A4)); màn hình này không có nút sửa nên không cần liên kết gì thêm.
///
/// [profile] đến từ `GET /api/teacher/me/overview` (CRM, xem
/// `CrmTeacherApi.overview`) — có thể null khi lần gọi đó chưa xong hoặc lỗi;
/// khi đó dùng [fallbackName]/[teacherCode] đã có sẵn trong phiên đăng nhập
/// (không cần mạng, xem `AppSession`).
///
/// `teachers` của CRM không có cột ngày sinh — IMS `GiangVien.ngaysinh` KHÔNG
/// có tương đương. Hàng "Ngày sinh" bị bỏ thay vì bịa dữ liệu (xem
/// `docs/ims_to_crm_teacher_map.md`).
class GvProfileInfoScreen extends StatelessWidget {
  final CrmTeacherProfile? profile;
  final String fallbackName;
  final String teacherCode;

  const GvProfileInfoScreen({
    super.key,
    required this.profile,
    required this.fallbackName,
    required this.teacherCode,
  });

  @override
  Widget build(BuildContext context) {
    final name = (profile?.name.isNotEmpty ?? false)
        ? profile!.name
        : (fallbackName.isNotEmpty ? fallbackName : '–');
    final code = (profile?.teacherCode?.isNotEmpty ?? false)
        ? profile!.teacherCode!
        : (teacherCode.isNotEmpty ? teacherCode : '–');
    final phone = profile?.phone;
    final email = profile?.email;

    return Scaffold(
      backgroundColor: Colors.white,
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
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(24)),
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _Section(title: 'Thông tin cơ bản', children: [
                    _InfoRow(icon: Icons.person_outline, label: 'Họ tên', value: name),
                    _InfoRow(icon: Icons.badge_outlined, label: 'Mã GV', value: code),
                    if (profile?.isCoHuu == true)
                      const _InfoRow(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Cơ hữu',
                        value: 'Có',
                      ),
                  ]),
                  const SizedBox(height: 12),
                  _Section(title: 'Liên hệ', children: [
                    _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Số điện thoại',
                        value: (phone?.isNotEmpty ?? false) ? phone! : '–'),
                    _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: (email?.isNotEmpty ?? false) ? email! : '–'),
                  ]),
                ],
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
            border: Border.all(color: Colors.grey[200]!, width: 1),
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
