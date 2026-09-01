import 'dart:async';

import 'package:flutter/material.dart';
import '../services/app_session.dart';
import '../services/notification_service.dart';

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
    final restored = await AppSession.instance.tryRestore();
    if (!mounted) return;
    if (restored && AppSession.instance.token != null) {
      // Đăng ký lại token cho session cũ (app update / token refresh)
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

      // Phiên cũ có thể chưa từng có token EMS (bản app trước tính năng này)
      // hoặc token đã hết hạn. Đối chiếu lại ở nền — không chặn vào home.
      if (!AppSession.instance.hasEms) {
        unawaited(AppSession.instance.refreshEmsToken());
      }

      final route = AppSession.instance.isGiangVien ? '/gv_home' : '/home';
      Navigator.pushReplacementNamed(context, route);

      // Nếu app được mở bằng cách bấm vào notification (app đã tắt hẳn),
      // vào thẳng màn hình thông báo — sau khi đã vào home để nút back còn hoạt động
      // Chờ tối đa 2s để biết app có được mở từ notification hay không.
      // Có timeout để dù FCM lỗi thì app vẫn vào home bình thường.
      await NotificationService.instance.initialMessageReady
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      if (!mounted) return;

      if (NotificationService.instance.consumePendingInitialMessage()) {
        Navigator.pushNamed(context, '/notifications');
      }
    } else {
      // Chưa đăng nhập thì bỏ qua notification đang chờ, tránh mở
      // màn hình thông báo khi không có session
      NotificationService.instance.consumePendingInitialMessage();
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
