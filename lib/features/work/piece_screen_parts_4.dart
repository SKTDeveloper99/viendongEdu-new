part of 'piece_screen.dart';

/// Handing in: the short note, the report sheet (word and photo minimums)
/// and the way back to my row when a linked table is still empty.
extension _PieceScreenStatePart4 on _PieceScreenState {
  /// The Nhóm table this piece is filled in (proposed LAW T-60), if any.
  String? get _linkedListId {
    final meta = _task?['title_meta'];
    final id = meta is Map ? meta['for_list_id'] : null;
    return id == null || _task?['space_id'] == null ? null : '$id';
  }

  /// The server refused a hand-in because my row in the linked table is
  /// empty: open that table on my row, with Nộp under it.
  Future<void> _openMyRow(Map<String, dynamic> a) async {
    final listId = _linkedListId;
    if (listId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TableScreen(
          spaceId: '${_task!['space_id']}',
          listId: listId,
          title: '${_task?['title'] ?? ''}',
          handIn: [
            TablePiece(
              assignmentId: '${a['id']}',
              status: '${a['status']}',
              title: '${_task?['title'] ?? ''}',
              review: _task?['requires_review'] != false,
            ),
          ],
        ),
      ),
    );
    _act.remove('handin:${a['id']}');
    await _load();
  }

  Future<void> _handIn(Map<String, dynamic> a) async {
    final aid = '${a['id']}';
    final ReportRule rule;
    try {
      rule = await WorkApi.ruleFor(_task ?? const {}, aid);
    } on EmsException catch (e) {
      if (mounted) handleCrmAuthError(context, e);
      return;
    }
    if (!mounted) return;
    if (rule.needsReportSheet) return _handInReport(a, rule);
    final r = await showHandInSheet(context, pickPhotos: widget.pickPhotos);
    if (r == null) return;
    final note = r.note;
    final to = _task?['requires_review'] == true ? 'submitted' : 'done';
    final key = 'handin:${a['id']}';
    // Files already sent survive a "Thử lại": only what failed goes again.
    final up = HandInUploads(r.files);
    _line(key, null);
    await _action(key, () async {
      try {
        // Start first: the server itself moves an unopened part to
        // in_progress when a file arrives, so starting after the upload was
        // refused ("đã ở trạng thái này") and the hand-in never went (17/11).
        if (a['status'] == 'assigned') {
          try {
            await WorkApi.move('${a['id']}', 'in_progress');
          } on EmsException catch (e) {
            // 409 "đã ở trạng thái này": already started (an earlier
            // attempt, or the server on a file upload) — carry on.
            if (e.statusCode != 409) rethrow;
          }
        }
        // Then the files, as the web sends them, so the hand-in carries them.
        await up.sendRest(
          (f, onStatus) async => WorkApi.attach(
            widget.taskId,
            '${a['id']}',
            await f.read(),
            filename: f.name,
            onStatus: onStatus,
          ),
          onLine: (l) => _line(key, l),
        );
        _line(key, null);
        await WorkApi.move('${a['id']}', to, note: note);
      } catch (_) {
        _line(key, up.keptLine);
        rethrow;
      }
    });
  }

  /// A duty report (or a piece with a word or photo minimum): the long text
  /// and the photos go in ONE request, as the web's report form sends them;
  /// the server checks the minimums and hands the part in.
  Future<void> _handInReport(Map<String, dynamic> a, ReportRule rule) async {
    final aid = '${a['id']}';
    final onPart = _myFiles(a)
        .where(
          (f) =>
              '${f['mime_type'] ?? ''}'.startsWith('image/') ||
              RegExp(
                r'\.(jpe?g|png|webp|heic|heif)$',
                caseSensitive: false,
              ).hasMatch('${f['filename'] ?? ''}'),
        )
        .length;
    final r = await showReportSheet(
      context,
      assignmentId: aid,
      rule: rule,
      photosOnPart: onPart,
      pickPhotos: widget.pickPhotos,
      pickFiles: rule.isReport ? null : pickFilesForHandIn,
    );
    if (r == null) return;
    final key = 'handin:$aid';
    // One request (the server checks the minimums on all of it together).
    void status(UploadStatus s) => _line(key, s.text);
    await _action(key, () async {
      try {
        final files = [
          for (final f in r.files) (bytes: await f.read(), filename: f.name),
        ];
        if (rule.isReport) {
          await WorkApi.submitReport(
            aid,
            note: r.note,
            photos: files,
            onStatus: status,
          );
        } else {
          await WorkApi.submitWithNote(
            aid,
            note: r.note,
            files: files,
            onStatus: status,
          );
        }
        forgetReportDraft(aid);
      } finally {
        _line(key, null);
      }
    });
  }
}
