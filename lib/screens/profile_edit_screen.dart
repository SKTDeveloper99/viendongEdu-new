import 'package:flutter/material.dart';
import '../models/crm_identity.dart';
import '../services/app_session.dart';
import '../services/crm_profile_api.dart';
import '../services/crm_session_guard.dart';

// Kiểm định NHẸ phía app — chỉ để chặn lỗi rõ ràng trước khi gửi; thông điệp
// lỗi thật (server trả về, `lib/contact-validators.js`) LUÔN được hiện
// nguyên văn, không tự diễn giải lại.
final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _phoneRe = RegExp(r'^(0\d{9,10}|\+84\d{9,10})$');
final RegExp _cccdRe = RegExp(r'^(\d{9}|\d{12})$');

/// Màn hình sửa hồ sơ dùng chung cho học viên và giảng viên — đọc
/// [AppSession.instance.role] để quyết định gọi API/hiển thị trường nào.
///
/// Học viên: PATCH /api/student/me/profile {email, sdt, cmnd}.
/// Giảng viên: PATCH /api/teacher/me/profile {email, sdt}.
///
/// KHÔNG được gọi từ nơi khác trong app bản này — `hv_profile_info_screen`/
/// `gv_profile_info_screen` do bot khác giữ; điểm vào là
/// `ProfileEditScreen()`, master sẽ nối nút ở lượt gộp.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cccdCtrl = TextEditingController();

  bool get _isTeacher => AppSession.instance.role == CrmRole.teacher;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// Đã lưu thành công ít nhất một lần — trả về khi pop để màn hình gọi
  /// (hv/gv_profile_info_screen) biết cần tải lại hồ sơ.
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cccdCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isTeacher) {
        final p = await CrmProfileApi.getTeacherMe();
        _emailCtrl.text = p.email ?? '';
        _phoneCtrl.text = p.phone ?? '';
      } else {
        final p = await CrmProfileApi.getStudentMe();
        _emailCtrl.text = p.email ?? '';
        _phoneCtrl.text = p.phone ?? '';
        // cmnd/cccd không có ở GET /api/student/me hiện tại — để trống,
        // không phải lỗi (xem CrmStudentProfile.fromGetMeJson).
        _cccdCtrl.text = p.cmnd ?? '';
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _error = null; });
    try {
      final email = _emailCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      if (_isTeacher) {
        final res = await CrmProfileApi.updateTeacherProfile(
          email: email.isEmpty ? null : email,
          sdt: phone.isEmpty ? null : phone,
        );
        if (!mounted) return;
        _emailCtrl.text = res.email ?? email;
        _phoneCtrl.text = res.phone ?? phone;
      } else {
        final cccd = _cccdCtrl.text.trim();
        final res = await CrmProfileApi.updateStudentProfile(
          email: email.isEmpty ? null : email,
          sdt: phone.isEmpty ? null : phone,
          cmnd: cccd.isEmpty ? null : cccd,
        );
        if (!mounted) return;
        _emailCtrl.text = res.email ?? email;
        _phoneCtrl.text = res.phone ?? phone;
        _cccdCtrl.text = res.cmnd ?? cccd;
      }
      if (!mounted) return;
      setState(() { _saving = false; _saved = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Đã cập nhật hồ sơ ở EMS. Thay đổi CHƯA được gửi tới hệ thống IMS của trường.',
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (!mounted) return;
      setState(() => _saving = false);
      // Hiện nguyên văn thông điệp lỗi validate/máy chủ.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // canPop: false + tự pop trong onPopInvokedWithResult để back bằng cử chỉ
    // hệ thống (Android/iOS) cũng mang theo [_saved], giống hệt nút back thủ
    // công bên dưới — nơi gọi (hv/gv_profile_info_screen) chỉ tải lại hồ sơ
    // khi kết quả pop là true.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _saved);
      },
      child: Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(top: false, child: Column(
        children: [
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
                  onTap: () => Navigator.pop(context, _saved),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sửa hồ sơ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetch,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                              child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Color(0xFFE65100), size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Thay đổi được ghi vào EMS. Hệ thống quản lý đào tạo (IMS) của trường CHƯA nhận được cập nhật này.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return null;
                                  if (!_emailRe.hasMatch(s)) return 'Email không đúng định dạng.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Số điện thoại',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return null;
                                  if (!_phoneRe.hasMatch(s)) {
                                    return 'Số điện thoại không đúng định dạng (vd. 0912345678).';
                                  }
                                  return null;
                                },
                              ),
                              if (!_isTeacher) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _cccdCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'CMND/CCCD',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return null;
                                    if (!_cccdRe.hasMatch(s)) {
                                      return 'CMND/CCCD phải có 9 hoặc 12 chữ số.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE65100),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                        )
                                      : const Text('Lưu thay đổi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      )),
      ),
    );
  }
}
