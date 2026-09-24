// lib/services/crm_session_guard.dart — one trivial helper shared by any
// screen that calls the CRM directly: on a 401 the session is dead (no IMS
// token left to fall back on, see AppSession.refreshEmsToken's doc comment),
// so clear it and send the user back to '/login'.
//
// Kept deliberately tiny. Bot A2 may add an identical file for the teacher
// screens — if so, this is the copy the student screens (lib/screens/
// hv_home_screen.dart, schedule_screen.dart, classes_screen.dart,
// grades_screen.dart, exam_screen.dart, hv_profile_info_screen.dart,
// student_board_screen.dart, ems_attendance_student_screen.dart) use.
import 'package:flutter/material.dart';
import 'app_session.dart';
import 'ems_api_service.dart';

/// Nếu [error] là một phiên EMS đã hết hạn (401), xoá session và điều hướng
/// về '/login'. Trả về `true` khi đã xử lý (nơi gọi không cần báo lỗi thêm).
Future<bool> handleCrmSessionExpired(BuildContext context, Object error) async {
  if (error is! EmsException || error.statusCode != 401) return false;
  await AppSession.instance.clear();
  if (!context.mounted) return true;
  Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  return true;
}
