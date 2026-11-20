part of 'work_home_screen.dart';

extension _WorkHomeScreenStatePart2 on _WorkHomeScreenState {
  Widget _profile() {
    final code = _vm != null && _vm!.teacherCode != '–'
        ? 'Mã GV ${_vm!.teacherCode} · $_kindsLabel'
        : _kindsLabel;
    final tab = ProfileTab(
      name: _name,
      code: code,
      onOpenInfo: _teacher
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GvProfileInfoScreen(
                  profile: _vm?.profile,
                  fallbackName: _name,
                  teacherCode: _vm?.teacherCode ?? '',
                ),
              ),
            )
          : null,
      onLogout: _logout,
    );
    return tab;
  }

  Future<void> _logout() async {
    // One tap is enough: a second tap while signing out does nothing.
    if (_signingOut) return;
    _signingOut = true;
    await HomePrefs.setHomeSpec(null);
    if (_vm != null) {
      await _vm!.logout();
    } else {
      await _s.clear();
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }
}

extension _WorkHomeCounts on _WorkHomeScreenState {
  Map<String, dynamic>? get _counts {
    final c = (_me?['counts'] as Map?)?.cast<String, dynamic>();
    final mine = _mine;
    if (c == null || mine == null) return c;
    // "Tiếp theo" and the focus card: the nearest deadline, never a part
    // that is already locked (the server orders by the oldest deadline).
    final next = nextDue(mine);
    final dueRows = [
      for (final a in next.where((a) => a['due_at'] != null).take(5))
        {
          'kind': 'due',
          'task_id': a['task_id'],
          'title': a['title'],
          'due_at': a['due_at'],
          'at': a['due_at'],
        },
    ];
    final reviews = ((c['queue'] as List?) ?? const []).cast<Map>().where(
      (q) => q['kind'] == 'review',
    );
    return {
      ...c,
      'received_open': stillOpen(mine).length,
      'next_due': dueRows.isEmpty ? null : dueRows.first,
      'queue': [...reviews, ...dueRows].take(6).toList(),
    };
  }
}
