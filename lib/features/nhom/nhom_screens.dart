import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../work/piece_screen.dart';
import '../work/work_api.dart';
import 'nhom_api.dart';
import 'small_group_api.dart';
import 'small_group_screens.dart';
import '../notices/notice_screens.dart';

Future<void> _guard(
  BuildContext context,
  Object e,
  void Function(String) show,
) async {
  if (e is EmsException && e.statusCode == 401) {
    await handleCrmAuthError(context, e);
    return;
  }
  show(e is EmsException ? e.message : 'Không kết nối được máy chủ.');
}

/// "Nhóm" (Overlord slice): the groups I am in first, then the ones I follow.
class NhomListScreen extends StatefulWidget {
  const NhomListScreen({super.key});

  @override
  State<NhomListScreen> createState() => _NhomListScreenState();
}

class _NhomListScreenState extends State<NhomListScreen> {
  List<Map<String, dynamic>>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await NhomApi.list();
      final rows = EmsApiService.rows(
        b['spaces'] ?? const [],
      ).where((s) => s['archived_at'] == null).toList();
      rows.sort((a, b) {
        final m =
            (b['is_member'] == true ? 1 : 0) - (a['is_member'] == true ? 1 : 0);
        if (m != 0) return m;
        return '${b['last_activity_at'] ?? ''}'.compareTo(
          '${a['last_activity_at'] ?? ''}',
        );
      });
      if (mounted)
        setState(() {
          _rows = rows;
          _error = null;
        });
    } catch (e) {
      if (mounted) await _guard(context, e, (m) => setState(() => _error = m));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final rows = _rows;
    final mine =
        rows?.where((s) => s['is_member'] == true).toList() ?? const [];
    final others =
        rows?.where((s) => s['is_member'] != true).toList() ?? const [];
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Nhóm')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Nhóm mới'),
        onPressed: () async {
          final id = await Navigator.push<String?>(
            context,
            MaterialPageRoute(builder: (_) => const NewGroupScreen()),
          );
          await _load();
          if (id != null && mounted) {
            final row = _rows?.firstWhere(
              (s) => '${s['id']}' == id,
              orElse: () => {'name': ''},
            );
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NhomScreen(spaceId: id, name: '${row?['name'] ?? ''}'),
              ),
            );
            _load();
          }
        },
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : rows == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  for (final s in mine) _tile(vd, s),
                  if (others.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        'NHÓM BẠN THEO DÕI (${others.length})',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: vd.inkMuted,
                        ),
                      ),
                    ),
                    for (final s in others) _tile(vd, s),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _tile(VdTokens vd, Map<String, dynamic> s) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: vd.surface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: vd.hairline),
        ),
        leading: CircleAvatar(
          backgroundColor: vd.accentSoft,
          child: Icon(Icons.groups_2_outlined, color: vd.accent),
        ),
        title: Text(
          '${s['name'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${s['member_count'] ?? 0} thành viên · ${s['post_count'] ?? 0} tin',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  NhomScreen(spaceId: '${s['id']}', name: '${s['name'] ?? ''}'),
            ),
          );
          _load();
        },
      ),
    ),
  );
}

/// One group: Bảng tin, Việc, Thành viên; post, and give work to members.
class NhomScreen extends StatefulWidget {
  final String spaceId;
  final String name;
  const NhomScreen({super.key, required this.spaceId, required this.name});

  @override
  State<NhomScreen> createState() => _NhomScreenState();
}

class _NhomScreenState extends State<NhomScreen> {
  Map<String, dynamic>? _one;
  List<Map<String, dynamic>> _feed = const [];
  List<Map<String, dynamic>> _work = const [];
  List<Map<String, dynamic>> _lists = const [];
  String? _error;
  final _postCtrl = TextEditingController();
  bool _postUrgent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        NhomApi.one(widget.spaceId),
        NhomApi.feed(widget.spaceId),
        NhomApi.work(widget.spaceId),
        SmallGroupApi.lists(
          widget.spaceId,
        ).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _one = r[0] as Map<String, dynamic>;
        _feed = r[1] as List<Map<String, dynamic>>;
        _work = r[2] as List<Map<String, dynamic>>;
        _lists = r[3] as List<Map<String, dynamic>>;
        _error = null;
      });
    } catch (e) {
      if (mounted) await _guard(context, e, (m) => setState(() => _error = m));
    }
  }

  List<Map<String, dynamic>> get _members =>
      ((_one?['members'] as List?) ?? const []).cast<Map<String, dynamic>>();

  Future<void> _post() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      final r = await NhomApi.post(widget.spaceId, text, urgent: false);
      _postCtrl.clear();
      if (mounted) {
        showSuccessSnack(
          context,
          r['urgent_error'] != null
              ? 'Đã đăng; chưa đổ chuông: ${r['urgent_error']}'
              : (_postUrgent ? 'Đã đăng và đổ chuông cả nhóm.' : 'Đã đăng.'),
        );
        setState(() => _postUrgent = false);
      }
      await _load();
    } catch (e) {
      if (mounted) await _guard(context, e, (m) => showErrorSnack(context, m));
    }
  }

  Future<void> _give() async {
    final me = AppSession.instance.userId;
    final people = _members
        .where((m) => '${m['user_id']}' != me && m['can_receive_task'] != false)
        .toList();
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GiveWorkScreen(spaceId: widget.spaceId, people: people),
      ),
    );
    if (done == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: vd.bg,
        appBar: AppBar(
          title: Text(
            widget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: TabBar(
            labelColor: vd.onHeader,
            unselectedLabelColor: vd.onHeader.withValues(alpha: 0.7),
            indicatorColor: vd.onHeader,
            tabs: [
              const Tab(text: 'Bảng tin'),
              Tab(
                text: 'Việc (${_work.map((a) => a['task_id']).toSet().length})',
              ),
              Tab(text: 'Danh sách (${_lists.length})'),
              Tab(text: 'Thành viên (${_members.length})'),
            ],
            isScrollable: true,
            tabAlignment: TabAlignment.start,
          ),
        ),
        floatingActionButton: _one == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _give,
                icon: const Icon(Icons.add_task),
                label: const Text('Giao việc'),
              ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!),
                ),
              )
            : _one == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_temporary && _space['archived_at'] == null)
                    _keepBanner(vd),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _feedTab(vd),
                        _workTab(vd),
                        _listsTab(vd),
                        _membersTab(vd),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _feedTab(VdTokens vd) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _postCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Viết cho cả nhóm…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _post, icon: const Icon(Icons.send)),
          ],
        ),
        // A post rings every other member (bell row and banner).
        Row(
          children: [
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NoticeComposeScreen(
                    preset: {
                      'kind': 'space',
                      'id': widget.spaceId,
                      'name': widget.name,
                    },
                  ),
                ),
              ),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Gửi thông báo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_feed.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Chưa có tin nào.',
                style: TextStyle(color: vd.inkMuted),
              ),
            ),
          ),
        for (final p in _feed)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
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
                  '${p['author_name'] ?? ''} · ${whenLabel(p['created_at'])}',
                  style: TextStyle(color: vd.inkMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text('${p['body'] ?? ''}', style: TextStyle(color: vd.ink)),
                if (p['task_id'] != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: Text(
                      '${p['task_title'] ?? 'Mở việc'} · ${p['task_done_count'] ?? 0}/${p['task_assignee_count'] ?? 0}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _openPiece('${p['task_id']}'),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );

  Future<void> _openPiece(String taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PieceScreen(taskId: taskId)),
    );
    _load();
  }

  Widget _workTab(VdTokens vd) {
    final byTask = <String, List<Map<String, dynamic>>>{};
    for (final a in _work) {
      byTask.putIfAbsent('${a['task_id']}', () => []).add(a);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (byTask.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Chưa có việc nào trong nhóm.',
                  style: TextStyle(color: vd.inkMuted),
                ),
              ),
            ),
          for (final e in byTask.entries)
            Card(
              elevation: 0,
              color: vd.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: vd.hairline),
              ),
              child: ListTile(
                title: Text(
                  '${e.value.first['title'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    'Giao bởi ${e.value.first['giver_name'] ?? '—'}',
                    '${e.value.where((a) => a['status'] == 'done').length}/${e.value.length} xong',
                    if (dueLabel(e.value.first['due_at']).isNotEmpty)
                      dueLabel(e.value.first['due_at']),
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openPiece(e.key),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> get _space =>
      ((_one?['space'] as Map?) ?? const {}).cast<String, dynamic>();
  bool get _isHead => ((_one?['me'] as Map?)?['is_lead']) == true;
  bool get _temporary =>
      _space['kept_at'] == null &&
      (_space['is_temporary'] == true ||
          _space['source_task_id'] != null ||
          _space['calendar_line_id'] != null);

  Widget _keepBanner(VdTokens vd) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: vd.warningSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.timelapse, color: vd.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _space['source_task_id'] != null
                ? 'Nhóm tạm của một việc: tự đóng khi việc xong.'
                : 'Nhóm tạm: tự đóng khi mọi việc trong nhóm xong.',
            style: TextStyle(color: vd.ink, fontSize: 13),
          ),
        ),
        if (_isHead)
          TextButton(
            onPressed: () async {
              try {
                await SmallGroupApi.keep(widget.spaceId);
                if (mounted)
                  showSuccessSnack(
                    context,
                    'Đã giữ nhóm. Nhóm không tự đóng nữa.',
                  );
                await _load();
              } catch (e) {
                if (mounted)
                  await _guard(context, e, (m) => showErrorSnack(context, m));
              }
            },
            child: const Text('Giữ nhóm này'),
          ),
      ],
    ),
  );

  Future<void> _newList() async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Danh sách mới'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên danh sách'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Thôi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    try {
      final r = await SmallGroupApi.createList(widget.spaceId, title);
      final id = (r['list'] as Map?)?['id']?.toString();
      await _load();
      if (id != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TableScreen(spaceId: widget.spaceId, listId: id, title: title),
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) await _guard(context, e, (m) => showErrorSnack(context, m));
    }
  }

  Widget _listsTab(VdTokens vd) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        OutlinedButton.icon(
          onPressed: _newList,
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Danh sách mới'),
        ),
        const SizedBox(height: 8),
        if (_lists.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Chưa có danh sách nào.',
                style: TextStyle(color: vd.inkMuted),
              ),
            ),
          ),
        for (final l in _lists)
          Card(
            elevation: 0,
            color: vd.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: vd.hairline),
            ),
            child: ListTile(
              leading: Icon(Icons.table_rows_outlined, color: vd.accent),
              title: Text(
                '${l['title'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${l['students'] ?? 0} dòng · ${l['reporters'] ?? 0} người điền · ${l['created_by_name'] ?? ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TableScreen(
                      spaceId: widget.spaceId,
                      listId: '${l['id']}',
                      title: '${l['title'] ?? ''}',
                    ),
                  ),
                );
                _load();
              },
            ),
          ),
      ],
    ),
  );

  Widget _membersTab(VdTokens vd) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
    children: [
      for (final m in _members)
        ListTile(
          leading: CircleAvatar(
            backgroundColor: vd.accentSoft,
            child: Text(
              '${m['full_name'] ?? '?'}'
                  .trim()
                  .split(' ')
                  .last
                  .characters
                  .first,
              style: TextStyle(color: vd.accent),
            ),
          ),
          title: Text('${m['teacher_name'] ?? m['full_name'] ?? ''}'),
          subtitle: Text(m['role'] == 'lead' ? 'Trưởng nhóm' : 'Thành viên'),
        ),
    ],
  );
}

/// "Giao việc" inside a group: title, note, hạn, who (default: everyone else).
class GiveWorkScreen extends StatefulWidget {
  final String spaceId;
  final List<Map<String, dynamic>> people;
  const GiveWorkScreen({
    super.key,
    required this.spaceId,
    required this.people,
  });

  @override
  State<GiveWorkScreen> createState() => _GiveWorkScreenState();
}

class _GiveWorkScreenState extends State<GiveWorkScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _due;
  late final Set<String> _picked = widget.people
      .map((p) => '${p['user_id']}')
      .toSet();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 2)),
    );
    if (d != null) setState(() => _due = DateTime(d.year, d.month, d.day, 17));
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      await NhomApi.giveWork(
        widget.spaceId,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        dueAt: _due,
        assigneeIds: _picked.length == widget.people.length
            ? null
            : _picked.toList(),
      );
      if (!mounted) return;
      showSuccessSnack(context, 'Đã giao việc cho ${_picked.length} người.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) await _guard(context, e, (m) => showErrorSnack(context, m));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Giao việc trong nhóm')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Tên việc',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mô tả (không bắt buộc)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDue,
            icon: const Icon(Icons.event),
            label: Text(
              _due == null ? 'Chọn hạn' : dueLabel(_due!.toIso8601String()),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'GIAO CHO (${_picked.length}/${widget.people.length})',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: vd.inkMuted,
            ),
          ),
          for (final p in widget.people)
            CheckboxListTile(
              value: _picked.contains('${p['user_id']}'),
              onChanged: (v) => setState(
                () => v == true
                    ? _picked.add('${p['user_id']}')
                    : _picked.remove('${p['user_id']}'),
              ),
              title: Text('${p['teacher_name'] ?? p['full_name'] ?? ''}'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: Text(_busy ? 'Đang giao…' : 'Giao việc'),
          ),
        ],
      ),
    );
  }
}
