import 'package:flutter/foundation.dart';

import '../../data/teacher_conversations_repository.dart';
import '../../models/teacher_conversation_models.dart';
import 'conversation_format.dart';

/// One thread: messages, sending and resolving.
class ConversationThreadViewModel extends ChangeNotifier {
  final TeacherConversationsRepository _repo;
  final String conversationId;
  ConversationThreadViewModel(this._repo, this.conversationId);

  TeacherThread? _thread;
  final List<TeacherMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _resolving = false;
  bool _resolved = false;
  String? _error;
  Object? _authError;
  bool _disposed = false;

  TeacherConversation? get conversation => _thread?.conversation;
  List<TeacherMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get sending => _sending;
  bool get resolving => _resolving;
  bool get isClosed => _resolved || (conversation?.isClosed ?? false);
  String? get error => _error;
  Object? get authError => _authError;

  Future<void> load() async {
    _loading = _thread == null;
    _error = null;
    _notify();
    try {
      final t = await _repo.thread(conversationId);
      _thread = t;
      _messages
        ..clear()
        ..addAll(t.messages);
    } catch (e) {
      if (isAuthError(e)) _authError = e;
      _error = conversationErrorText(e);
    }
    _loading = false;
    _notify();
  }

  /// Sends [text]; returns null on success or the message to show. The draft
  /// is only cleared by the caller on success.
  Future<String?> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return null;
    _sending = true;
    _notify();
    try {
      final sent = await _repo.send(conversationId, body);
      _messages.add(
        sent ??
            TeacherMessage(
              id: '',
              body: body,
              fromStudent: false,
              createdAt: DateTime.now(),
            ),
      );
      return null;
    } catch (e) {
      if (isAuthError(e)) _authError = e;
      return conversationErrorText(e);
    } finally {
      _sending = false;
      _notify();
    }
  }

  /// Marks the thread resolved (PATCH); returns null on success or the
  /// message to show.
  Future<String?> resolve() async {
    if (_resolving) return null;
    _resolving = true;
    _notify();
    try {
      await _repo.resolve(conversationId);
      _resolved = true;
      return null;
    } catch (e) {
      if (isAuthError(e)) _authError = e;
      return conversationErrorText(e);
    } finally {
      _resolving = false;
      _notify();
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
