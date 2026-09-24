import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode, TargetPlatform;
import 'package:flutter/material.dart';
import '../models/crm_identity.dart';
import '../services/ems_api_service.dart';
import '../services/app_session.dart';
import '../services/notification_service.dart';
import 'change_password_screen.dart';

/// Đăng nhập CHỈ qua CRM (EMS) kể từ 6.1.0 — không còn đăng nhập IMS, không
/// còn đối chiếu token. Học viên: MSSV + mật khẩu (mặc định = MSSV). Giảng
/// viên: mã giáo viên + mật khẩu (mặc định = mã giáo viên).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  CrmRole _role = CrmRole.student;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String get _idLabel =>
      _role == CrmRole.student ? 'Mã số sinh viên (MSSV)' : 'Mã giáo viên';

  Future<void> _login() async {
    final loginId = _idCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (loginId.isEmpty || pass.isEmpty) {
      _showError('Vui lòng nhập tài khoản và mật khẩu.');
      return;
    }

    setState(() => _loading = true);

    try {
      final CrmIdentity identity;
      if (_role == CrmRole.student) {
        identity = await EmsApiService.studentLogin(loginId, pass);
      } else {
        // Giảng viên: FCM token đi kèm ngay trong body đăng nhập — không có
        // lượt đăng ký thiết bị riêng như học viên.
        String? fcmToken;
        try {
          fcmToken = await NotificationService.instance.getToken();
        } catch (_) {
          // Không lấy được FCM token không được chặn đăng nhập.
        }
        identity = await EmsApiService.teacherLogin(
          loginId,
          pass,
          fcmToken: fcmToken,
          platform: defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'web',
        );
      }

      AppSession.instance.applyIdentity(identity);
      await AppSession.instance.persist();

      // Đăng ký kênh thông báo cũ (vercel) song song — không phải IMS, giữ
      // nguyên cho tới khi có quyết định thay nó. Một sự cố Firebase/mạng ở
      // đây không được phép chặn đăng nhập (cùng nguyên tắc với
      // AppSession._refreshEmsTokenOnce trước đây).
      try {
        NotificationService.instance.registerToken(
          identity.notificationId,
          mssv: identity.loginId,
          hoTen: identity.fullName,
        );
      } catch (_) {}

      if (identity.isStudent) {
        // Đăng ký thiết bị EMS cho học viên (giảng viên đã gửi trong lúc
        // đăng nhập ở trên).
        try {
          final fcmToken = await NotificationService.instance.getToken();
          if (fcmToken != null) {
            await AppSession.instance.registerStudentDeviceToken(fcmToken);
          }
        } catch (_) {}
      }

      if (!mounted) return;

      if (identity.mustChangePassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ChangePasswordScreen(forced: true),
          ),
        );
        return;
      }

      final route = identity.isTeacher ? '/gv_home' : '/home';
      Navigator.pushReplacementNamed(context, route);
    } on EmsException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Đã có lỗi xảy ra. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            Text('Đăng nhập thất bại', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Thử lại',
              style: TextStyle(color: Colors.orange),
            ),
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

              // ── Vai trò: Sinh viên / Giảng viên ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _RoleTab(
                        label: 'Sinh viên',
                        selected: _role == CrmRole.student,
                        enabled: !_loading,
                        onTap: () => setState(() => _role = CrmRole.student),
                      ),
                    ),
                    Expanded(
                      child: _RoleTab(
                        label: 'Giảng viên',
                        selected: _role == CrmRole.teacher,
                        enabled: !_loading,
                        onTap: () => setState(() => _role = CrmRole.teacher),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Tài khoản ──
              SizedBox(
                height: 48,
                child: TextField(
                  key: ValueKey(_role),
                  controller: _idCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.orange[50],
                    labelText: _idLabel,
                    labelStyle: const TextStyle(color: Colors.orange),
                    prefixIcon: const Icon(Icons.person, color: Colors.orange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
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
                    prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.orange,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
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
                    disabledBackgroundColor: Colors.orange.withValues(
                      alpha: 0.6,
                    ),
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
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              // Cửa chạy thử CHỈ Ở BẢN DEBUG: mở thẳng màn hình điểm danh giáo
              // viên bằng token EMS đã đăng nhập, để kiểm tra luồng giáo viên
              // mà không cần rời trang. Bản release (kDebugMode = false) cắt
              // bỏ hoàn toàn nút này.
              if (kDebugMode &&
                  AppSession.instance.emsToken != null &&
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

class _RoleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RoleTab({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.orange,
          ),
        ),
      ),
    );
  }
}
