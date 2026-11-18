import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/vd_brand_lockup.dart';
import '../services/app_session.dart';
import '../services/app_update_gate.dart';
import '../services/notification_service.dart';
import 'change_password_screen.dart';
import '../theme/vd_tokens.dart';

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
    // Khôi phục dữ liệu cục bộ song song với yêu cầu mạng để khỏi cộng thêm
    // thời gian chờ vào màn mở đầu trên kết nối yếu.
    final restoreFuture = AppSession.instance.tryRestore();
    if (!await AppUpdateGate.check(context)) return;
    if (!mounted) return;
    final restored = await restoreFuture;
    if (!mounted) return;
    // Đăng nhập hợp lệ = có danh tính CRM (xem AppSession.isLoggedIn). Một
    // token IMS mồ côi từ một bản cài đặt cũ không còn đưa được vào app.
    if (restored && AppSession.instance.isLoggedIn) {
      final identity = AppSession.instance.identity!;
      // Đăng ký lại token FCM lên CRM cho phiên khôi phục — thiết bị/token có
      // thể đã xoay từ lần đăng nhập trước (xem
      // NotificationService._postToken). Một sự cố Firebase/mạng ở đây
      // không được chặn việc vào app.
      if (identity.notificationId.isNotEmpty) {
        try {
          NotificationService.instance.registerToken(
            identity.notificationId,
            mssv: identity.loginId,
            hoTen: identity.fullName,
          );
        } catch (_) {}
      }

      if (AppSession.instance.mustChangePassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ChangePasswordScreen(forced: true),
          ),
        );
        return;
      }

      Navigator.pushReplacementNamed(context, AppSession.instance.homeRoute);

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
    // White in light and dark mode, like the launch screen before it, so the
    // crest never jumps and always stands on white.
    final vd = context.vd;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: vd.brandPaper,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const VdBrandLockup(crestSize: 132, plate: false),
              const SizedBox(height: 40),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: vd.brandInk.withValues(alpha: 0.3),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
