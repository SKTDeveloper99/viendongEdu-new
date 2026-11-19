part of 'small_group_screens.dart';

/// One open piece of mine that a table is for: "Nộp" under the table hands
/// it in (the web's "Nộp" under the row, owner's walk 2026-11-18).
class TablePiece {
  final String assignmentId;
  final String status;
  final String title;

  /// Needs the giver's check: hand in as `submitted`, else `done`.
  final bool review;
  const TablePiece({
    required this.assignmentId,
    required this.status,
    required this.title,
    this.review = true,
  });
}

/// My open pieces on a Nhóm board (`GET /spaces/:id/tasks` rows) that point
/// at [listId]; one per assignment.
List<TablePiece> tablePiecesOf(
  List<Map<String, dynamic>> board,
  String listId,
) {
  final seen = <String>{};
  return [
    for (final r in board)
      if (r['is_mine'] == true &&
          '${r['linked_list_id']}' == listId &&
          const {'assigned', 'in_progress', 'blocked'}.contains(r['status']) &&
          seen.add('${r['assignment_id']}'))
        TablePiece(
          assignmentId: '${r['assignment_id']}',
          status: '${r['status']}',
          title: '${r['title'] ?? ''}',
          review: r['requires_review'] != false,
        ),
  ];
}

/// A column named for the CCCD takes exactly 12 digits (server `setCell`).
bool isCccdColumn(String name) =>
    RegExp(r'\bcccd\b|can cuoc').hasMatch(_foldVi(name));

/// Whose row: the person a person row names, else who added it (the
/// server's `rowOwner`).
String? tableRowOwner(Map r) {
  for (final k in const [
    'person_user_id',
    'owner_user_id',
    'reporter_user_id',
    'created_by',
  ]) {
    final v = r[k];
    if (v != null && '$v'.isNotEmpty) return '$v';
  }
  return null;
}

extension _TableScreenOwnRows on _TableScreenState {
  bool get _ownRows => (_data?['list'] as Map?)?['own_rows_only'] == true;

  bool _isMine(Map r) {
    final me = AppSession.instance.userId;
    return me != null && tableRowOwner(r) == me;
  }

  /// "Thêm dòng của tôi": my own person row in an own-rows table.
  Future<void> _addMyRow() async {
    final me = AppSession.instance.userId;
    if (me == null) return;
    try {
      await SmallGroupApi.addRows(widget.spaceId, widget.listId, [
        {'user_id': me},
      ]);
      await _load();
    } catch (e) {
      if (mounted) await _fail(context, e);
    }
  }

  /// Every column of my row(s) has a value.
  bool get _ownComplete {
    final mine = _rows.where(_isMine).toList();
    if (mine.isEmpty) return false;
    return mine.every(
      (r) => _cols.every((c) {
        final cell = ((r['cells'] as Map?) ?? const {})['${c['id']}'] as Map?;
        return '${cell?['value'] ?? ''}'.trim().isNotEmpty;
      }),
    );
  }

  Widget? _handInBar(VdTokens vd) {
    final open = widget.handIn
        .where((p) => !_handed.contains(p.assignmentId))
        .toList();
    if (_data == null || open.isEmpty) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: vd.surface,
          border: Border(top: BorderSide(color: vd.hairline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _ownComplete
                  ? 'Bạn đã điền đủ. Bấm Nộp để báo người giao việc.'
                  : 'Điền xong dòng của bạn thì bấm Nộp.',
              style: TextStyle(color: vd.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            for (final p in open)
              FilledButton(
                onPressed: _handingIn ? null : () => _handInPiece(p),
                child: Text(
                  _handingIn
                      ? 'Đang nộp…'
                      : (open.length == 1 ? 'Nộp' : 'Nộp: ${p.title}'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handInPiece(TablePiece p) async {
    if (!_ownComplete) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text('Dòng của bạn còn ô trống. Vẫn nộp?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Điền tiếp'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vẫn nộp'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    _set(() => _handingIn = true);
    try {
      if (p.status == 'assigned' || p.status == 'blocked') {
        try {
          await WorkApi.move(p.assignmentId, 'in_progress');
        } on EmsException catch (e) {
          if (e.statusCode != 409) rethrow; // already started
        }
      }
      await WorkApi.move(p.assignmentId, p.review ? 'submitted' : 'done');
      if (!mounted) return;
      _set(() => _handed.add(p.assignmentId));
      showSuccessSnack(context, 'Đã nộp. Người giao việc đã được báo.');
    } catch (e) {
      if (mounted) await _fail(context, e);
    } finally {
      if (mounted) _set(() => _handingIn = false);
    }
  }

  /// "+ Thêm cả nhóm": every member once as a person row, 50 per call.
  Future<void> _addAll() async {
    try {
      final d = await NhomApi.one(widget.spaceId);
      final have = {
        for (final r in _rows)
          if (r['person_user_id'] != null) '${r['person_user_id']}',
      };
      final ids = [
        for (final m in EmsApiService.rows(d['members'] ?? const []))
          if (m['is_active'] != false &&
              m['user_id'] != null &&
              !have.contains('${m['user_id']}'))
            '${m['user_id']}',
      ];
      if (!mounted) return;
      if (ids.isEmpty) {
        showSuccessSnack(context, 'Mọi thành viên đã có trong danh sách.');
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(
            'Thêm ${ids.length} thành viên của nhóm vào danh sách, mỗi người một dòng?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Thôi'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Thêm'),
            ),
          ],
        ),
      );
      if (go != true) return;
      for (var i = 0; i < ids.length; i += 50) {
        await SmallGroupApi.addRows(widget.spaceId, widget.listId, [
          for (final id in ids.skip(i).take(50)) {'user_id': id},
        ]);
      }
      await _load();
    } catch (e) {
      if (mounted) await _fail(context, e);
    }
  }
}
