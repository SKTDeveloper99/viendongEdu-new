import '../../services/ems_api_service.dart';

abstract final class StudentCasesApi {
  /// Cases assigned to the signed-in teacher. EMS decides visibility and
  /// whether a submitted answer needs approval.
  static Future<List<TeacherStudentCase>> myOpenStudentCases() async {
    final body = await EmsApiService.sendMap('GET', '/student-cases/my-open');
    final rows = body['cases'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(TeacherStudentCase.fromJson)
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
    return TeacherCaseAnswer.fromJson(body);
  }
}
