part of 'work_home_screen.dart';

/// Server-led home (proposed P-50): the tiles, the Văn phòng and Thêm rows
/// and the button words come from `home` in `/app/me`; without it (an older
/// server, `APP_HOME_SERVER=off`, nothing usable) the built-in home stays.
extension _WorkHomeServerLed on _WorkHomeScreenState {
  /// The spec in force: the fresh answer, else the last one this account got.
  HomeSpec? get _spec => _serverSpec ?? _cachedSpec;

  Future<void> _loadCachedSpec() async {
    final stored = await HomePrefs.homeSpec();
    final spec = HomeSpec.fromCache(
      stored,
      userId: _s.userId,
      teacher: _teacher,
    );
    if (mounted && spec != null && _serverSpec == null) {
      _set(() => _cachedSpec = spec);
    }
  }

  /// After every `/app/me`: the new spec (or none) wins and is kept.
  void _takeSpec(Map<String, dynamic> me) {
    final raw = me['home'];
    final spec = HomeSpec.parse(raw, teacher: _teacher);
    _serverSpec = spec;
    if (spec == null) _cachedSpec = null;
    final id = _s.userId;
    unawaited(
      HomePrefs.setHomeSpec(
        spec == null || id == null || id.isEmpty ? null : spec.toCache(id),
      ),
    );
  }

  String _word(String key, String fallback) =>
      _spec?.word(key, fallback) ?? fallback;

  int _badge(String? kind) => switch (kind) {
    'work' => _c('to_review') + _c('received_open'),
    'review' => _c('to_review'),
    'bell' => _c('bell_work_unread'),
    _ => 0,
  };

  List<HomeTileSpec>? get _specTiles {
    final spec = _spec;
    if (spec == null) return null;
    return [
      for (final t in spec.tiles)
        HomeTileSpec(
          homeIcon(t.icon),
          t.label,
          badge: _badge(t.badge),
          onTap: () => _openItem(t),
        ),
    ];
  }

  Future<void> _openItem(HomeItem item) async {
    final o = item.open;
    switch (o) {
      case WebOpen(:final path):
        final target = CrmTarget.page(path, label: item.label);
        if (target == null) return;
        await Navigator.pushNamed(
          context,
          target.routeName,
          arguments: item.label,
        );
        _refresh();
      case AppOpen(:final name):
        await _openApp(name);
    }
  }

  Future<void> _openApp(String name) async {
    final vm = _vm;
    final lookup = _can['student_lookup'] == true;
    switch (name) {
      case 'viec':
        await _openWork();
      case 'nhom':
        await _go(const NhomListScreen());
      case 'lich':
        await _openLich();
      case 'lop':
        if (vm != null) await _go(LopScreen(vm: vm, studentLookup: lookup));
      case 'van_phong':
        await _go(
          VanPhongScreen(
            congVan: _can['cong_van'] == true,
            page: _spec?.pages['van_phong'],
            onOpen: _openItem,
          ),
        );
      case 'them':
        await _go(ThemScreen(page: _spec?.pages['them'], onOpen: _openItem));
      case 'sent_notices':
        await _go(const SentNoticesScreen());
      case 'give_work':
        await _go(const GiveTaskScreen());
      case 'notice':
        await _go(const NoticeComposeScreen());
      case 'bell':
        await _go(const BellScreen());
      default:
        final route = _teacherRoutes[name];
        if (route != null && _teacher) await _goNamed(route);
    }
  }

  static const _teacherRoutes = {
    'attendance': '/ems_attendance_gv',
    'gv_schedule': '/gv_schedule',
    'lich_thi': '/gv_lichthi',
    'danh_sach_thi': '/gv_danh_sach_thi',
    'my_classes': '/gv_quanly_lop',
    'my_students': '/gv_sinh_vien',
    'messages': '/teacher_conversations',
  };

  /// "+ Tạo": Giao việc and Gửi thông báo, each only if the person may do it;
  /// with one choice the button does that one thing and carries its name.
  Widget _createAction() {
    final canGive = _can['give_work'] == true;
    final canNotice = _teacher || _staff;
    final choices = <(IconData, String, VoidCallback)>[
      if (canGive)
        (
          Icons.task_alt,
          _word('give_work', 'Giao việc'),
          () => _go(const GiveTaskScreen()),
        ),
      if (canNotice)
        (
          Icons.campaign_outlined,
          _word('send_notice', 'Gửi thông báo'),
          () => _go(const NoticeComposeScreen()),
        ),
    ];
    if (choices.isEmpty) return const SizedBox(height: 4);
    final one = choices.length == 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          onPressed: one
              ? choices.first.$3
              : () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in choices)
                          ListTile(
                            leading: Icon(c.$1),
                            title: Text(c.$2),
                            onTap: () {
                              Navigator.pop(ctx);
                              c.$3();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
          icon: Icon(one ? choices.first.$1 : Icons.add),
          label: Text(one ? choices.first.$2 : _word('create', 'Tạo')),
        ),
      ),
    );
  }
}
