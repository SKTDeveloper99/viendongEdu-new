import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import 'work_api.dart';

/// One piece of work on ONE screen (Overlord slice): what it is, where it
/// came from (a calendar line, a Nhóm), its files, each person's part with
/// Duyệt / Trả lại / Nhắc for the giver, the receiver's own moves, and the
/// conversation. Every list, bell and line opens this same screen.
class PieceScreen extends StatefulWidget {
  final String taskId;
  const PieceScreen({super.key, required this.taskId});

  @override
  State<PieceScreen> createState() => _PieceScreenState();
}

class _PieceScreenState extends State<PieceScreen> {
  Map<String, dynamic>? _task;
  List<Map<String, dynamic>> _comments = const [];
  String? _error;
  bool _busy = false;
  final _commentCtrl = TextEditingController();

  String? get _me => AppSession.instance.userId;
  String? get _myTeacherId => AppSession.instance.teacherId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await WorkApi.task(widget.taskId);
      final c = await WorkApi.comments(
        widget.taskId,
      ).catchError((_) => <Map<String, dynamic>>[]);
      if (mounted)
        setState(() {
          _task = t;
          _comments = c;
          _error = null;
        });
    } on EmsException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        handleCrmAuthError(context, e);
        return;
      }
      setState(() => _error = e.message);
    }
  }

  List<Map<String, dynamic>> get _assignments =>
      ((_task?['assignments'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

  bool get _iGave => _task != null && '${_task!['created_by']}' == _me;

  Map<String, dynamic>? get _mine {
    for (final a in _assignments) {
      if ('${a['assignee_user_id']}' == _me ||
          (_myTeacherId != null && '${a['teacher_id']}' == _myTeacherId)) {
        return a;
      }
    }
    return null;
  }

  Future<void> _run(String done, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showSuccessSnack(context, done);
      await _load();
    } on EmsException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        handleCrmAuthError(context, e);
        return;
      }
      showErrorSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask({
    required String title,
    required String hint,
    required String action,
    bool required = true,
    String initial = '',
  }) {
    final ctrl = TextEditingController(text: initial);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl,
              builder: (ctx, v, _) {
                final ok = !required || v.text.trim().isNotEmpty;
                return FilledButton(
                  onPressed: ok
                      ? () => Navigator.pop(ctx, ctrl.text.trim())
                      : null,
                  child: Text(action),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(Map<String, dynamic> a) => _run(
    'Đã duyệt phần của ${a['teacher_name'] ?? 'người này'}.',
    () => WorkApi.approve(widget.taskId, '${a['id']}', '${a['status']}'),
  );

  Future<void> _giveBack(Map<String, dynamic> a) async {
    final note = await _ask(
      title: 'Trả lại cho ${a['teacher_name'] ?? 'người này'}',
      hint: 'Một câu: cần sửa gì',
      action: 'Trả lại',
    );
    if (note == null || note.isEmpty) return;
    await _run(
      'Đã trả lại.',
      () => WorkApi.giveBack(widget.taskId, '${a['id']}', note),
    );
  }

  Future<void> _nudge(Map<String, dynamic> a) async {
    final msg = await _ask(
      title: 'Nhắc ${a['teacher_name'] ?? 'người này'}',
      hint: 'Câu nhắc của cô (để trống: câu nhắc mặc định)',
      action: 'Gửi lời nhắc',
      required: false,
    );
    if (msg == null) return;
    await _run(
      'Đã nhắc.',
      () => WorkApi.nudge(widget.taskId, '${a['id']}', msg),
    );
  }

  Future<void> _handIn(Map<String, dynamic> a) async {
    final note = await _ask(
      title: 'Nộp phần việc',
      hint: 'Ghi chú khi nộp',
      action: 'Nộp',
      required: false,
    );
    if (note == null) return;
    final to = _task?['requires_review'] == true ? 'submitted' : 'done';
    await _run('Đã nộp.', () async {
      if (a['status'] == 'assigned')
        await WorkApi.move('${a['id']}', 'in_progress');
      await WorkApi.move('${a['id']}', to, note: note);
    });
  }

  Future<void> _sendComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    await _run('Đã gửi.', () async {
      await WorkApi.addComment(widget.taskId, body);
      _commentCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Một việc')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _task == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: AbsorbPointer(absorbing: _busy, child: _body(vd)),
            ),
    );
  }

  Widget _body(VdTokens vd) {
    final t = _task!;
    final line = t['calendar_line'] as Map?;
    final files = [
      ...((t['instruction_attachments'] as List?) ?? const []),
      ...((t['attachments'] as List?) ?? const []).where(
        (f) => (f as Map)['assignment_id'] == null,
      ),
    ].cast<Map>();
    final mine = _mine;
    final total = _assignments.length;
    final done = _assignments.where((a) => a['status'] == 'done').length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          '${t['title'] ?? ''}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: vd.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          [
            'Giao bởi ${t['created_by_name'] ?? '—'}',
            if (dueLabel(t['due_at']).isNotEmpty) dueLabel(t['due_at']),
            if (total > 0) '$done/$total đã duyệt',
          ].join(' · '),
          style: TextStyle(color: vd.inkMuted),
        ),
        if (line != null || t['space_name'] != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (line != null)
                _chip(
                  vd,
                  Icons.event_note,
                  'Dòng lịch: ${line['content'] ?? 'riêng tư'}',
                ),
              if (t['space_name'] != null)
                _chip(vd, Icons.groups_2_outlined, 'Nhóm: ${t['space_name']}'),
            ],
          ),
        ],
        if ('${t['description'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '${t['description']}',
            style: TextStyle(color: vd.ink, height: 1.4),
          ),
        ],
        if (files.isNotEmpty) ...[
          _section(vd, 'Tệp kèm (${files.length})'),
          for (final f in files) _fileRow(vd, f),
        ],
        if (mine != null) ...[_section(vd, 'Phần của tôi'), _myPart(vd, mine)],
        if (_iGave || AppSession.instance.isStaff && mine == null) ...[
          _section(vd, 'Người nhận ($total)'),
          for (final a in _assignments) _person(vd, a),
        ],
        _section(vd, 'Trao đổi (${_comments.length})'),
        for (final c in _comments) _comment(vd, c),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Viết trao đổi…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sendComment,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  Widget _section(VdTokens vd, String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: vd.inkMuted,
      ),
    ),
  );

  Widget _chip(VdTokens vd, IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: vd.accentSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: vd.accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: vd.accent),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _fileRow(VdTokens vd, Map f) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(Icons.attach_file, size: 18, color: vd.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${f['filename'] ?? 'tệp'}',
            style: TextStyle(color: vd.ink),
          ),
        ),
      ],
    ),
  );

  Color _statusColor(VdTokens vd, String s) => switch (s) {
    'submitted' || 'in_review' => vd.warning,
    'done' => vd.success,
    'in_progress' => vd.info,
    'blocked' || 'cancelled' => vd.danger,
    _ => vd.inkMuted,
  };

  Widget _person(VdTokens vd, Map<String, dynamic> a) {
    final s = '${a['status']}';
    final open = !['done', 'cancelled'].contains(s);
    final review = s == 'submitted' || s == 'in_review';
    final attempts = ((a['submission_attempts'] as List?) ?? const [])
        .cast<Map>();
    final last = attempts.isNotEmpty ? attempts.last : null;
    final handedFiles = ((a['attachments'] as List?) ?? const []).cast<Map>();
    final returned = asInt(a['returned_count']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vd.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: review ? vd.warning : vd.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${a['teacher_name'] ?? '—'}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: vd.ink),
                ),
              ),
              Text(
                statusLabel(
                  s,
                  acknowledged: a['acknowledged_at'] != null,
                  returned: returned,
                ),
                style: TextStyle(
                  color: _statusColor(vd, s),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (a['submitted_at'] != null ||
              returned > 0 ||
              a['is_overdue'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (a['submitted_at'] != null)
                    'nộp lúc ${whenLabel(a['submitted_at'])}',
                  if (returned > 0) 'đã trả lại $returned lần',
                  if (a['is_overdue'] == true) 'quá hạn',
                ].join(' · '),
                style: TextStyle(color: vd.inkMuted, fontSize: 12),
              ),
            ),
          if (last != null && '${last['note'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '“${last['note']}”',
                style: TextStyle(color: vd.ink, fontStyle: FontStyle.italic),
              ),
            ),
          for (final f in handedFiles) _fileRow(vd, f),
          if (_iGave && open)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (review)
                    FilledButton(
                      onPressed: () => _approve(a),
                      child: const Text('Duyệt'),
                    ),
                  if (review)
                    OutlinedButton(
                      onPressed: () => _giveBack(a),
                      child: const Text('Trả lại'),
                    ),
                  if (!review)
                    OutlinedButton.icon(
                      onPressed: () => _nudge(a),
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 18,
                      ),
                      label: const Text('Nhắc'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _myPart(VdTokens vd, Map<String, dynamic> a) {
    final s = '${a['status']}';
    final returned = asInt(a['returned_count']);
    final lastReturn = ((a['history'] as List?) ?? const [])
        .cast<Map>()
        .where((h) => h['event'] == 'returned')
        .lastOrNull;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vd.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vd.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusLabel(
              s,
              acknowledged: a['acknowledged_at'] != null,
              returned: returned,
            ),
            style: TextStyle(
              color: _statusColor(vd, s),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (s == 'in_progress' &&
              lastReturn != null &&
              '${lastReturn['note'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Lý do trả lại: ${lastReturn['note']}',
                style: TextStyle(color: vd.danger),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (s == 'assigned' && a['acknowledged_at'] == null)
                OutlinedButton(
                  onPressed: () => _run(
                    'Đã nhận việc.',
                    () => WorkApi.acknowledge('${a['id']}'),
                  ),
                  child: const Text('Đã nhận'),
                ),
              if (s == 'assigned' || s == 'in_progress')
                FilledButton(
                  onPressed: () => _handIn(a),
                  child: const Text('Nộp'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comment(VdTokens vd, Map<String, dynamic> c) {
    final who =
        c['author_name'] ??
        c['user_name'] ??
        c['full_name'] ??
        c['created_by_name'] ??
        '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$who · ${whenLabel(c['created_at'])}',
            style: TextStyle(color: vd.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text('${c['body'] ?? ''}', style: TextStyle(color: vd.ink)),
        ],
      ),
    );
  }
}
