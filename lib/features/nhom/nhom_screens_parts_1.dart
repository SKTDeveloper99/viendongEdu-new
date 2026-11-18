part of 'nhom_screens.dart';

extension _NhomScreenStatePart1 on _NhomScreenState {
  Future<void> _load() async {
    try {
      final r = await Future.wait([
        NhomApi.one(widget.spaceId),
        NhomApi.feed(widget.spaceId),
        NhomApi.work(widget.spaceId),
        SmallGroupApi.lists(
          widget.spaceId,
        ).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      _set(() {
        _one = r[0] as Map<String, dynamic>;
        _feed = r[1] as List<Map<String, dynamic>>;
        _work = r[2] as List<Map<String, dynamic>>;
        _lists = r[3] as List<Map<String, dynamic>>;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        await _guard(context, e, (m) {
          if (_one == null) {
            _set(() => _error = m);
          } else {
            showErrorSnack(context, m);
          }
        });
      }
    }
  }

  List<Map<String, dynamic>> get _members =>
      ((_one?['members'] as List?) ?? const []).cast<Map<String, dynamic>>();

  Future<void> _post() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty || _posting) return;
    _set(() => _posting = true);
    try {
      final r = await NhomApi.post(widget.spaceId, text, urgent: false);
      _postCtrl.clear();
      if (mounted) {
        showSuccessSnack(
          context,
          r['urgent_error'] != null
              ? 'Đã đăng; chưa đổ chuông: ${r['urgent_error']}'
              : (_postUrgent ? 'Đã đăng và đổ chuông cả nhóm.' : 'Đã đăng.'),
        );
        _set(() => _postUrgent = false);
      }
      await _load();
    } catch (e) {
      if (mounted) await _guard(context, e, (m) => showErrorSnack(context, m));
    } finally {
      if (mounted) _set(() => _posting = false);
    }
  }

  Future<void> _give() async {
    final me = AppSession.instance.userId;
    final people = _members
        .where((m) => '${m['user_id']}' != me && m['can_receive_task'] != false)
        .toList();
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GiveWorkScreen(
          spaceId: widget.spaceId,
          people: people,
          lists: _lists,
        ),
      ),
    );
    if (done == true) await _load();
  }

  Widget _feedTab(VdTokens vd) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _postCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Viết cho cả nhóm…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _posting ? null : _post,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
        // A post rings every other member (bell row and banner).
        Row(
          children: [
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NoticeComposeScreen(
                    preset: {
                      'kind': 'space',
                      'id': widget.spaceId,
                      'name': widget.name,
                    },
                  ),
                ),
              ),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Gửi thông báo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_feed.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Chưa có tin nào.',
                style: TextStyle(color: vd.inkMuted),
              ),
            ),
          ),
        for (final p in _feed)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
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
                  '${p['author_name'] ?? ''} · ${whenLabel(p['created_at'])}',
                  style: TextStyle(color: vd.inkMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text('${p['body'] ?? ''}', style: TextStyle(color: vd.ink)),
                if (p['task_id'] != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: Text(
                      '${p['task_title'] ?? 'Mở việc'} · ${p['task_done_count'] ?? 0}/${p['task_assignee_count'] ?? 0}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _openPiece('${p['task_id']}'),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );

  Future<void> _openPiece(String taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PieceScreen(taskId: taskId)),
    );
    _load();
  }

  Widget _workTab(VdTokens vd) {
    final byTask = <String, List<Map<String, dynamic>>>{};
    for (final a in _work) {
      byTask.putIfAbsent('${a['task_id']}', () => []).add(a);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (byTask.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Chưa có việc nào trong nhóm.',
                  style: TextStyle(color: vd.inkMuted),
                ),
              ),
            ),
          for (final e in byTask.entries)
            Card(
              elevation: 0,
              color: vd.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: vd.hairline),
              ),
              child: ListTile(
                title: Text(
                  '${e.value.first['title'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    'Giao bởi ${e.value.first['giver_name'] ?? '—'}',
                    '${e.value.where((a) => a['status'] == 'done').length}/${e.value.length} xong',
                    if (dueLabel(e.value.first['due_at']).isNotEmpty)
                      dueLabel(e.value.first['due_at']),
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openPiece(e.key),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> get _space =>
      ((_one?['space'] as Map?) ?? const {}).cast<String, dynamic>();

  bool get _isHead => ((_one?['me'] as Map?)?['is_lead']) == true;

  bool get _temporary =>
      _space['kept_at'] == null &&
      (_space['is_temporary'] == true ||
          _space['source_task_id'] != null ||
          _space['calendar_line_id'] != null);

  Widget _keepBanner(VdTokens vd) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: vd.warningSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.timelapse, color: vd.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _space['source_task_id'] != null
                ? 'Nhóm tạm của một việc: tự đóng khi việc xong.'
                : 'Nhóm tạm: tự đóng khi mọi việc trong nhóm xong.',
            style: TextStyle(color: vd.ink, fontSize: 13),
          ),
        ),
        if (_isHead)
          TextButton(
            onPressed: () async {
              try {
                await SmallGroupApi.keep(widget.spaceId);
                if (mounted) {
                  showSuccessSnack(
                    context,
                    'Đã giữ nhóm. Nhóm không tự đóng nữa.',
                  );
                }
                await _load();
              } catch (e) {
                if (mounted) {
                  await _guard(context, e, (m) => showErrorSnack(context, m));
                }
              }
            },
            child: const Text('Giữ nhóm này'),
          ),
      ],
    ),
  );

  Future<void> _newList() async {
    final ctrl = TextEditingController();
    var ownRows = false;
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Danh sách mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên danh sách'),
              ),
              const SizedBox(height: 8),
              // Proposed LAW T-58: chosen once, when the table is made.
              CheckboxListTile(
                value: ownRows,
                onChanged: (v) => setInner(() => ownRows = v == true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Mỗi người chỉ thấy và điền dòng của mình'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Thôi'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
    if (title == null || title.isEmpty) return;
    try {
      final r = await SmallGroupApi.createList(
        widget.spaceId,
        title,
        ownRowsOnly: ownRows,
      );
      final id = (r['list'] as Map?)?['id']?.toString();
      await _load();
      if (id != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TableScreen(spaceId: widget.spaceId, listId: id, title: title),
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) await _guard(context, e, (m) => showErrorSnack(context, m));
    }
  }
}
