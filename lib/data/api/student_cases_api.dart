import '../../services/ems_api_service.dart';

abstract final class StudentCasesApi {
  /// Cases assigned to the signed-in teacher. EMS decides visibility and
  /// whether a submitted answer needs approval.
  static Future<List<TeacherStudentCase>> myOpenStudentCases() async {
    final body = await EmsApiService.sendMap('GET', '/student-cases/my-open');
    final rows = EmsApiService.rows(body['cases']);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => EmsApiService.parse(() => TeacherStudentCase.fromJson(row)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<TeacherCaseAnswer> answerStudentCase(
    String caseId,
    String answer,
  ) async {
    final body = await EmsApiService.sendMap(
      'POST',
      '/student-cases/my-open/${Uri.encodeComponent(caseId)}/answer',
      body: {'answer': answer.trim()},
    );
    return EmsApiService.parse(() => TeacherCaseAnswer.fromJson(body));
  }
}
