import '../../models/exam_status_models.dart';
import '../../services/ems_api_service.dart';

/// `GET /api/teacher/me/classes/:id/exam-money?view=status`. `view=status`
/// asks the server for statuses only (app-lane ask A2); until it does, the
/// figures it still sends are dropped by [ExamRosterStatus.fromJson].
abstract final class TeacherExamStatusApi {
  static Future<ExamRosterStatus> roster(String sectionId) async {
    final body = await EmsApiService.sendMap(
      'GET',
      '/teacher/me/classes/${Uri.encodeComponent(sectionId)}/exam-money',
      query: const {'view': 'status'},
    );
    if (body['students'] is! List) {
      throw EmsException(
        'Máy chủ trả về danh sách thi không đọc được. Vui lòng thử lại.',
      );
    }
    return EmsApiService.parse(() => ExamRosterStatus.fromJson(body));
  }
}
