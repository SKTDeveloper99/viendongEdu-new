class TeacherStudentCase {
  final String id;
  final String studentMssv;
  final String studentName;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String relation;
  final DateTime? dueAt;
  final String? latestAnswer;

  const TeacherStudentCase({
    required this.id,
    required this.studentMssv,
    required this.studentName,
    required this.title,
    required this.status,
    required this.priority,
    required this.relation,
    this.description,
    this.dueAt,
    this.latestAnswer,
  });

  bool get isOverdue => dueAt != null && dueAt!.isBefore(DateTime.now());

  factory TeacherStudentCase.fromJson(Map<String, dynamic> j) =>
      TeacherStudentCase(
        id: j['id']?.toString() ?? '',
        studentMssv: j['student_mssv']?.toString() ?? '',
        studentName: j['student_name']?.toString() ?? '',
        title: j['title']?.toString() ?? 'Sinh viên cần phản hồi',
        description: j['description']?.toString(),
        status: j['status']?.toString() ?? 'open',
        priority: j['priority']?.toString() ?? 'normal',
        relation: j['my_relation']?.toString() ?? 'primary',
        dueAt: DateTime.tryParse(j['due_at']?.toString() ?? '')?.toLocal(),
        latestAnswer: j['latest_answer']?.toString(),
      );
}

class TeacherCaseAnswer {
  final String caseId;
  final String status;
  final String? answer;

  const TeacherCaseAnswer({
    required this.caseId,
    required this.status,
    this.answer,
  });

  bool get requiresApproval => status == 'pending_approval';

  factory TeacherCaseAnswer.fromJson(Map<String, dynamic> j) {
    final rawCase = j['case'];
    final item = rawCase is Map<String, dynamic>
        ? rawCase
        : <String, dynamic>{};
    final official = j['official_answer'];
    return TeacherCaseAnswer(
      caseId: item['id']?.toString() ?? j['id']?.toString() ?? '',
      status: item['status']?.toString() ?? j['status']?.toString() ?? '',
      answer: official is Map<String, dynamic>
          ? official['text']?.toString()
          : j['answer']?.toString(),
    );
  }
}
