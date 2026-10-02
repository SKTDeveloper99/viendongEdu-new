import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';
import 'ems_api_service.dart';

class EmsAttendanceDraft {
  const EmsAttendanceDraft({
    required this.marks,
    required this.notes,
    required this.queued,
    this.students = const [],
    this.session,
    this.savedAt,
  });

  final Map<String, String> marks;
  final Map<String, String> notes;
  final bool queued;
  final List<EmsRosterStudent> students;

  /// Session identity needed to resend without the roster screen. Null on
  /// drafts written by older releases; those are left for the screen.
  final EmsSession? session;

  /// Last time this draft (including its cached roster) was written locally.
  final DateTime? savedAt;
}

/// A stored draft together with the key it was saved under.
class EmsStoredDraft {
  const EmsStoredDraft(this.draftKey, this.draft);
  final String draftKey;
  final EmsAttendanceDraft draft;
}

/// Small durable store for unreliable classroom networks.
///
/// Teacher choices are written here before an HTTP request. Student history is
/// also cached so the last confirmed result remains readable while offline.
class EmsAttendanceCache {
  static String _safe(String value) => base64Url.encode(utf8.encode(value));
  static String? get _account {
    final session = AppSession.instance;
    final id = session.isGiangVien ? session.teacherId : session.mssv;
    if (!session.hasEms || id == null || id.isEmpty) return null;
    return _safe('${session.role}:$id');
  }

  static String? _key(String kind, String suffix) {
    final account = _account;
    if (account == null) return null;
    return 'ems_attendance_v2_${account}_${kind}_${_safe(suffix)}';
  }

  /// Older releases used device-wide keys. On upgrade, the restored account
  /// is the only identity known to own them. Move them before another account
  /// can sign in; never read the old keys in normal screen flows.
  static Future<void> migrateLegacyForRestoredAccount() async {
    if (_account == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final oldKey in prefs.getKeys().toList()) {
      String? newKey;
      if (AppSession.instance.isGiangVien &&
          oldKey.startsWith('ems_attendance_draft_')) {
        final suffix = oldKey.substring('ems_attendance_draft_'.length);
        newKey = 'ems_attendance_v2_${_account}_draft_$suffix';
      } else if (AppSession.instance.isGiangVien &&
          oldKey.startsWith('ems_attendance_teacher_sessions_')) {
        final suffix = oldKey.substring(
          'ems_attendance_teacher_sessions_'.length,
        );
        newKey = 'ems_attendance_v2_${_account}_sessions_$suffix';
      } else if (!AppSession.instance.isGiangVien &&
          oldKey == 'ems_attendance_student_history_v1') {
        newKey = _key('student_history', 'latest');
      }
      if (newKey == null) continue;
      final value = prefs.getString(oldKey);
      if (value != null && !prefs.containsKey(newKey)) {
        final saved = await prefs.setString(newKey, value);
        if (!saved) continue;
      }
      await prefs.remove(oldKey);
    }
  }

  /// A fresh login cannot prove who owned old device-wide keys. Remove them
  /// rather than expose another person's roster on a shared phone.
  static Future<void> purgeUnownedLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('ems_attendance_draft_') ||
          key.startsWith('ems_attendance_teacher_sessions_') ||
          key == 'ems_attendance_student_history_v1') {
        await prefs.remove(key);
      }
    }
  }

  static Future<void> saveTeacherSessions(
    String date,
    List<EmsSession> sessions,
  ) async {
    final key = _key('sessions', date);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      }),
    );
  }

  static Future<List<EmsSession>> loadTeacherSessions(String date) async {
    final key = _key('sessions', date);
    if (key == null) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
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
    final key = _key('draft', sessionKey);
    if (key == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return _decodeDraft(prefs.getString(key));
  }

  /// Every draft of the CURRENT account (never another account's).
  static Future<List<EmsStoredDraft>> listDrafts() async {
    final account = _account;
    if (account == null) return const [];
    final prefix = 'ems_attendance_v2_${account}_draft_';
    final prefs = await SharedPreferences.getInstance();
    final out = <EmsStoredDraft>[];
    for (final k in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      try {
        final draftKey = utf8.decode(
          base64Url.decode(k.substring(prefix.length)),
        );
        final d = _decodeDraft(prefs.getString(k));
        if (d != null) out.add(EmsStoredDraft(draftKey, d));
      } catch (_) {
        // Unreadable key: not ours to resend.
      }
    }
    return out;
  }

  static EmsAttendanceDraft? _decodeDraft(String? raw) {
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return EmsAttendanceDraft(
        session: data['session'] is Map<String, dynamic>
            ? EmsSession.fromJson(data['session'] as Map<String, dynamic>)
            : null,
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
        savedAt: DateTime.tryParse(
          data['updated_at']?.toString() ?? '',
        )?.toLocal(),
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
    EmsSession? session,
  }) async {
    final key = _key('draft', sessionKey);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'marks': marks,
        'notes': notes,
        'queued': queued,
        'students': students.map((s) => s.toJson()).toList(),
        if (session != null) 'session': session.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<void> clearDraft(String sessionKey) async {
    final key = _key('draft', sessionKey);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> saveStudentHistory(List<EmsStudentMark> marks) async {
    final key = _key('student_history', 'latest');
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'marks': marks.map((m) => m.toJson()).toList(),
      }),
    );
  }

  static Future<List<EmsStudentMark>> loadStudentHistory() async {
    final key = _key('student_history', 'latest');
    if (key == null) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
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
