part of 'notice_screens.dart';

class _SentNoticesScreenState extends State<SentNoticesScreen> {
  List<Map<String, dynamic>>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await NoticeApi.sent();
      if (mounted)
        setState(() => _rows = EmsApiService.rows(r['notices'] ?? const []));
    } catch (e) {
      if (mounted) await _fail(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Thông báo đã gửi')),
      body: _rows == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_rows!.isEmpty)
                    Center(
                      child: Text(
                        'Chưa gửi thông báo nào.',
                        style: TextStyle(color: vd.inkMuted),
                      ),
                    ),
                  for (final n in _rows!)
                    Card(
                      elevation: 0,
                      color: vd.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: vd.hairline),
                      ),
                      child: ListTile(
                        title: Text(
                          '${n['body']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_scopeLabel('${n['scope_kind']}')}'
                          '${n['level'] == 'urgent' ? ' · Cần xem ngay' : ''} · ${whenLabel(n['created_at'])}',
                        ),
                        trailing: Text(
                          'đã xem\n${n['seen']}/${n['recipient_count']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: vd.primary,
                          ),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NoticeDetailScreen(id: '${n['id']}'),
                            ),
                          );
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// One notice: the sender sees đã xem x/y, who has not opened it, and can
/// ring those again; a receiver sees the notice and its link.
class NoticeDetailScreen extends StatefulWidget {
  final String id;
  const NoticeDetailScreen({super.key, required this.id});

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  Map<String, dynamic>? _d;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await NoticeApi.one(widget.id);
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) await _fail(context, e);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      final r = await NoticeApi.resend(widget.id);
      if (mounted)
        showSuccessSnack(context, 'Đã nhắc lại ${r['resent']} người chưa xem.');
      await _load();
    } catch (e) {
      if (mounted) await _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openLink(Map n) {
    final id = '${n['link_id']}';
    final w = switch ('${n['link_kind']}') {
      'task' => PieceScreen(taskId: id),
      'space' => NhomScreen(spaceId: id, name: 'Nhóm'),
      _ => null,
    };
    if (w != null)
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final d = _d;
    final n = (d?['notice'] as Map?) ?? const {};
    final mine = d?['mine'] == true;
    final notSeen = ((d?['not_seen'] as List?) ?? const []).cast<Map>();
    final seen = ((d?['seen_people'] as List?) ?? const []).cast<Map>();
    final many = n['scope_kind'] != 'person';
    final canRing = mine && notSeen.isNotEmpty;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Thông báo')),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    mine
                        ? 'Bạn gửi · ${_scopeLabel('${n['scope_kind']}')}'
                        : 'Từ ${n['sender_name'] ?? '—'}',
                    style: TextStyle(color: vd.inkMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    whenLabel(n['created_at']),
                    style: TextStyle(color: vd.inkFaint, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${n['body'] ?? ''}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: vd.ink,
                      height: 1.35,
                    ),
                  ),
                  if (n['link_kind'] != null && n['link_kind'] != 'line') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openLink(n),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        n['link_kind'] == 'task' ? 'Mở việc' : 'Mở nhóm',
                      ),
                    ),
                  ],
                  if (mine) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Đã xem ${n['seen']}/${n['recipient_count']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: vd.primary,
                          ),
                        ),
                        const Spacer(),
                        if (n['level'] == 'urgent')
                          Text(
                            'Cần xem ngay',
                            style: TextStyle(color: vd.warning),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: asInt(n['recipient_count']) == 0
                            ? 0
                            : asInt(n['seen']) / asInt(n['recipient_count']),
                        backgroundColor: vd.surfaceAlt,
                      ),
                    ),
                    if (canRing) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _resend,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: Text(
                          'Nhắc lại ${notSeen.length} người chưa xem',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'CHƯA XEM (${notSeen.length})',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: vd.inkMuted,
                      ),
                    ),
                    for (final p in notSeen)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${p['name'] ?? ''}'),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'ĐÃ XEM (${seen.length})',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: vd.inkMuted,
                      ),
                    ),
                    for (final p in seen)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${p['name'] ?? ''}'),
                        trailing: Text(
                          whenLabel(p['at']),
                          style: TextStyle(color: vd.inkFaint, fontSize: 12),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
