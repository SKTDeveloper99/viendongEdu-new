part of 'piece_screen.dart';

extension _PieceScreenStatePart3 on _PieceScreenState {
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
          // My own handed-in files, so I can open what I sent.
          for (final f in _myFiles(a)) _fileRow(vd, f),
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

  /// Files on my part: from the part itself, else the piece's files tagged
  /// with my part's id (a receiver's view may carry them either way).
  List<Map> _myFiles(Map<String, dynamic> a) {
    final seen = <String>{};
    return [
      ...((a['attachments'] as List?) ?? const []),
      ...((_task?['attachments'] as List?) ?? const []).where(
        (f) => '${(f as Map)['assignment_id']}' == '${a['id']}',
      ),
    ].cast<Map>().where((f) => seen.add('${f['id']}')).toList();
  }
}
