import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../work/work_api.dart';
import '../common/load_error.dart';
import 'nhom_api.dart';
import 'small_group_api.dart';
import 'table_file_cell.dart';
import 'table_file_sheet.dart';

part 'small_group_screens_parts_1.dart';
part 'small_group_screens_parts_2.dart';
part 'small_group_people_picker.dart';
part 'small_group_table_parts.dart';

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
              if (d != null) {
                setState(() => _due = DateTime(d.year, d.month, d.day, 17));
              }
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
              if (v && _cols.isEmpty) {
                _cols.add((TextEditingController(), 'yes_no'));
              }
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
/// [limits]: the server's `nhom_limits` (LAW P-32): `member_max` people
/// besides the opener, `open_left_today` of `open_per_day` (null: no cap).
class NewGroupScreen extends StatefulWidget {
  final Map<String, dynamic>? limits;
  const NewGroupScreen({super.key, this.limits});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}
