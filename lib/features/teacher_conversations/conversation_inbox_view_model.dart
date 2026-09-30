import 'package:flutter/foundation.dart';

import '../../data/teacher_conversations_repository.dart';
import '../../models/teacher_conversation_models.dart';
import 'conversation_format.dart';

/// State of one inbox tab.
class InboxTab {
  List<TeacherConversation> rows = const [];
  bool loading = true;
  String? error;

  /// Set when [rows] is the stored copy because the refresh failed.
  DateTime? staleAt;
}

/// Inbox "Tin nhắn": the teacher's own threads, `open` and `closed` tabs.
class ConversationInboxViewModel extends ChangeNotifier {
  static const statuses = ['open', 'closed'];

  final TeacherConversationsRepository _repo;
  ConversationInboxViewModel(this._repo);

  final Map<String, InboxTab> _tabs = {for (final s in statuses) s: InboxTab()};
  Object? _authError;
  bool _disposed = false;

  InboxTab tab(String status) => _tabs[status]!;
  Object? get authError => _authError;

  /// Loads [status], painting the stored copy first when there is one.
  Future<void> load(String status) async {
    final t = tab(status);
    t.error = null;
    if (t.rows.isEmpty) t.loading = true;
    _notify();
    try {
      final r = await _repo.list(
        status,
        onStored: (rows, at) {
          if (t.rows.isNotEmpty || _disposed) return;
          t.rows = rows;
          t.staleAt = at;
          t.loading = false;
          _notify();
        },
      );
      t.rows = r.data;
      t.staleAt = r.fresh ? null : r.savedAt;
    } catch (e) {
      if (isAuthError(e)) _authError = e;
      // Whatever is on screen (stored copy) stays; the message says why.
      t.error = conversationErrorText(e);
    }
    t.loading = false;
    _notify();
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
