import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_motion.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import 'work_api.dart';
import '../nhom/nhom_screens.dart';
import '../nhom/small_group_api.dart';
import '../nhom/small_group_screens.dart';

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

  // Hand-ins waiting for a check first, then open parts, then finished ones.
  List<Map<String, dynamic>> get _assignments {
    final list = ((_task?['assignments'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
    int rank(Map a) => switch ('${a['status']}') {
      'submitted' || 'in_review' => 0,
      'in_progress' || 'blocked' => 1,
      'assigned' => 2,
      _ => 3,
    };
    list.sort((a, b) => rank(a).compareTo(rank(b)));
    return list;
  }

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

  // ── Action effects (Overlord home, agreed 2026-11-16) ─────────────────────
  // Each action button shows progress while its request runs, then a check
  // with a haptic; a person whose part is settled leaves the list over 200 ms
  // instead of the whole list jumping; a failure says what happened in one
  // line with "Thử lại". All durations come from VdMotion (zero under Reduce
  // Motion).
  final Map<String, String> _act = {}; // key → busy | done | error message
  final Map<String, Future<void> Function()> _retry = {};
  final Set<String> _leaving = {};

  Future<void> _action(
    String key,
    Future<void> Function() fn, {
    String? leave,
  }) async {
    setState(() {
      _act[key] = 'busy';
      _retry[key] = () => _action(key, fn, leave: leave);
    });
    try {
      await fn();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _act[key] = 'done');
      final m = VdMotion.of(context);
      await Future.delayed(
        m.reduced ? Duration.zero : const Duration(milliseconds: 450),
      );
      if (!mounted) return;
      if (leave != null) {
        setState(() => _leaving.add(leave));
        await Future.delayed(m.standard);
      }
      if (!mounted) return;
      await _load();
      if (mounted)
        setState(() {
          _act.remove(key);
          _retry.remove(key);
          _leaving.remove(leave);
        });
    } on EmsException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        handleCrmAuthError(context, e);
        return;
      }
      setState(() => _act[key] = e.message);
    } catch (_) {
      if (mounted) setState(() => _act[key] = 'Không kết nối được máy chủ.');
    }
  }

  /// A button that answers its own action: spinner, then a check.
  Widget _actButton(
    String key,
    String label,
    VoidCallback onPressed, {
    bool filled = false,
    IconData? icon,
  }) {
    final st = _act[key];
    final busy = st == 'busy';
    final done = st == 'done';
    final Widget child = AnimatedSwitcher(
      duration: VdMotion.of(context).quick,
      child: busy
          ? const SizedBox(
              key: ValueKey('b'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : done
          ? const Icon(Icons.check, key: ValueKey('d'), size: 20)
          : Row(
              key: const ValueKey('l'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(label),
              ],
            ),
    );
    final press = (busy || done) ? () {} : onPressed;
    return filled
        ? FilledButton(onPressed: press, child: child)
        : OutlinedButton(onPressed: press, child: child);
  }

  /// One line under a card's buttons when an action failed, with a retry.
  Widget _actError(VdTokens vd, List<String> keys) {
    for (final k in keys) {
      final st = _act[k];
      if (st != null && st != 'busy' && st != 'done') {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  st,
                  style: TextStyle(color: vd.danger, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => _retry[k]?.call(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        );
      }
    }
    return const SizedBox.shrink();
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
          MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.paddingOf(ctx).bottom +
              16,
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

  Future<void> _approve(Map<String, dynamic> a) => _action(
    'approve:${a['id']}',
    () => WorkApi.approve(widget.taskId, '${a['id']}', '${a['status']}'),
    leave: '${a['id']}',
  );

  Future<void> _giveBack(Map<String, dynamic> a) async {
    final note = await _ask(
      title: 'Trả lại cho ${a['teacher_name'] ?? 'người này'}',
      hint: 'Một câu: cần sửa gì',
      action: 'Trả lại',
    );
    if (note == null || note.isEmpty) return;
    await _action(
      'return:${a['id']}',
      () => WorkApi.giveBack(widget.taskId, '${a['id']}', note),
      leave: '${a['id']}',
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
    await _action(
      'nudge:${a['id']}',
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
    await _action('handin:${a['id']}', () async {
      if (a['status'] == 'assigned')
        await WorkApi.move('${a['id']}', 'in_progress');
      await WorkApi.move('${a['id']}', to, note: note);
    });
  }

  Future<void> _delegate() async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DelegateScreen(
          taskId: widget.taskId,
          pieceTitle: '${_task?['title'] ?? ''}',
        ),
      ),
    );
    if (done == true) await _load();
  }

  List<Widget> _smallGroup(VdTokens vd, Map<String, dynamic> g) {
    final id = g['space_id']?.toString();
    final kept = g['kept_at'] != null;
    final closed = g['archived_at'] != null;
    return [
      _section(vd, 'Nhóm nhỏ của việc này'),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: vd.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: vd.hairline),
        ),
        child: id == null
            ? Text(
                'Người nhận đã mở một nhóm nhỏ (${g['member_count'] ?? 0} người) để chia việc.',
                style: TextStyle(color: vd.inkMuted),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${g['name'] ?? ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: vd.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${g['member_count'] ?? 0} người',
                      closed
                          ? 'đã đóng'
                          : (kept
                                ? 'nhóm lâu dài'
                                : 'nhóm tạm, tự đóng khi việc xong'),
                    ].join(' · '),
                    style: TextStyle(color: vd.inkMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.groups_2_outlined, size: 18),
                        label: const Text('Mở nhóm'),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NhomScreen(
                                spaceId: id,
                                name: '${g['name'] ?? ''}',
                              ),
                            ),
                          );
                          _load();
                        },
                      ),
                      if (g['can_keep'] == true)
                        TextButton.icon(
                          icon: const Icon(Icons.push_pin_outlined, size: 18),
                          label: const Text('Giữ nhóm này'),
                          onPressed: () => _run(
                            'Đã giữ nhóm. Nhóm không tự đóng nữa.',
                            () => SmallGroupApi.keep(id),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    ];
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
        if (t['small_group'] is Map)
          ..._smallGroup(vd, (t['small_group'] as Map).cast<String, dynamic>()),
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
    final m = VdMotion.of(context);
    final gone = _leaving.contains('${a['id']}');
    return AnimatedSize(
      duration: m.standard,
      curve: VdMotion.curve,
      child: AnimatedOpacity(
        duration: m.standard,
        opacity: gone ? 0 : 1,
        child: gone
            ? const SizedBox(width: double.infinity)
            : _personCard(vd, a, s, open, review, last, handedFiles, returned),
      ),
    );
  }

  Widget _personCard(
    VdTokens vd,
    Map<String, dynamic> a,
    String s,
    bool open,
    bool review,
    Map? last,
    List<Map> handedFiles,
    int returned,
  ) {
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
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
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
                    _actButton(
                      'approve:${a['id']}',
                      'Duyệt',
                      () => _approve(a),
                      filled: true,
                    ),
                  if (review)
                    _actButton(
                      'return:${a['id']}',
                      'Trả lại',
                      () => _giveBack(a),
                    ),
                  if (!review)
                    _actButton(
                      'nudge:${a['id']}',
                      'Nhắc',
                      () => _nudge(a),
                      icon: Icons.notifications_active_outlined,
                    ),
                ],
              ),
            ),
          _actError(vd, [
            'approve:${a['id']}',
            'return:${a['id']}',
            'nudge:${a['id']}',
          ]),
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
                _actButton(
                  'ack:${a['id']}',
                  'Đã nhận',
                  () => _action(
                    'ack:${a['id']}',
                    () => WorkApi.acknowledge('${a['id']}'),
                  ),
                ),
              if (s == 'assigned' || s == 'in_progress')
                _actButton(
                  'handin:${a['id']}',
                  'Nộp',
                  () => _handIn(a),
                  filled: true,
                ),
              // Overlord slice: pass part of this piece to others, from here.
              if (s == 'assigned' || s == 'in_progress')
                OutlinedButton.icon(
                  onPressed: _delegate,
                  icon: const Icon(Icons.call_split, size: 18),
                  label: const Text('Giao một phần'),
                ),
            ],
          ),
          _actError(vd, ['ack:${a['id']}', 'handin:${a['id']}']),
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
