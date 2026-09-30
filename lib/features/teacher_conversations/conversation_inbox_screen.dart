import 'package:flutter/material.dart';

import '../../data/teacher_conversations_repository.dart';
import '../../models/teacher_conversation_models.dart';
import '../../services/crm_session_guard.dart';
import 'conversation_inbox_view_model.dart';
import 'conversation_thread_screen.dart';
import 'new_conversation_screen.dart';
import 'widgets/inbox_list.dart';

/// Teacher "Tin nhắn": threads addressed to this teacher, "Đang mở" and
/// "Đã xong". [openThreadId] opens one thread straight away (push tap).
class TeacherConversationsScreen extends StatefulWidget {
  final TeacherConversationsRepository repository;
  final String? openThreadId;
  const TeacherConversationsScreen({
    super.key,
    this.repository = const TeacherConversationsRepository(),
    this.openThreadId,
  });

  @override
  State<TeacherConversationsScreen> createState() =>
      _TeacherConversationsScreenState();
}

class _TeacherConversationsScreenState extends State<TeacherConversationsScreen>
    with SingleTickerProviderStateMixin {
  late final ConversationInboxViewModel _vm;
  late final TabController _tabs;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _vm = ConversationInboxViewModel(widget.repository)
      ..addListener(_onChanged);
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) _refresh();
      });
    _vm.load('open');
    _vm.load('closed');
    final id = widget.openThreadId;
    if (id != null && id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openId(id));
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _vm.dispose();
    _tabs.dispose();
    super.dispose();
  }

  String get _status => ConversationInboxViewModel.statuses[_tabs.index];

  Future<void> _refresh() => _vm.load(_status);

  void _onChanged() {
    if (_vm.authError == null || _authHandled || !mounted) return;
    _authHandled = true;
    handleCrmAuthError(context, _vm.authError!);
  }

  Future<void> _openId(String id) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationThreadScreen(
          conversationId: id,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) {
      _vm.load('open');
      _vm.load('closed');
    }
  }

  Future<void> _newThread() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => NewConversationScreen(repository: widget.repository),
      ),
    );
    if (id != null) await _openId(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tin nhắn'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Đang mở'),
          Tab(text: 'Đã xong'),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _newThread,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Nhắn sinh viên'),
    ),
    body: ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => TabBarView(
        controller: _tabs,
        children: [
          for (final s in ConversationInboxViewModel.statuses)
            InboxList(
              tab: _vm.tab(s),
              onRefresh: () => _vm.load(s),
              onOpen: (TeacherConversation c) => _openId(c.id),
            ),
        ],
      ),
    ),
  );
}
