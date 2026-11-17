part of 'staff_home_screen.dart';

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  Map<String, dynamic>? _counts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await AppMeApi.me();
      if (mounted) {
        setState(
          () => _counts = (me['counts'] as Map?)?.cast<String, dynamic>(),
        );
      }
    } on EmsException catch (e) {
      if (mounted && e.statusCode == 401) handleCrmAuthError(context, e);
    }
  }

  Future<void> _logout() async {
    await AppSession.instance.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final name = AppSession.instance.fullName ?? '';
    final c = _counts;
    int n(String k) => c == null
        ? 0
        : (c[k] is int ? c[k] as int : int.tryParse('${c[k]}') ?? 0);
    final tiles = staffTiles(context, c, refresh: _load);
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: const Text('Hôm nay'),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BellScreen()),
              );
              _load();
            },
            icon: Badge(
              isLabelVisible: n('bell_work_unread') > 0,
              label: Text('${n('bell_work_unread')}'),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'pw') Navigator.pushNamed(context, '/change_password');
              if (v == 'out') _logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pw', child: Text('Đổi mật khẩu')),
              PopupMenuItem(value: 'out', child: Text('Đăng xuất')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Chào $name',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: vd.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              c == null
                  ? 'Đang tải…'
                  : '${n('to_review')} bài nộp chờ duyệt · ${n('received_open')} việc đang chờ bạn',
              style: TextStyle(color: vd.inkMuted),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [for (final t in tiles) StaffTileView(t)],
            ),
          ],
        ),
      ),
    );
  }
}
