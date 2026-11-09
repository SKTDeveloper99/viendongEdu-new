import 'ems_api_service.dart';
import 'offline_snapshot.dart';

/// The student help desk already exists on EMS. This client only sends the
/// signed-in student's own requests; all routing is validated by the server.
class CrmQuestionsApi {
  CrmQuestionsApi._();

  static Future<List<QuestionThread>> list() async {
    final body = await EmsApiService.sendMap('GET', '/student/conversations');
    return _threads(body);
  }

  static Future<({List<QuestionThread> threads, DateTime savedAt})?>
  cachedList() async {
    final value = await OfflineSnapshot.load('questions_list');
    if (value == null || value.data is! Map<String, dynamic>) return null;
    try {
      return (threads: _threads(value.data), savedAt: value.savedAt);
    } catch (_) {
      return null;
    }
  }

  static List<QuestionThread> _threads(Map<String, dynamic> body) {
    final rows = body['conversations'];
    if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
      throw EmsException(
        'Máy chủ trả về câu hỏi không đọc được. Vui lòng thử lại.',
      );
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => EmsApiService.parse(() => QuestionThread.fromJson(row)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<List<QuestionTarget>> targets() async {
    final body = await EmsApiService.sendMap(
      'GET',
      '/student/conversations/targets',
    );
    final rows = EmsApiService.rows(body['targets']);
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => EmsApiService.parse(() => QuestionTarget.fromJson(row)))
        .toList();
  }

  static Future<QuestionDetail> detail(String id) async {
    final body = await EmsApiService.sendMap(
      'GET',
      '/student/conversations/${Uri.encodeComponent(id)}',
    );
    final detail = EmsApiService.parse(() => QuestionDetail.fromJson(body));
    if (detail.id != id || body['messages'] is! List) {
      throw EmsException(
        'Máy chủ trả về cuộc trao đổi không đọc được. Vui lòng thử lại.',
      );
    }
    return detail;
  }

  static Future<({QuestionDetail detail, DateTime savedAt})?> cachedDetail(
    String id,
  ) async {
    final value = await OfflineSnapshot.load('question_$id');
    if (value == null || value.data is! Map<String, dynamic>) return null;
    try {
      final detail = EmsApiService.parse(
        () => QuestionDetail.fromJson(value.data),
      );
      if (detail.id != id) return null;
      return (detail: detail, savedAt: value.savedAt);
    } catch (_) {
      return null;
    }
  }

  static Future<String> create({
    required String subject,
    required String message,
    required String targetType,
    String? teacherId,
  }) async {
    final body = await EmsApiService.sendMap(
      'POST',
      '/student/conversations',
      body: {
        'subject': subject.trim(),
        'body': message.trim(),
        'target_type': targetType,
        'target_teacher_id': ?teacherId,
      },
    );
    final conv = body['conversation'];
    final id = conv is Map ? conv['id']?.toString() : null;
    if (id == null || id.isEmpty) {
      throw EmsException(
        'Máy chủ chưa xác nhận câu hỏi. Hãy kiểm tra danh sách trước khi gửi lại.',
      );
    }
    return id;
  }

  static Future<void> sendMessage(String threadId, String message) async {
    await EmsApiService.sendMap(
      'POST',
      '/student/conversations/${Uri.encodeComponent(threadId)}/messages',
      body: {'body': message.trim()},
    );
  }
}

class QuestionThread {
  final String id;
  final String subject;
  final String status;
  final String preview;
  final DateTime? updatedAt;

  const QuestionThread({
    required this.id,
    required this.subject,
    required this.status,
    required this.preview,
    this.updatedAt,
  });

  bool get isClosed => status == 'closed';

  factory QuestionThread.fromJson(Map<String, dynamic> j) {
    final last = j['last_message'];
    return QuestionThread(
      id: j['id']?.toString() ?? '',
      subject: j['subject']?.toString().trim().isNotEmpty == true
          ? j['subject'].toString()
          : 'Câu hỏi của tôi',
      status: j['status']?.toString() ?? 'open',
      preview: last is Map ? last['body']?.toString() ?? '' : '',
      updatedAt: DateTime.tryParse(
        j['updated_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

class QuestionTarget {
  final String type;
  final String label;
  final bool available;
  final List<QuestionTeacher> teachers;

  const QuestionTarget({
    required this.type,
    required this.label,
    required this.available,
    this.teachers = const [],
  });

  factory QuestionTarget.fromJson(Map<String, dynamic> j) => QuestionTarget(
    type: j['target_type']?.toString() ?? '',
    label: j['label']?.toString() ?? '',
    available: j['available'] != false,
    teachers: (j['teachers'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(QuestionTeacher.fromJson)
        .toList(),
  );
}

class QuestionTeacher {
  final String id;
  final String name;
  final String? subject;
  const QuestionTeacher(this.id, this.name, this.subject);
  factory QuestionTeacher.fromJson(Map<String, dynamic> j) => QuestionTeacher(
    j['teacher_id']?.toString() ?? '',
    j['name']?.toString() ?? '',
    j['subject_name']?.toString(),
  );
}

class QuestionDetail {
  final String id;
  final String subject;
  final String status;
  final List<QuestionMessage> messages;
  const QuestionDetail(this.id, this.subject, this.status, this.messages);

  bool get isClosed => status == 'closed';

  factory QuestionDetail.fromJson(Map<String, dynamic> j) {
    final conv = j['conversation'] is Map<String, dynamic>
        ? j['conversation']
        : const <String, dynamic>{};
    final raw = j['messages'];
    return QuestionDetail(
      conv['id']?.toString() ?? '',
      conv['subject']?.toString() ?? 'Câu hỏi của tôi',
      conv['status']?.toString() ?? 'open',
      raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(QuestionMessage.fromJson)
                .toList()
          : const [],
    );
  }
}

class QuestionMessage {
  final String id;
  final String body;
  final bool fromStudent;
  final DateTime? createdAt;
  const QuestionMessage(this.id, this.body, this.fromStudent, this.createdAt);
  factory QuestionMessage.fromJson(Map<String, dynamic> j) => QuestionMessage(
    j['id']?.toString() ?? '',
    j['body']?.toString() ?? '',
    j['sender_type'] == 'student',
    DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
  );
}
