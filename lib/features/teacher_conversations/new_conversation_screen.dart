import 'package:flutter/material.dart';

import '../../components/skeleton.dart';
import '../../data/teacher_conversations_repository.dart';
import '../../models/teacher_conversation_models.dart';
import '../../services/crm_session_guard.dart';
import '../../theme/vd_tokens.dart';
import 'new_conversation_view_model.dart';
import 'widgets/compose_sheet.dart';

/// Picker for "Nhắn sinh viên". Pops with the new conversation id.
class NewConversationScreen extends StatefulWidget {
  final TeacherConversationsRepository repository;
  const NewConversationScreen({
    super.key,
    this.repository = const TeacherConversationsRepository(),
  });

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  late final NewConversationViewModel _vm;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _vm = NewConversationViewModel(widget.repository)..addListener(_onChanged);
    _vm.load();
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _vm.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_vm.authError == null || _authHandled || !mounted) return;
    _authHandled = true;
    handleCrmAuthError(context, _vm.authError!);
  }

  Future<void> _compose(PickerStudent student) async {
    String? createdId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ComposeSheet(
        student: student,
        onSend: (subject, message) async {
          final r = await _vm.create(student, subject, message);
          createdId = r.id;
          return r.error;
        },
      ),
    );
    if (createdId != null && mounted) Navigator.pop(context, createdId);
  }

  Widget _list() {
    final vd = context.vd;
    if (_vm.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Skeleton(height: 120, radius: 12),
      );
    }
    if (_vm.error != null) {
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
    final groups = _vm.groups;
    if (groups.isEmpty) {
      return Center(
        child: Text(
          _vm.query.isEmpty
              ? 'Chưa có sinh viên nào trong học kỳ hiện tại'
              : 'Không tìm thấy sinh viên',
          style: TextStyle(color: vd.inkMuted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              g.label,
              style: TextStyle(fontWeight: FontWeight.w800, color: vd.ink),
            ),
          ),
          for (final s in g.students)
            ListTile(
              title: Text(s.name),
              subtitle: Text(s.mssv),
              onTap: () => _compose(s),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhắn sinh viên')),
    body: ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: _vm.setQuery,
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên hoặc MSSV',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _list()),
        ],
      ),
    ),
  );
}
