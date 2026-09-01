import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hoc_vien_model.dart';
import '../models/giang_vien_model.dart';
import '../services/api_service.dart';
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

      // Đối chiếu sang EMS. CỐ Ý không await-chặn và không bắt lỗi ra ngoài:
      // refreshEmsToken() tự nuốt mọi lỗi, nên EMS hỏng/chậm/từ chối cũng
      // không giữ người dùng lại ở màn hình đăng nhập IMS.
      unawaited(AppSession.instance.refreshEmsToken());

      if (!mounted) return;
      final route = AppSession.instance.isGiangVien ? '/gv_home' : '/home';
      Navigator.pushReplacementNamed(context, route);
    } on ApiException catch (e) {
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
            ],
          ),
        ),
      ),
    );
  }
}
