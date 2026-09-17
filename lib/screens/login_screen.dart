import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../models/hoc_vien_model.dart';
import '../models/giang_vien_model.dart';
import '../services/api_service.dart';
import '../services/ems_api_service.dart';
import '../services/app_session.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _useridCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _useridCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final userid = _useridCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (userid.isEmpty || pass.isEmpty) {
      _showError('Vui lòng nhập tài khoản và mật khẩu.');
      return;
    }

    setState(() => _loading = true);

    try {
      final data = await ApiService.login(userid, pass);

      AppSession.instance.token = data['token'] as String? ?? '';
      // A successful IMS login is a fresh identity attempt. Never carry an EMS
      // denial or token from a previous user/session into this one.
      AppSession.instance.emsToken = null;
      AppSession.instance.emsDenied = false;
      final userMap = data['user'] as Map<String, dynamic>?;
      AppSession.instance.userid = userMap?['userid'] as String?;

      final hocVienMap = userMap?['hocVien'] as Map<String, dynamic>?;
      final giangVienMap = userMap?['giangVien'] as Map<String, dynamic>?;

      if (hocVienMap != null) {
        AppSession.instance.hocVien = HocVien.fromJson(hocVienMap);
        AppSession.instance.giangVien = null;
      } else if (giangVienMap != null) {
        AppSession.instance.giangVien = GiangVien.fromJson(giangVienMap);
        AppSession.instance.hocVien = null;
      }

      await AppSession.instance.persist();

      // Đăng ký FCM token cho cả Sinh viên và Giảng viên vào Firebase
      final gv = AppSession.instance.giangVien;
      final hv = AppSession.instance.hocVien;
      if (gv != null) {
        NotificationService.instance.registerToken(
          'gv_${gv.id}',
          mssv: gv.ma,
          hoTen: gv.ten,
          userid: AppSession.instance.userid,
        );
      } else if (hv != null) {
        NotificationService.instance.registerToken(
          'hv_${hv.id}',
          mssv: hv.mshv,
          hoTen: hv.fullName,
          ngaysinh: hv.ngaysinh,
          userid: AppSession.instance.userid,
        );
      }

      // Finish the EMS mirror before entering the app. Other IMS features may
      // still be used when EMS is unavailable, but attendance can no longer
      // race this request and silently open the legacy writer.
      await AppSession.instance.refreshEmsToken(force: true);

      if (!mounted) return;
      final route = AppSession.instance.isGiangVien ? '/gv_home' : '/home';
      Navigator.pushReplacementNamed(context, route);
    } on ApiException catch (e) {
      _showError(await _explainStudentRefusal(userid, pass, e.message));
    } catch (e) {
      _showError('Đã có lỗi xảy ra. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// IMS nói "sai mật khẩu" cho một MSSV. Hỏi EMS cùng cặp mssv/mật khẩu:
  /// nếu EMS nhận thì lỗi nằm ở mật khẩu IMS đã bị đổi, và app nói rõ cách
  /// xử lý thay vì để học viên đoán. Không bao giờ làm nặng thêm lỗi gốc.
  Future<String> _explainStudentRefusal(
    String userid,
    String pass,
    String imsMessage,
  ) async {
    final looksLikeMssv = RegExp(r'^\d{10}$').hasMatch(userid);
    if (!looksLikeMssv || imsMessage.startsWith('Lỗi kết nối')) {
      return imsMessage;
    }
    try {
      final emsOk = await EmsApiService.studentLoginProbe(userid, pass);
      if (emsOk) {
        return 'Mật khẩu này đúng trên EMS nhưng IMS đã đổi mật khẩu của bạn '
            '(không còn là MSSV). Hãy dùng mật khẩu IMS đã đổi, hoặc nhờ '
            'Phòng Đào tạo đặt lại mật khẩu IMS về MSSV.';
      }
    } catch (_) {
      // EMS không tới được — giữ nguyên câu trả lời của IMS.
    }
    return imsMessage;
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Đăng nhập thất bại',
                style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Thử lại',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Logo ──
              Container(
                width: 200,
                height: 150,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/logo2.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Tài khoản ──
              SizedBox(
                height: 48,
                child: TextField(
                  controller: _useridCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.orange[50],
                    labelText: 'Tài khoản',
                    labelStyle: const TextStyle(color: Colors.orange),
                    prefixIcon:
                        const Icon(Icons.person, color: Colors.orange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Mật khẩu ──
              SizedBox(
                height: 48,
                child: TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  enabled: !_loading,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.orange[50],
                    labelText: 'Mật khẩu',
                    labelStyle: const TextStyle(color: Colors.orange),
                    prefixIcon:
                        const Icon(Icons.lock, color: Colors.orange),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.orange,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Nút đăng nhập ──
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    disabledBackgroundColor: Colors.orange.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Đăng nhập',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),

              // Cửa chạy thử CHỈ Ở BẢN DEBUG: mở thẳng màn hình điểm danh giáo
              // viên bằng token EMS nạp qua --dart-define=EMS_DEBUG_TOKEN, để
              // kiểm tra luồng giáo viên mà không cần đăng nhập IMS. Bản release
              // (kDebugMode = false) cắt bỏ hoàn toàn nút này.
              if (kDebugMode && AppSession.instance.emsToken != null &&
                  AppSession.instance.emsToken!.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/ems_attendance_gv'),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('DEBUG · Điểm danh giáo viên'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE65100),
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
