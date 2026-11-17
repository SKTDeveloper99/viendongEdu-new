import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../work/work_api.dart';
import 'small_group_api.dart';

part 'small_group_screens_parts_1.dart';
part 'small_group_screens_parts_2.dart';

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
