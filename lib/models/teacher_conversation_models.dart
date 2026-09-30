// Models for the teacher side of the student help desk
// (`/api/v1/teacher/conversations`, crm-clean
// `routes/portals/teacher-conversations.js`). Everything is parsed
// defensively: a missing or oddly-typed field never throws.

DateTime? _date(Object? v) => DateTime.tryParse(v?.toString() ?? '')?.toLocal();

String _str(Object? v) => v?.toString().trim() ?? '';

/// One row of the inbox (`GET /`).
class TeacherConversation {
  final String id;
  final String subject;
  final String status;
  final String studentMssv;
  final String studentName;
  final String classCode;
  final String preview;
  final bool lastFromStudent;
  final bool awaitingReply;
  final DateTime? updatedAt;

  const TeacherConversation({
    required this.id,
    this.subject = '',
    this.status = 'open',
    this.studentMssv = '',
    this.studentName = '',
    this.classCode = '',
    this.preview = '',
    this.lastFromStudent = false,
    this.awaitingReply = false,
    this.updatedAt,
  });

  bool get isClosed => status == 'closed';

  factory TeacherConversation.fromJson(Map<String, dynamic> j) {
    final last = j['last_message'];
    final lastMap = last is Map ? last : const {};
    return TeacherConversation(
      id: _str(j['id']),
      subject: _str(j['subject']),
      status: _str(j['status']).isEmpty ? 'open' : _str(j['status']),
      studentMssv: _str(j['student_mssv']),
      studentName: _str(j['student_name']),
      classCode: _str(j['class_code']),
      preview: _str(lastMap['body']),
      lastFromStudent: lastMap['sender_type'] == 'student',
      awaitingReply: j['awaiting_reply'] == true,
      updatedAt: _date(lastMap['created_at']) ?? _date(j['updated_at']),
    );
  }

  static List<TeacherConversation> listFrom(Object? body) {
    final rows = body is Map ? body['conversations'] : null;
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(TeacherConversation.fromJson)
        .where((c) => c.id.isNotEmpty)
        .toList();
  }
}

/// One chat message. Students are `sender_type == 'student'`; the teacher's
/// own messages are stored server-side as `'staff'`.
class TeacherMessage {
  final String id;
  final String body;
  final bool fromStudent;
  final DateTime? createdAt;

  const TeacherMessage({
    required this.id,
    required this.body,
    required this.fromStudent,
    this.createdAt,
  });

  factory TeacherMessage.fromJson(Map<String, dynamic> j) => TeacherMessage(
    id: _str(j['id']),
    body: j['body']?.toString() ?? '',
    fromStudent: j['sender_type'] == 'student',
    createdAt: _date(j['created_at']),
  );
}

/// `GET /:id` — header info plus the messages, oldest first.
class TeacherThread {
  final TeacherConversation conversation;
  final List<TeacherMessage> messages;

  const TeacherThread(this.conversation, this.messages);

  factory TeacherThread.fromJson(Map<String, dynamic> j) {
    final conv = j['conversation'] is Map<String, dynamic>
        ? j['conversation'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final raw = j['messages'];
    return TeacherThread(
      TeacherConversation.fromJson({
        ...conv,
        'class_code': conv['student_class'] ?? conv['class_code'],
      }),
      raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(TeacherMessage.fromJson)
                .toList()
          : const [],
    );
  }
}

/// A student the teacher may start a thread with.
class PickerStudent {
  final String mssv;
  final String name;
  const PickerStudent(this.mssv, this.name);
}

/// A current-semester class with its students, for the "Nhắn sinh viên"
/// picker.
class PickerClass {
  final String sectionId;
  final String label;
  final List<PickerStudent> students;
  const PickerClass(this.sectionId, this.label, this.students);
}
