import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ems_api_service.dart';

class EmsAttendanceDraft {
  const EmsAttendanceDraft({
    required this.marks,
    required this.notes,
    required this.queued,
    this.students = const [],
  });

  final Map<String, String> marks;
  final Map<String, String> notes;
  final bool queued;
  final List<EmsRosterStudent> students;
}

/// Small durable store for unreliable classroom networks.
///
/// Teacher choices are written here before an HTTP request. Student history is
/// also cached so the last confirmed result remains readable while offline.
class EmsAttendanceCache {
  static String _safe(String value) => base64Url.encode(utf8.encode(value));
  static String _draftKey(String sessionKey) =>
      'ems_attendance_draft_${_safe(sessionKey)}';
  static const _studentKey = 'ems_attendance_student_history_v1';
  static String _sessionsKey(String date) =>
      'ems_attendance_teacher_sessions_${_safe(date)}';

  static Future<void> saveTeacherSessions(
    String date,
    List<EmsSession> sessions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey(date),
      jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      }),
    );
  }

  static Future<List<EmsSession>> loadTeacherSessions(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey(date));
    if (raw == null) return const [];
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final sessions = data['sessions'];
      if (sessions is! List) return const [];
      return sessions
          .whereType<Map<String, dynamic>>()
          .map(EmsSession.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<EmsAttendanceDraft?> loadDraft(String sessionKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey(sessionKey));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return EmsAttendanceDraft(
        marks: (data['marks'] as Map<String, dynamic>? ?? const {}).map(
          (k, v) => MapEntry(k, v.toString()),
        ),
        notes: (data['notes'] as Map<String, dynamic>? ?? const {}).map(
          (k, v) => MapEntry(k, v.toString()),
        ),
        queued: data['queued'] == true,
        students: (data['students'] is List)
            ? (data['students'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map(EmsRosterStudent.fromJson)
                  .toList()
            : const [],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveDraft(
    String sessionKey,
    Map<String, String> marks,
    Map<String, String> notes, {
    required bool queued,
    List<EmsRosterStudent> students = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey(sessionKey),
      jsonEncode({
        'marks': marks,
        'notes': notes,
        'queued': queued,
        'students': students.map((s) => s.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<void> clearDraft(String sessionKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey(sessionKey));
  }

  static Future<void> saveStudentHistory(List<EmsStudentMark> marks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _studentKey,
      jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'marks': marks.map((m) => m.toJson()).toList(),
      }),
    );
  }

  static Future<List<EmsStudentMark>> loadStudentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_studentKey);
    if (raw == null) return const [];
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final marks = data['marks'];
      if (marks is! List) return const [];
      return marks
          .whereType<Map<String, dynamic>>()
          .map(EmsStudentMark.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
