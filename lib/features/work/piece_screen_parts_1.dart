part of 'piece_screen.dart';

extension _PieceScreenStatePart1 on _PieceScreenState {
  String? get _me => AppSession.instance.userId;

  String? get _myTeacherId => AppSession.instance.teacherId;

  Future<void> _load() async {
    try {
      final t = await WorkApi.task(widget.taskId);
      final c = await WorkApi.comments(
        widget.taskId,
      ).catchError((_) => <Map<String, dynamic>>[]);
      if (mounted)
        _set(() {
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
      _set(() => _error = e.message);
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

  Future<void> _action(
    String key,
    Future<void> Function() fn, {
    String? leave,
  }) async {
    _set(() {
      _act[key] = 'busy';
      _retry[key] = () => _action(key, fn, leave: leave);
    });
    try {
      await fn();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _set(() => _act[key] = 'done');
      final m = VdMotion.of(context);
      await Future.delayed(
        m.reduced ? Duration.zero : const Duration(milliseconds: 450),
      );
      if (!mounted) return;
      if (leave != null) {
        _set(() => _leaving.add(leave));
        await Future.delayed(m.standard);
      }
      if (!mounted) return;
      await _load();
      if (mounted)
        _set(() {
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
      _set(() => _act[key] = e.message);
    } catch (_) {
      if (mounted) _set(() => _act[key] = 'Không kết nối được máy chủ.');
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
    _set(() => _busy = true);
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
      if (mounted) _set(() => _busy = false);
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
    final r = await showHandInSheet(context);
    if (r == null) return;
    final note = r.note;
    final to = _task?['requires_review'] == true ? 'submitted' : 'done';
    await _action('handin:${a['id']}', () async {
      // Start first: the server itself moves an unopened part to in_progress
      // when a file arrives, so starting after the upload was refused
      // ("đã ở trạng thái này") and the hand-in never went (seen 17/11).
      if (a['status'] == 'assigned')
        await WorkApi.move('${a['id']}', 'in_progress');
      // Then the files, as the web sends them, so the hand-in carries them.
      for (final f in r.files) {
        await WorkApi.attach(
          widget.taskId,
          '${a['id']}',
          f.path,
          filename: f.name,
        );
      }
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
}
