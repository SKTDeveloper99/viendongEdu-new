import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/hv_home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/exam_screen.dart';
import 'screens/tuition_screen.dart';
import 'screens/grades_screen.dart';
import 'screens/classes_screen.dart';
import 'screens/lephi_screen.dart';
import 'screens/gv_home_screen.dart';
import 'screens/gv_schedule_screen.dart';
import 'screens/gv_lophoc_screen.dart';
import 'screens/gv_lichthi_screen.dart';
import 'screens/gv_quanly_lop_screen.dart';
import 'screens/capbu_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/student_board_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase phải xong trước khi dùng FCM, nhưng không được để lỗi mạng
  // làm app trắng màn hình — nếu lỗi thì vẫn chạy app, chỉ mất notification
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('[Firebase] init failed: $e');
  }
  setNotificationNavigatorKey(navigatorKey);

  // Vẽ giao diện TRƯỚC. Không await notification init ở đây:
  // requestPermission chờ người dùng bấm nút, sẽ treo màn hình trắng.
  runApp(const MyApp());

  unawaited(NotificationService.instance.init());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ViendongEdu',
      theme: ThemeData(primarySwatch: Colors.orange),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('vi', 'VN'),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/schedule': (context) => const ScheduleScreen(),
        '/exam': (context) => const ExamScreen(),
        '/tuition': (context) => const TuitionScreen(),
        '/grades': (context) => const GradesScreen(),
        '/classes': (context) => const ClassesScreen(),
        '/lephi': (context) => const LePhiScreen(),
        '/gv_home': (context) => const GvHomeScreen(),
        '/gv_schedule': (context) => const GvScheduleScreen(),
        '/gv_lophoc': (context) => const GvLopHocScreen(),
        '/gv_lichthi': (context) => const GvLichThiScreen(),
        '/gv_quanly_lop': (context) => const GvQuanLyLopScreen(),
        '/capbu': (context) => const CapBuScreen(),
        '/change_password': (context) => const ChangePasswordScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        // Bảng tin — thông tin từ EMS. Tách hẳn khỏi chuông thông báo Vercel
        // ở trên: đây là một mặt kéo (pull) riêng, không thay thế chuông.
        '/student_board': (context) => const StudentBoardScreen(),
      },
    );
  }
}