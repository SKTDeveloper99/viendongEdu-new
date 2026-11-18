part of 'my_work_screen.dart';

extension _MyWorkScreenStatePart1 on _MyWorkScreenState {
  bool get _gives =>
      AppSession.instance.isStaff || AppSession.instance.canAssign;

  Future<void> _load() async {
    await Future.wait([_loadReceived(), if (_gives) _loadGiven()]);
  }

  Future<void> _loadReceived() async {
    try {
      final r = await WorkApi.received();
      if (mounted) {
        _set(() {
          _received = r;
          _receivedError = null;
        });
      }
    } on EmsException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        handleCrmAuthError(context, e);
        return;
      }
      _set(() => _receivedError = e.message);
    }
  }

  Future<void> _loadGiven() async {
    try {
      final g = await WorkApi.given();
      if (mounted) {
        _set(() {
          _given = g;
          _givenError = null;
        });
      }
    } on EmsException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        handleCrmAuthError(context, e);
        return;
      }
      _set(
        () => _givenError = e.statusCode == 403
            ? 'Danh sách việc đã giao chưa mở cho tài khoản này.'
            : e.message,
      );
    }
  }

  Future<void> _open(String taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PieceScreen(taskId: taskId)),
    );
    _load();
  }

  int _waiting(Map<String, dynamic> t) =>
      asInt(t['n_submitted']) + asInt(t['n_in_review']);

  List<Map<String, dynamic>> get _openReceived {
    final open = (_received ?? const [])
        .where((a) => a['status'] != 'done' && a['status'] != 'cancelled')
        .toList();
    return myWorkUnopenedFirst ? unopenedFirst(open) : open;
  }

  // Clean start: pieces nobody has touched yet are folded away, not lost.
  List<Map<String, dynamic>> get _activeGiven => (_given ?? const [])
      .where(
        (t) =>
            t['derived_status'] != 'cancelled' &&
            t['derived_status'] != 'done' &&
            (asInt(t['n_in_progress']) + _waiting(t) + asInt(t['n_blocked'])) >
                0,
      )
      .toList();

  List<Map<String, dynamic>> get _untouchedGiven => (_given ?? const [])
      .where(
        (t) =>
            t['derived_status'] != 'cancelled' &&
            t['derived_status'] != 'done' &&
            !_activeGiven.contains(t),
      )
      .toList();

  List<Map<String, dynamic>> get _toReview =>
      (_given ?? const []).where((t) => _waiting(t) > 0).toList();

  Widget _receivedTab() {
    if (_receivedError != null) return _error(_receivedError!, _loadReceived);
    if (_received == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final open = _openReceived;
    final closed = _received!.where((a) => !open.contains(a)).toList();
    return RefreshIndicator(
      onRefresh: _loadReceived,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (open.isEmpty) _empty('Không có việc nào đang chờ bạn.'),
          for (final a in open) _receivedCard(a),
          if (closed.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Đã xong (${closed.length})'),
              children: [for (final a in closed) _receivedCard(a)],
            ),
        ],
      ),
    );
  }

  Widget _givenTab() {
    if (_givenError != null) return _error(_givenError!, _loadGiven);
    if (_given == null) return const Center(child: CircularProgressIndicator());
    final untouched = _untouchedGiven;
    return RefreshIndicator(
      onRefresh: _loadGiven,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_activeGiven.isEmpty)
            _empty('Chưa có việc nào người nhận đang làm.'),
          for (final t in _activeGiven) _givenCard(t),
          if (untouched.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Chưa ai mở (${untouched.length})'),
              subtitle: const Text('Cất gọn ở đây, không xoá gì.'),
              children: [for (final t in untouched) _givenCard(t)],
            ),
        ],
      ),
    );
  }

  Widget _reviewTab() {
    if (_givenError != null) return _error(_givenError!, _loadGiven);
    if (_given == null) return const Center(child: CircularProgressIndicator());
    final list = _toReview;
    return RefreshIndicator(
      onRefresh: _loadGiven,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (list.isEmpty) _empty('Không có bài nộp nào chờ bạn duyệt.'),
          for (final t in list) _givenCard(t, review: true),
        ],
      ),
    );
  }

  Widget _receivedCard(Map<String, dynamic> a) {
    final returned =
        asInt(a['returned_count']) > 0 && a['status'] == 'in_progress';
    return _Card(
      title: '${a['title'] ?? ''}',
      lines: [
        'Từ ${a['assigned_by_name'] ?? '—'}',
        if (a['space_name'] != null) 'Nhóm: ${a['space_name']}',
        if (returned && a['returned_note'] != null)
          'Lý do trả lại: ${a['returned_note']}',
      ],
      chip: statusLabel(
        '${a['status']}',
        acknowledged: a['acknowledged_at'] != null,
        returned: asInt(a['returned_count']),
      ),
      chipTone: returned || a['is_overdue'] == true
          ? _Tone.danger
          : _toneOf('${a['status']}'),
      trailing: dueLabel(a['due_at']),
      onTap: () => _open('${a['task_id']}'),
    );
  }

  Widget _givenCard(Map<String, dynamic> t, {bool review = false}) {
    final total = asInt(t['assignee_count']);
    final done = asInt(t['n_done']);
    final waiting = _waiting(t);
    final unopened = asInt(t['n_assigned']);
    final overdue = asInt(t['n_overdue']);
    return _Card(
      title: '${t['title'] ?? ''}',
      lines: [
        '$total người · $done đã duyệt'
            '${waiting > 0 ? ' · $waiting chờ duyệt' : ''}'
            '${unopened > 0 ? ' · $unopened ${taskShowsReceipt ? 'chưa mở' : 'chưa bắt đầu'}' : ''}',
        if (overdue > 0) '$overdue quá hạn',
      ],
      chip: review
          ? '$waiting chờ duyệt'
          : statusLabel('${t['derived_status']}'),
      chipTone: review ? _Tone.warning : _toneOf('${t['derived_status']}'),
      trailing: dueLabel(t['due_at']),
      onTap: () => _open('${t['id']}'),
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(text, style: TextStyle(color: context.vd.inkMuted)),
    ),
  );

  Widget _error(String msg, Future<void> Function() retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

enum _Tone { neutral, info, warning, success, danger }

_Tone _toneOf(String status) => switch (status) {
  'submitted' || 'in_review' => _Tone.warning,
  'done' => _Tone.success,
  'in_progress' => _Tone.info,
  'blocked' || 'cancelled' => _Tone.danger,
  _ => _Tone.neutral,
};

class _Card extends StatelessWidget {
  final String title;
  final List<String> lines;
  final String chip;
  final _Tone chipTone;
  final String trailing;
  final VoidCallback onTap;
  const _Card({
    required this.title,
    required this.lines,
    required this.chip,
    required this.chipTone,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final (bg, fg) = switch (chipTone) {
      _Tone.info => (vd.infoSoft, vd.info),
      _Tone.warning => (vd.warningSoft, vd.warning),
      _Tone.success => (vd.successSoft, vd.success),
      _Tone.danger => (vd.dangerSoft, vd.danger),
      _Tone.neutral => (vd.surfaceAlt, vd.inkMuted),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: vd.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: vd.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: vd.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          color: fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final l in lines)
                  Text(l, style: TextStyle(color: vd.inkMuted, fontSize: 13)),
                if (trailing.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    trailing,
                    style: TextStyle(color: vd.inkFaint, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
