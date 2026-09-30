import 'package:flutter/foundation.dart';

import '../../data/teacher_conversations_repository.dart';
import '../../models/teacher_conversation_models.dart';
import 'conversation_format.dart';

/// "Nhắn sinh viên": current-semester students of this teacher, one entry per
/// MSSV, grouped by class and searchable by name or MSSV.
class NewConversationViewModel extends ChangeNotifier {
  final TeacherConversationsRepository _repo;
  NewConversationViewModel(this._repo);

  List<PickerClass> _classes = const [];
  String _query = '';
  bool _loading = true;
  String? _error;
  Object? _authError;
  bool _disposed = false;

  bool get loading => _loading;
  String? get error => _error;
  Object? get authError => _authError;
  String get query => _query;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _classes = await _repo.currentSemesterClasses();
    } catch (e) {
      if (isAuthError(e)) _authError = e;
      _error = conversationErrorText(e);
    }
    _loading = false;
    _notify();
  }

  void setQuery(String value) {
    _query = value;
    _notify();
  }

  /// Classes with their students after dedupe (a student in two classes
  /// appears once, under the first) and the search filter. Empty groups are
  /// dropped.
  List<PickerClass> get groups {
    final q = _query.trim().toLowerCase();
    final seen = <String>{};
    final out = <PickerClass>[];
    for (final c in _classes) {
      final kept = <PickerStudent>[];
      for (final s in c.students) {
        if (!seen.add(s.mssv)) continue;
        if (q.isEmpty ||
            s.mssv.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q)) {
          kept.add(s);
        }
      }
      if (kept.isNotEmpty) out.add(PickerClass(c.sectionId, c.label, kept));
    }
    return out;
  }

  /// Opens the thread. Returns (id, null) on success or (null, message).
  Future<({String? id, String? error})> create(
    PickerStudent student,
    String subject,
    String message,
  ) async {
    try {
      final id = await _repo.create(
        mssv: student.mssv,
        message: message,
        subject: subject,
      );
      return (id: id, error: null);
    } catch (e) {
      if (isAuthError(e)) _authError = e;
      return (id: null, error: conversationErrorText(e));
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
