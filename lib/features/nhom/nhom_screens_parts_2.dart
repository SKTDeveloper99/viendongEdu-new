part of 'nhom_screens.dart';

extension _NhomScreenStatePart2 on _NhomScreenState {
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
              _initialOf('${m['full_name'] ?? ''}'),
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

/// First letter of the last word of a name; "?" for an empty or blank name.
String _initialOf(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  final last = words.isEmpty ? '' : words.last;
  return last.isEmpty ? '?' : last.characters.first;
}
