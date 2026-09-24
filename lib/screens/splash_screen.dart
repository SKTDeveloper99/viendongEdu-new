import 'package:flutter/material.dart';
import '../services/app_session.dart';
import '../services/app_update_gate.dart';
import '../services/notification_service.dart';
import 'change_password_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Cổng bắt buộc cập nhật chạy TRƯỚC mọi thứ: bản quá cũ dừng ở đây.
    if (!await AppUpdateGate.check(context)) return;
    if (!mounted) return;
    final restored = await AppSession.instance.tryRestore();
    if (!mounted) return;
    // Đăng nhập hợp lệ = có danh tính CRM (xem AppSession.isLoggedIn). Một
    // token IMS mồ côi từ một bản cài đặt cũ không còn đưa được vào app.
    if (restored && AppSession.instance.isLoggedIn) {
      final identity = AppSession.instance.identity!;
      // Đăng ký lại kênh thông báo cũ (vercel) cho session cũ. Một sự cố
      // Firebase/mạng ở đây không được chặn việc vào app.
      try {
        NotificationService.instance.registerToken(
          identity.notificationId,
          mssv: identity.loginId,
          hoTen: identity.fullName,
        );
      } catch (_) {}

      if (AppSession.instance.mustChangePassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ChangePasswordScreen(forced: true),
          ),
        );
        return;
      }

      final route = AppSession.instance.isGiangVien ? '/gv_home' : '/home';
      Navigator.pushReplacementNamed(context, route);

      // Nếu app được mở bằng cách bấm vào notification (app đã tắt hẳn),
      // vào thẳng màn hình thông báo — sau khi đã vào home để nút back còn hoạt động
      // Chờ tối đa 2s để biết app có được mở từ notification hay không.
      // Có timeout để dù FCM lỗi thì app vẫn vào home bình thường.
      await NotificationService.instance.initialMessageReady.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      if (!mounted) return;

      final notificationRoute = NotificationService.instance
          .consumePendingInitialMessageRoute();
      if (notificationRoute != null) {
        Navigator.pushNamed(context, notificationRoute);
      }
    } else {
      // Chưa đăng nhập thì bỏ qua notification đang chờ, tránh mở
      // màn hình thông báo khi không có session
      NotificationService.instance.consumePendingInitialMessageRoute();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 180, fit: BoxFit.contain),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.orange,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
