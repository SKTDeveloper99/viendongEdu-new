part of 'work_home_screen.dart';

extension _WorkHomeScreenStatePart1 on _WorkHomeScreenState {
  AppSession get _s => AppSession.instance;

  bool get _teacher => _s.isGiangVien;

  bool get _staff => _s.isStaff;

  void _onVm() {
    final vm = _vm;
    if (vm != null && vm.unauthorized && !_authHandled && mounted) {
      _authHandled = true;
      handleCrmAuthError(context, vm.authError!);
    }
  }

  Future<void> _refresh() async {
    unawaited(_refreshMine());
    try {
      final me = await AppMeApi.me();
      // Older installs: fill the stored identity from the server and keep it.
      if (_s.applyAppMe(me)) unawaited(_s.persist());
      if (mounted) _set(() => _me = me);
    } on EmsException catch (e) {
      if (mounted && e.statusCode == 401) handleCrmAuthError(context, e);
    } catch (_) {}
    if (_teacher) {
      try {
        final n = await TeacherConversationsApi.unreadCount();
        if (mounted) _set(() => _messages = n);
      } catch (_) {}
    }
  }

  Future<void> _refreshMine() async {
    try {
      final mine = await WorkApi.received();
      if (mounted) _set(() => _mine = mine);
    } catch (_) {
      // The server's own counts stay on the home.
    }
  }

  Future<void> _go(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  Future<void> _goNamed(String route) async {
    await Navigator.pushNamed(context, route);
    _refresh();
  }

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

  Map<String, dynamic> get _can =>
      ((_me?['can'] as Map?) ?? const {}).cast<String, dynamic>();

  int _c(String k) => asInt(_counts?[k]);

  Map<String, dynamic>? get _dayCard =>
      (_me?['day_card'] as Map?)?.cast<String, dynamic>();

  String get _name {
    final vmName = _vm?.displayName;
    if (vmName != null && vmName != '–' && vmName.isNotEmpty) return vmName;
    return _s.fullName ?? '';
  }

  List<String> get _chips => [
    if (_teacher && _vm != null && _vm!.teacherCode != '–')
      'Mã GV: ${_vm!.teacherCode}',
    if (_teacher && _vm?.profile?.isCoHuu == true) 'Cơ hữu',
    if (_staff) 'Văn phòng',
  ];

  // A class in progress or starting within 90 minutes wins the focus card.
  bool _classWins(NextUp n) =>
      n.entry != null &&
      (n.phase == NextUpPhase.ongoing ||
          (n.phase == NextUpPhase.upcoming && n.minutes <= 90));

  String _classLine(NextUp n) => n.entry == null
      ? ''
      : '${n.statusLabel}: ${n.entry!.subject} · ${n.countdown}';

  Future<void> _openWork() async {
    // Việc opens on the tab that waits on the person.
    final tab = _c('to_review') > 0 ? 1 : 0;
    await _go(MyWorkScreen(initialTab: tab));
  }

  Future<void> _openLich() async {
    final vm = _vm;
    if (vm == null) {
      await openWeekPage(context);
      _refresh();
      return;
    }
    final last = _staff ? await HomePrefs.lichLast() : 'teach';
    if (!mounted) return;
    await _go(LichScreen(vm: vm, openWeekFirst: last == 'week'));
  }

  List<HomeTileSpec> get _tiles {
    final lookup = _can['student_lookup'] == true;
    return [
      HomeTileSpec(
        Icons.task_alt,
        'Việc',
        badge: _c('to_review') + _c('received_open'),
        onTap: _openWork,
      ),
      HomeTileSpec(
        Icons.groups_2_outlined,
        'Nhóm',
        onTap: () => _go(const NhomListScreen()),
      ),
      HomeTileSpec(Icons.event_note, 'Lịch', onTap: _openLich),
      if (_teacher)
        HomeTileSpec(
          Icons.class_outlined,
          'Lớp',
          onTap: () => _go(LopScreen(vm: _vm!, studentLookup: lookup)),
        )
      else if (lookup)
        HomeTileSpec(
          Icons.person_search_outlined,
          'Sinh viên',
          onTap: () => _goNamed(const CrmTarget.students().routeName),
        ),
      HomeTileSpec(
        Icons.business_center_outlined,
        'Văn phòng',
        onTap: () => _go(VanPhongScreen(congVan: _can['cong_van'] == true)),
      ),
      HomeTileSpec(
        Icons.more_horiz,
        'Thêm',
        onTap: () => _go(const ThemScreen()),
      ),
    ];
  }

  Widget _focus() {
    final vm = _vm;
    final office = OfficeFocusCard(
      counts: _counts,
      onReview: () => _go(const MyWorkScreen(initialTab: 1)),
      onPiece: (id) => _go(PieceScreen(taskId: id)),
    );
    if (vm == null) return office;
    if (vm.scheduleLoading && !vm.scheduleFailed) {
      return const FocusSkeleton();
    }
    final next = vm.upNext;
    final e = next.entry;
    final classCard = e == null
        ? const CalmFocusCard(
            text: teacherNextUpEmpty,
            icon: Icons.event_available,
          )
        : CompactFocusCard(
            chip: next.statusLabel,
            live: next.phase == NextUpPhase.ongoing,
            right: next.countdown,
            title: e.subject,
            line: [
              next.timeRange,
              if (e.room.isNotEmpty) e.room,
              if (e.classCode.isNotEmpty) e.classCode,
            ].join(' · '),
            action: 'Điểm danh',
            onAction: () => _goNamed('/ems_attendance_gv'),
          );
    if (!_staff) return classCard;
    return _classWins(next) ? classCard : office;
  }

  String? _status() {
    final vm = _vm;
    if (vm != null && _staff) {
      // The one that lost the focus card becomes the status line.
      final next = vm.upNext;
      if (_classWins(next)) return OfficeFocusCard.statusOf(_counts);
      return next.entry == null ? null : _classLine(next);
    }
    if (_counts == null) return null;
    final waiting = _c('received_open');
    return waiting > 0 ? '$waiting việc đang chờ bạn' : null;
  }

  Widget _homeBody() {
    return Column(
      children: [
        HomeHeaderBar(
          now: _vm?.now ?? DateTime.now(),
          name: _name,
          chips: _chips,
          status: _status(),
          unreadCount: _c('bell_work_unread'),
          onBell: () => _go(const BellScreen()),
          actions: [
            if (_teacher)
              HeaderRoundButton(
                icon: Icons.chat_bubble_outline,
                badge: _messages,
                label: 'Tin nhắn',
                onTap: () => _goNamed('/teacher_conversations'),
              ),
          ],
        ),
        // Tight: focus card, one action and the places fill the screen; the
        // tiles take the height that is left (no empty band on a tall phone,
        // no scrolling on 360 × 640 dp). Pull to refresh still works.
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _refresh(),
                  if (_vm != null) _vm!.loadOverview(),
                ]);
              },
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    // On the day of a greeting a small phone may scroll a
                    // little rather than squeeze the places below their
                    // smallest size; the focus card stays on screen.
                    height: _dayCard == null
                        ? box.maxHeight
                        : math.max(box.maxHeight, 520.0),
                    child: Column(
                      children: [
                        // A greeting on the day the server names; nothing
                        // on other days (lib/features/work_home/day_card.dart).
                        DayCardSlot(card: _dayCard),
                        _focus(),
                        _createAction(),
                        Expanded(child: _placesAndNext()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tight home: on a small phone the tiles take what is left (no scrolling);
  /// on a tall phone the spare height lists what comes next instead of
  /// stretching the tiles or leaving an empty band.
  Widget _placesAndNext() {
    final tiles = _tiles;
    final rows = tiles.length >= 5 ? 2 : (tiles.length / 2).ceil();
    // The piece the office focus card already shows is not listed twice;
    // when the class card holds the focus (a teacher), nothing is left out.
    final vm = _vm;
    final officeShown = vm == null || (_staff && !_classWins(vm.upNext));
    final shown = !officeShown
        ? ''
        : '${(_counts?['first_review'] as Map?)?['task_id'] ?? (_counts?['next_due'] as Map?)?['task_id'] ?? ''}';
    final next = ((_counts?['queue'] as List?) ?? const [])
        .cast<Map>()
        .where((q) => '${q['task_id']}' != shown)
        .toList();
    // Owner 2026-11-17 ("make it look good, no hard laws"): Tiếp theo rows
    // where there is room (never crowding the tiles, at most four), tiles a
    // little taller when the phone is tall, and any space left sits above the
    // tiles so they stay by the thumb and no band opens under them.
    return LayoutBuilder(
      builder: (context, box) {
        const rowH = 52.0;
        const headH = 30.0;
        const gap = 12.0;
        const pad = EdgeInsets.fromLTRB(16, 16, 16, 16);
        final grid = rows * homeTileHeight + gap * (rows - 1);
        final room = box.maxHeight - grid - pad.vertical;
        final int n = homeShowsNextList && room >= headH + rowH + 8
            ? ((room - headH - 8) / rowH)
                  .floor()
                  .clamp(0, math.min(next.length, 4))
                  .toInt()
            : 0;
        return Column(
          children: [
            if (n > 0)
              NextList(
                items: next.take(n).toList(),
                onOpen: (id) => _go(PieceScreen(taskId: id)),
              ),
            // The tiles take their height from what is really left: up to
            // homeTileHeightTall, anchored at the bottom by the thumb.
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final h = rows == 0
                      ? homeTileHeight
                      : ((c.maxHeight - pad.vertical - gap * (rows - 1)) / rows)
                            .clamp(64.0, homeTileHeightTall);
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: pad,
                      child: SizedBox(
                        height: rows * h + gap * (rows - 1),
                        child: HomeTileGrid(tiles: tiles, maxTileHeight: h),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// "+ Tạo": Giao việc and Gửi thông báo, each only if the person may do it;
  /// with one choice the button does that one thing and carries its name.
  Widget _createAction() {
    final canGive = _can['give_work'] == true;
    final canNotice = _teacher || _staff;
    final choices = <(IconData, String, VoidCallback)>[
      if (canGive)
        (Icons.task_alt, 'Giao việc', () => _go(const GiveTaskScreen())),
      if (canNotice)
        (
          Icons.campaign_outlined,
          'Gửi thông báo',
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
          label: Text(one ? choices.first.$2 : 'Tạo'),
        ),
      ),
    );
  }

  String get _kindsLabel =>
      [if (_teacher) 'Giảng viên', if (_staff) 'Văn phòng'].join(' · ');
}
