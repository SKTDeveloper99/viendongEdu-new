import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../work/work_api.dart';
import 'small_group_api.dart';

Future<void> _fail(BuildContext context, Object e) async {
  if (e is EmsException && e.statusCode == 401) {
    await handleCrmAuthError(context, e);
    return;
  }
  if (context.mounted) {
    showErrorSnack(
      context,
      e is EmsException ? e.message : 'Không kết nối được máy chủ.',
    );
  }
}

/// Pick people from the directory (search by name). Returns user ids → names.
class PeoplePicker extends StatefulWidget {
  final bool work;
  final String title;
  final bool single;
  const PeoplePicker({
    super.key,
    this.work = true,
    required this.title,
    this.single = false,
  });

  @override
  State<PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<PeoplePicker> {
  List<Map<String, dynamic>>? _all;
  final Map<String, String> _picked = {};
  String _q = '';

  @override
  void initState() {
    super.initState();
    SmallGroupApi.people(work: widget.work)
        .then((p) {
          final me = AppSession.instance.userId;
          if (mounted) {
            setState(
              () => _all = p
                  .where(
                    (x) =>
                        '${x['id']}' != me &&
                        (!widget.work || x['can_receive_work'] != false),
                  )
                  .toList(),
            );
          }
        })
        .catchError((e) async {
          if (mounted) await _fail(context, e);
        });
  }

  // "hoang tho" finds "Hoàng Thơ": search ignores Vietnamese marks.
  static const _from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  static const _to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  String _fold(String s) {
    final low = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in low.split('')) {
      final i = _from.indexOf(ch);
      b.write(i >= 0 ? _to[i] : ch);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final rows = (_all ?? const <Map<String, dynamic>>[])
        .where(
          (p) =>
              _q.length < 2 || _fold('${p['full_name']}').contains(_fold(_q)),
        )
        .take(60)
        .toList();
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!widget.single)
            TextButton(
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, _picked),
              child: Text(
                'Xong (${_picked.length})',
                style: TextStyle(color: vd.onHeader),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Gõ tên (ít nhất 2 chữ)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          if (_picked.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final e in _picked.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(e.value),
                        onDeleted: () => setState(() => _picked.remove(e.key)),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _all == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      for (final p in rows)
                        ListTile(
                          title: Text('${p['full_name'] ?? ''}'),
                          subtitle: Text(
                            '${p['role_label'] ?? p['role'] ?? ''}${p['hint'] != null ? ' · ${p['hint']}' : ''}',
                          ),
                          trailing: _picked.containsKey('${p['id']}')
                              ? Icon(Icons.check_circle, color: vd.accent)
                              : null,
                          onTap: () {
                            final id = '${p['id']}';
                            if (widget.single) {
                              Navigator.pop(context, {
                                id: '${p['full_name'] ?? ''}',
                              });
                              return;
                            }
                            setState(
                              () => _picked.containsKey(id)
                                  ? _picked.remove(id)
                                  : _picked[id] = '${p['full_name'] ?? ''}',
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Giao một phần" on a piece: pick people, name the part, optional table.
class DelegateScreen extends StatefulWidget {
  final String taskId;
  final String pieceTitle;
  const DelegateScreen({
    super.key,
    required this.taskId,
    required this.pieceTitle,
  });

  @override
  State<DelegateScreen> createState() => _DelegateScreenState();
}

class _DelegateScreenState extends State<DelegateScreen> {
  Map<String, String> _people = {};
  final _title = TextEditingController();
  final _list = TextEditingController();
  DateTime? _due;
  bool _withList = false;
  final List<(TextEditingController, String)> _cols = [];
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _list.dispose();
    for (final c in _cols) {
      c.$1.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const PeoplePicker(title: 'Giao cho ai?'),
      ),
    );
    if (r != null) setState(() => _people = {..._people, ...r});
  }

  Future<void> _send() async {
    if (_people.isEmpty || _title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await SmallGroupApi.delegate(
        widget.taskId,
        people: _people.keys.toList(),
        title: _title.text.trim(),
        dueAt: _due,
        listTitle: _withList ? _list.text.trim() : null,
        columns: [
          for (final c in _cols)
            if (c.$1.text.trim().isNotEmpty)
              {'name': c.$1.text.trim(), 'kind': c.$2},
        ],
      );
      if (!mounted) return;
      showSuccessSnack(
        context,
        'Đã giao một phần cho ${_people.length} người.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) await _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final ok =
        _people.isNotEmpty &&
        _title.text.trim().isNotEmpty &&
        (!_withList || _list.text.trim().isNotEmpty);
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Giao một phần')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Từ: ${widget.pieceTitle}',
            style: TextStyle(color: vd.inkMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.person_add_alt),
            label: Text(
              _people.isEmpty ? 'Chọn người' : _people.values.join(', '),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Phần việc giao',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
                initialDate: now.add(const Duration(days: 1)),
              );
              if (d != null)
                setState(() => _due = DateTime(d.year, d.month, d.day, 17));
            },
            icon: const Icon(Icons.event),
            label: Text(
              _due == null ? 'Chọn hạn' : dueLabel(_due!.toIso8601String()),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _withList,
            onChanged: (v) => setState(() {
              _withList = v;
              if (v && _cols.isEmpty)
                _cols.add((TextEditingController(), 'yes_no'));
            }),
            title: const Text('Kèm danh sách cần điền'),
          ),
          if (_withList) ...[
            TextField(
              controller: _list,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Tên danh sách',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _cols.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cols[i].$1,
                        decoration: InputDecoration(
                          labelText: 'Cột ${i + 1}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _cols[i].$2,
                      items: [
                        for (final k in columnKinds.entries)
                          DropdownMenuItem(value: k.key, child: Text(k.value)),
                      ],
                      onChanged: (v) =>
                          setState(() => _cols[i] = (_cols[i].$1, v ?? 'text')),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: _cols.length >= 12
                  ? null
                  : () => setState(
                      () => _cols.add((TextEditingController(), 'text')),
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Thêm cột'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Những người được giao vào nhóm nhỏ của việc này. Nhóm tự đóng khi việc xong, trừ khi trưởng nhóm bấm "Giữ nhóm này".',
            style: TextStyle(color: vd.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ok && !_busy ? _send : null,
            child: Text(_busy ? 'Đang giao…' : 'Giao'),
          ),
        ],
      ),
    );
  }
}

/// A small group with no piece: name, people, temporary by default.
class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _name = TextEditingController();
  Map<String, String> _people = {};
  bool _temporary = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final r = await SmallGroupApi.create(
        name: _name.text.trim(),
        members: _people.keys.toList(),
        temporary: _temporary,
      );
      if (!mounted) return;
      showSuccessSnack(context, 'Đã mở nhóm.');
      Navigator.pop(context, (r['space'] as Map?)?['id']?.toString());
    } catch (e) {
      if (mounted) await _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Nhóm mới')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Tên nhóm',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final r = await Navigator.push<Map<String, String>>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const PeoplePicker(work: false, title: 'Thành viên'),
                ),
              );
              if (r != null) setState(() => _people = {..._people, ...r});
            },
            icon: const Icon(Icons.group_add_outlined),
            label: Text(
              _people.isEmpty ? 'Chọn thành viên' : _people.values.join(', '),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _temporary,
            onChanged: (v) => setState(() => _temporary = v),
            title: const Text('Nhóm tạm'),
            subtitle: const Text(
              'Tự đóng khi mọi việc trong nhóm xong. Trưởng nhóm có thể "Giữ nhóm này" bất cứ lúc nào.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _name.text.trim().isEmpty || _busy ? null : _send,
            child: Text(_busy ? 'Đang mở…' : 'Mở nhóm'),
          ),
        ],
      ),
    );
  }
}

/// One table (Danh sách): rows are a student, a person or a line of text;
/// tap a cell to fill it; each filled cell says who and when.
class TableScreen extends StatefulWidget {
  final String spaceId;
  final String listId;
  final String title;
  const TableScreen({
    super.key,
    required this.spaceId,
    required this.listId,
    required this.title,
  });

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await SmallGroupApi.list(widget.spaceId, widget.listId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) await _fail(context, e);
    }
  }

  List<Map<String, dynamic>> get _cols =>
      ((_data?['columns'] as List?) ?? const []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _rows =>
      ((_data?['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();
  bool get _canShape => (_data?['list'] as Map?)?['can_edit_columns'] == true;

  String _rowName(Map<String, dynamic> r) =>
      switch ('${r['kind'] ?? 'student'}') {
        'person' => '${r['person_name'] ?? '—'}',
        'text' => '${r['label'] ?? ''}',
        _ => '${r['full_name'] ?? r['mssv'] ?? '—'}',
      };

  String _rowSub(Map<String, dynamic> r) =>
      switch ('${r['kind'] ?? 'student'}') {
        'person' => 'Cán bộ, GV',
        'text' => 'Dòng chữ',
        _ => 'SV ${r['mssv'] ?? ''}',
      };

  String _show(String kind, String? v) {
    if (v == null || v.isEmpty) return '';
    if (kind == 'yes_no') return v == 'yes' ? 'Có' : 'Không';
    if (kind == 'date' && v.length >= 10)
      return '${v.substring(8, 10)}/${v.substring(5, 7)}/${v.substring(0, 4)}';
    return v;
  }

  Future<void> _editCell(
    Map<String, dynamic> row,
    Map<String, dynamic> col,
  ) async {
    final cell = ((row['cells'] as Map?) ?? const {})['${col['id']}'] as Map?;
    final kind = '${col['kind']}';
    String? value = cell?['value']?.toString();
    final ctrl = TextEditingController(text: value ?? '');
    final result = await showModalBottomSheet<(bool, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.paddingOf(ctx).bottom +
              16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${col['name']} · ${_rowName(row)}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            if (cell?['by'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Đã điền bởi ${cell!['by']} lúc ${whenLabel(cell['at'])}',
                  style: TextStyle(color: ctx.vd.inkMuted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            if (kind == 'yes_no')
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, (true, 'yes')),
                      child: const Text('Có'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, (true, 'no')),
                      child: const Text('Không'),
                    ),
                  ),
                ],
              )
            else if (kind == 'date')
              FilledButton.icon(
                icon: const Icon(Icons.event),
                label: const Text('Chọn ngày'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate:
                        DateTime.tryParse(value ?? '') ?? DateTime.now(),
                  );
                  if (d != null && ctx.mounted) {
                    String two(int n) => n.toString().padLeft(2, '0');
                    Navigator.pop(ctx, (
                      true,
                      '${d.year}-${two(d.month)}-${two(d.day)}',
                    ));
                  }
                },
              )
            else ...[
              TextField(
                controller: ctrl,
                autofocus: true,
                autocorrect: kind == 'text',
                keyboardType: kind == 'number'
                    ? const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      )
                    : kind == 'link'
                    ? TextInputType.url
                    : TextInputType.text,
                decoration: InputDecoration(
                  hintText: kind == 'link' ? 'https://…' : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, (true, ctrl.text.trim())),
                child: const Text('Lưu'),
              ),
            ],
            if (value != null && value.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(ctx, (true, null)),
                child: const Text('Xoá giá trị'),
              ),
          ],
        ),
      ),
    );
    if (result == null || !result.$1) return;
    try {
      await SmallGroupApi.setCell(
        widget.spaceId,
        widget.listId,
        '${row['id']}',
        '${col['id']}',
        result.$2,
      );
      await _load();
    } catch (e) {
      if (mounted) await _fail(context, e);
    }
  }

  Future<void> _addColumn() async {
    final name = TextEditingController();
    var kind = 'yes_no';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Thêm cột'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên cột'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final k in columnKinds.entries)
                    ChoiceChip(
                      label: Text(k.value),
                      selected: kind == k.key,
                      onSelected: (_) => set(() => kind = k.key),
                    ),
                ],
              ),
            ],
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
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await SmallGroupApi.addColumn(
        widget.spaceId,
        widget.listId,
        name.text.trim(),
        kind,
      );
      await _load();
    } catch (e) {
      if (mounted) await _fail(context, e);
    }
  }

  Future<void> _addRow() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Sinh viên (MSSV)'),
              onTap: () => Navigator.pop(ctx, 'student'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Cán bộ, giảng viên'),
              onTap: () => Navigator.pop(ctx, 'person'),
            ),
            ListTile(
              leading: const Icon(Icons.short_text),
              title: const Text('Dòng chữ'),
              onTap: () => Navigator.pop(ctx, 'text'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    List<Map<String, String>> rows = [];
    if (choice == 'person') {
      final r = await Navigator.push<Map<String, String>>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const PeoplePicker(work: false, title: 'Thêm người vào bảng'),
        ),
      );
      if (r == null) return;
      rows = [
        for (final id in r.keys) {'user_id': id},
      ];
    } else {
      final ctrl = TextEditingController();
      final v = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(choice == 'student' ? 'MSSV' : 'Dòng chữ'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            autocorrect: choice == 'text',
            decoration: InputDecoration(
              hintText: choice == 'student'
                  ? 'Một hoặc nhiều MSSV, cách nhau bởi dấu cách'
                  : 'Ví dụ: Phòng 204',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Thôi'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Thêm'),
            ),
          ],
        ),
      );
      if (v == null || v.isEmpty) return;
      rows = choice == 'student'
          ? [
              for (final m
                  in v.split(RegExp(r'[\s,;]+')).where((x) => x.isNotEmpty))
                {'mssv': m},
            ]
          : [
              {'text': v},
            ];
    }
    try {
      final r = await SmallGroupApi.addRows(
        widget.spaceId,
        widget.listId,
        rows,
      );
      final results = ((r['results'] as List?) ?? const []).cast<Map>();
      final bad = results.where((x) => x['status'] != 'added').length;
      if (mounted && bad > 0)
        showErrorSnack(
          context,
          '$bad dòng không thêm được (không tìm thấy hoặc đã có).',
        );
      await _load();
    } catch (e) {
      if (mounted) await _fail(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final cols = _cols;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_canShape)
            IconButton(
              tooltip: 'Thêm cột',
              onPressed: _addColumn,
              icon: const Icon(Icons.view_column_outlined),
            ),
        ],
      ),
      floatingActionButton: _data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addRow,
              icon: const Icon(Icons.add),
              label: const Text('Thêm dòng'),
            ),
      body: _data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      '${_rows.length} dòng · ${cols.length} cột · chạm một ô để điền',
                      style: TextStyle(color: vd.inkMuted),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(vd.surfaceAlt),
                      columnSpacing: 18,
                      showCheckboxColumn: false,
                      columns: [
                        const DataColumn(label: Text('Dòng')),
                        for (final c in cols)
                          DataColumn(label: Text('${c['name']}')),
                      ],
                      rows: [
                        for (final r in _rows)
                          DataRow(
                            cells: [
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 170,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _rowName(r),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _rowSub(r),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: vd.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              for (final c in cols)
                                DataCell(
                                  Builder(
                                    builder: (_) {
                                      final cell =
                                          ((r['cells'] as Map?) ??
                                                  const {})['${c['id']}']
                                              as Map?;
                                      final v = _show(
                                        '${c['kind']}',
                                        cell?['value']?.toString(),
                                      );
                                      return ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 56,
                                          maxWidth: 160,
                                        ),
                                        child: Text(
                                          v.isEmpty ? '—' : v,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: v.isEmpty
                                                ? vd.inkFaint
                                                : vd.ink,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  onTap: () => _editCell(r, c),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
