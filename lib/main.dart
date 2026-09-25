import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/app_session.dart';
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
import 'screens/ems_attendance_teacher_screen.dart';
import 'screens/ems_attendance_student_screen.dart';
import 'screens/profile_edit_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase phải xong trước khi dùng FCM, nhưng không được để lỗi mạng
  // làm app trắng màn hình — nếu lỗi thì vẫn chạy app, chỉ mất notification
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase] init failed: $e');
  }
  // Phiên chạy thử: token EMS nạp thẳng lúc build, không phải dán tay.
  //
  // Dán tay qua ô nhập là nguồn của mọi rắc rối trong buổi thử đầu: clipboard
  // của máy giả lập đồng bộ với clipboard của máy Mac nên bị ghi đè, và ô nhập
  // giữ focus khi rời màn hình gây crash. Nạp bằng --dart-define thì không có
  // gì để dán, không có ô nhập, không có gì hỏng.
  //
  // kDebugMode là hằng số biên dịch: ở bản release nhánh này bị cắt bỏ hoàn
  // toàn, và giá trị --dart-define cũng không được truyền vào bản phát hành.
  if (kDebugMode) {
    const baked = String.fromEnvironment('EMS_DEBUG_TOKEN');
    if (baked.isNotEmpty) {
      AppSession.instance.emsToken = baked;
      AppSession.instance.emsDenied = false;
      debugPrint('[EMS] phiên chạy thử: đã nạp token từ --dart-define');
    }
  }

  setNotificationNavigatorKey(navigatorKey);
  NotificationService.instance.configureEmsStudentDevice(
    register: AppSession.instance.registerStudentDeviceToken,
    revoke: AppSession.instance.revokeStudentDeviceToken,
  );
  NotificationService.instance.configureEmsTeacherDevice(
    register: AppSession.instance.registerTeacherDeviceToken,
    revoke: AppSession.instance.revokeTeacherDeviceToken,
  );

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
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
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
        // Danh sách thông báo CRM — CHỈ giảng viên (xem
        // `notifications_screen.dart`). Học viên dùng '/student_board'.
        '/notifications': (context) => const NotificationsScreen(),
        // Bảng tin — thông tin từ EMS, đọc trực tiếp (kéo/pull), không qua
        // chuông đẩy (push) nào.
        '/student_board': (context) => const StudentBoardScreen(),
        // Điểm danh EMS — EMS là nguồn dữ liệu điểm danh chính thức.
        '/ems_attendance_gv': (context) => const EmsAttendanceTeacherScreen(),
        '/ems_attendance_hv': (context) => const EmsAttendanceStudentScreen(),
        '/profile_edit': (context) => const ProfileEditScreen(),
      },
    );
  }
}
