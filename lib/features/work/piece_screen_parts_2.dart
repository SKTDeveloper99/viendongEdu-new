part of 'piece_screen.dart';

extension _PieceScreenStatePart2 on _PieceScreenState {
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
}
