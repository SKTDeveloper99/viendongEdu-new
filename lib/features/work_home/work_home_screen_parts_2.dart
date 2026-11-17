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
    if (_vm != null) {
      await _vm!.logout();
    } else {
      await _s.clear();
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }
}
