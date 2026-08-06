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
      if (gv != null) {
        NotificationService.instance.registerToken(
          'gv_${gv.id}',
          mssv: gv.ma,
          hoTen: gv.ten,
          userid: AppSession.instance.userid,
        );
      }

      final route = AppSession.instance.isGiangVien ? '/gv_home' : '/home';
      Navigator.pushReplacementNamed(context, route);
    } else {
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
