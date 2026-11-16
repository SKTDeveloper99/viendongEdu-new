import 'package:flutter/material.dart';

import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../nhom/nhom_screens.dart';
import '../nhom/small_group_screens.dart' show PeoplePicker;
import '../work/piece_screen.dart';
import '../work/work_api.dart';

/// "Gửi thông báo" (Overlord; server `routes/notices.js`). One sentence to one
/// person (always a phone banner) or to a place: a Nhóm, a calendar line, a
/// khoa, up to 20 picked people, or the whole school for admin/vice admin.
/// To many, "Thường" rings nobody (bell and badge only); "Cần xem ngay" is a
/// banner, chosen on purpose, with a daily cap the server sets.
abstract final class NoticeApi {
  static Future<Map<String, dynamic>> targets() =>
      EmsApiService.sendMap('GET', '/notices/targets');
  static Future<Map<String, dynamic>> send(Map<String, dynamic> body) =>
      EmsApiService.sendMap('POST', '/notices', body: body);
  static Future<Map<String, dynamic>> sent() =>
      EmsApiService.sendMap('GET', '/notices/sent');
  static Future<Map<String, dynamic>> one(String id) =>
      EmsApiService.sendMap('GET', '/notices/$id');
  static Future<Map<String, dynamic>> resend(String id) =>
      EmsApiService.sendMap('POST', '/notices/$id/resend');
}

Future<void> _fail(BuildContext context, Object e) async {
  if (e is EmsException && e.statusCode == 401) {
    await handleCrmAuthError(context, e);
    return;
  }
  if (context.mounted)
    showErrorSnack(
      context,
      e is EmsException ? e.message : 'Không kết nối được máy chủ.',
    );
}

String _scopeLabel(String? k) => switch (k) {
  'person' => 'Một người',
  'people' => 'Chọn người',
  'space' => 'Nhóm',
  'line' => 'Dòng lịch',
  'khoa' => 'Khoa',
  'school' => 'Toàn trường',
  _ => '',
};

class NoticeComposeScreen extends StatefulWidget {
  /// Preset place (e.g. from a Nhóm): {'kind': 'space', 'id': …, 'name': …}.
  final Map<String, String>? preset;
  const NoticeComposeScreen({super.key, this.preset});

  @override
  State<NoticeComposeScreen> createState() => _NoticeComposeScreenState();
}

class _NoticeComposeScreenState extends State<NoticeComposeScreen> {
  Map<String, dynamic>? _t;
  String _kind = 'person';
  String? _placeId;
  String? _placeName;
  Map<String, String> _people = {};
  bool _urgent = false;
  bool _busy = false;
  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    if (p != null) {
      _kind = p['kind'] ?? 'person';
      _placeId = p['id'];
      _placeName = p['name'];
    }
    NoticeApi.targets()
        .then((t) {
          if (mounted) setState(() => _t = t);
        })
        .catchError((e) async {
          if (mounted) await _fail(context, e);
        });
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  bool get _many => _kind != 'person';
  int get _urgentLeft => asInt(_t?['urgent_left_today']);

  List<Map<String, dynamic>> _list(String k) =>
      ((_t?[k] as List?) ?? const []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get _to => switch (_kind) {
    'person' =>
      _people.isEmpty ? null : {'kind': 'person', 'id': _people.keys.first},
    'people' =>
      _people.isEmpty ? null : {'kind': 'people', 'ids': _people.keys.toList()},
    'school' => {'kind': 'school'},
    _ => _placeId == null ? null : {'kind': _kind, 'id': _placeId},
  };

  Future<void> _send({int? confirm}) async {
    final to = _to;
    if (to == null || _body.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await NoticeApi.send({
        'body': _body.text.trim(),
        'to': to,
        if (_many) 'level': _urgent ? 'urgent' : 'normal',
        'confirm_count': ?confirm,
      });
      if (!mounted) return;
      final n = (r['notice'] as Map?) ?? const {};
      final skipped = asInt(r['skipped']);
      showSuccessSnack(
        context,
        'Đã gửi cho ${n['recipient_count']} người'
        '${skipped > 0 ? ' ($skipped người ngoài phạm vi bạn được gửi)' : ''}.',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NoticeDetailScreen(id: '${n['id']}')),
      );
    } on EmsException catch (e) {
      if (!mounted) return;
      if (e.code == 'confirm_count' ||
          (e.statusCode == 409 && e.message.startsWith('Gửi cho'))) {
        final count =
            int.tryParse(
              RegExp(r'\d+').firstMatch(e.message)?.group(0) ?? '',
            ) ??
            0;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(e.message),
            content: Text(
              _urgent
                  ? 'Mỗi người sẽ nhận chuông trên điện thoại.'
                  : 'Mỗi người thấy trong mục Thông báo; điện thoại không đổ chuông.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Thôi'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Gửi cho $count người'),
              ),
            ],
          ),
        );
        if (ok == true) {
          setState(() => _busy = false);
          await _send(confirm: count);
          return;
        }
      } else {
        await _fail(context, e);
      }
    } catch (e) {
      if (mounted) await _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPlace() async {
    final items = switch (_kind) {
      'space' =>
        _list('spaces')
            .map((s) => ('${s['id']}', '${s['name']}', '${s['members']} người'))
            .toList(),
      'line' =>
        _list('lines')
            .map(
              (l) => (
                '${l['id']}',
                '${l['content']}',
                '${l['day'] ?? ''}'.split('T').first,
              ),
            )
            .toList(),
      'khoa' =>
        _list('khoa')
            .map((k) => ('${k['id']}', '${k['name']}', '${k['people']} người'))
            .toList(),
      _ => <(String, String, String)>[],
    };
    final r = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              if (items.isEmpty)
                const ListTile(title: Text('Không có mục nào.')),
              for (final i in items)
                ListTile(
                  title: Text(
                    i.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(i.$3),
                  onTap: () => Navigator.pop(ctx, (i.$1, i.$2)),
                ),
            ],
          ),
        ),
      ),
    );
    if (r != null)
      setState(() {
        _placeId = r.$1;
        _placeName = r.$2;
      });
  }

  Future<void> _pickPeople() async {
    final r = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => PeoplePicker(
          work: false,
          title: _kind == 'person' ? 'Gửi cho ai?' : 'Chọn tối đa 20 người',
          single: _kind == 'person',
        ),
      ),
    );
    if (r == null) return;
    setState(() {
      _people = _kind == 'person' ? r : {..._people, ...r};
      if (_people.length > 20)
        _people = Map.fromEntries(_people.entries.take(20));
    });
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final kinds = [
      'person',
      'space',
      'line',
      'khoa',
      'people',
      if (_t?['school'] == true) 'school',
    ];
    final ready = _to != null && _body.text.trim().isNotEmpty && !_busy;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: const Text('Gửi thông báo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SentNoticesScreen()),
            ),
            child: Text('Đã gửi', style: TextStyle(color: vd.onHeader)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'GỬI CHO',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: vd.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final k in kinds)
                ChoiceChip(
                  label: Text(_scopeLabel(k)),
                  selected: _kind == k,
                  onSelected: (_) => setState(() {
                    _kind = k;
                    _placeId = null;
                    _placeName = null;
                    _people = {};
                    _urgent = false;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_kind == 'person' || _kind == 'people')
            OutlinedButton.icon(
              onPressed: _pickPeople,
              icon: const Icon(Icons.person_add_alt),
              label: Text(
                _people.isEmpty
                    ? (_kind == 'person'
                          ? 'Chọn người'
                          : 'Chọn người (tối đa 20)')
                    : _people.values.join(', '),
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (_kind != 'school')
            OutlinedButton.icon(
              onPressed: _t == null ? null : _pickPlace,
              icon: const Icon(Icons.place_outlined),
              label: Text(
                _placeName ?? 'Chọn ${_scopeLabel(_kind).toLowerCase()}',
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            Text(
              'Mọi cán bộ, giảng viên đang làm việc.',
              style: TextStyle(color: vd.inkMuted),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nội dung (một câu)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_many) ...[
            const SizedBox(height: 4),
            Text(
              'MỨC',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: vd.inkMuted,
              ),
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              value: false,
              groupValue: _urgent,
              onChanged: (v) => setState(() => _urgent = false),
              title: const Text('Thường'),
              subtitle: const Text(
                'Hiện trong mục Thông báo, điện thoại không đổ chuông.',
              ),
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              value: true,
              groupValue: _urgent,
              onChanged: _urgentLeft > 0
                  ? (v) => setState(() => _urgent = true)
                  : null,
              title: const Text('Cần xem ngay'),
              subtitle: Text(
                _urgentLeft > 0
                    ? 'Điện thoại mỗi người đổ chuông. Hôm nay bạn còn $_urgentLeft lần.'
                    : 'Hôm nay bạn đã dùng hết lượt.',
              ),
            ),
          ] else
            Text(
              'Người nhận sẽ thấy trên điện thoại.',
              style: TextStyle(color: vd.inkMuted, fontSize: 13),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ready ? _send : null,
            child: Text(_busy ? 'Đang gửi…' : 'Gửi'),
          ),
        ],
      ),
    );
  }
}

/// What I sent, with "đã xem x/y".
class SentNoticesScreen extends StatefulWidget {
  const SentNoticesScreen({super.key});

  @override
  State<SentNoticesScreen> createState() => _SentNoticesScreenState();
}

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
    final canRing =
        mine && notSeen.isNotEmpty && (!many || n['level'] == 'urgent');
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
                    ] else if (mine && notSeen.isNotEmpty && many)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Thông báo "Thường" không đổ chuông; người nhận vẫn thấy trong mục Thông báo.',
                          style: TextStyle(color: vd.inkMuted, fontSize: 13),
                        ),
                      ),
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
