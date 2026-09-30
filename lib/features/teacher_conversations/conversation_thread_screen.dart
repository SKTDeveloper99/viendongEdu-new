import 'package:flutter/material.dart';

import '../../components/skeleton.dart';
import '../../data/teacher_conversations_repository.dart';
import '../../services/crm_session_guard.dart';
import '../../theme/vd_tokens.dart';
import 'conversation_thread_view_model.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';

/// One chat thread with a student: bubbles, composer and "Đánh dấu đã giải
/// quyết".
class ConversationThreadScreen extends StatefulWidget {
  final String conversationId;
  final TeacherConversationsRepository repository;
  const ConversationThreadScreen({
    super.key,
    required this.conversationId,
    this.repository = const TeacherConversationsRepository(),
  });

  @override
  State<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState extends State<ConversationThreadScreen> {
  late final ConversationThreadViewModel _vm;
  final _scroll = ScrollController();
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _vm = ConversationThreadViewModel(widget.repository, widget.conversationId)
      ..addListener(_onChanged);
    _vm.load();
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _vm.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_vm.authError == null || _authHandled || !mounted) return;
    _authHandled = true;
    handleCrmAuthError(context, _vm.authError!);
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _send(String text) async {
    final error = await _vm.send(text);
    if (!mounted) return error == null;
    if (error != null) {
      _toast(error);
      return false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
    return true;
  }

  Future<void> _resolve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đánh dấu đã giải quyết?'),
        content: const Text(
          'Cuộc trò chuyện sẽ đóng, sinh viên không nhắn thêm được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await _vm.resolve();
    if (!mounted) return;
    _toast(error ?? 'Đã đánh dấu đã giải quyết');
  }

  Widget _body() {
    if (_vm.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Skeleton(height: 120, radius: 12),
      );
    }
    if (_vm.error != null && _vm.conversation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_vm.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _vm.load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: [for (final m in _vm.messages) MessageBubble(message: m)],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _vm,
    builder: (context, _) {
      final c = _vm.conversation;
      final title = c == null || c.studentName.isEmpty
          ? 'Tin nhắn'
          : '${c.studentName} · ${c.studentMssv}';
      return Scaffold(
        appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
        body: Column(
          children: [
            if (c != null && !_vm.isClosed)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _vm.resolving ? null : _resolve,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Đánh dấu đã giải quyết'),
                ),
              ),
            Expanded(child: _body()),
            if (c != null && _vm.isClosed)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Cuộc trò chuyện đã giải quyết',
                  style: TextStyle(color: context.vd.inkMuted),
                ),
              )
            else if (c != null)
              MessageComposer(sending: _vm.sending, onSend: _send),
          ],
        ),
      );
    },
  );
}
