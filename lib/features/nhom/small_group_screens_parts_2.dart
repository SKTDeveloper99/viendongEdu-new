part of 'small_group_screens.dart';

extension _TableScreenStatePart1 on _TableScreenState {
  Future<void> _load() async {
    try {
      final d = await SmallGroupApi.list(widget.spaceId, widget.listId);
      if (mounted) _set(() => _data = d);
    } catch (e) {
      if (mounted && _data == null) _set(() => _failed = true);
      if (mounted) await _fail(context, e);
    }
  }

  List<Map<String, dynamic>> get _cols =>
      ((_data?['columns'] as List?) ?? const []).cast<Map<String, dynamic>>();

  /// My own row(s) first, the rest in the server's order.
  List<Map<String, dynamic>> get _rows {
    final all = ((_data?['rows'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    return [...all.where(_isMine), ...all.where((r) => !_isMine(r))];
  }

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
    if (kind == 'date' && v.length >= 10) {
      return '${v.substring(8, 10)}/${v.substring(5, 7)}/${v.substring(0, 4)}';
    }
    return v;
  }

  Future<void> _editCell(
    Map<String, dynamic> row,
    Map<String, dynamic> col,
  ) async {
    final cell = ((row['cells'] as Map?) ?? const {})['${col['id']}'] as Map?;
    final kind = '${col['kind']}';
    final cccd = isCccdColumn('${col['name']}');
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
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                    initialDate:
                        DateTime.tryParse(value ?? '') ?? DateTime.now(),
                    // An empty cell opens on the years (a birth date is
                    // decades back, not this month).
                    initialDatePickerMode:
                        DateTime.tryParse(value ?? '') == null
                        ? DatePickerMode.year
                        : DatePickerMode.day,
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
                keyboardType: cccd
                    ? TextInputType.number
                    : kind == 'number'
                    ? const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      )
                    : kind == 'link'
                    ? TextInputType.url
                    : TextInputType.text,
                decoration: InputDecoration(
                  hintText: cccd
                      ? '12 chữ số'
                      : kind == 'link'
                      ? 'https://…'
                      : null,
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
    var out = result.$2;
    if (cccd && out != null && out.isNotEmpty) {
      out = out.replaceAll(RegExp(r'[\s.]'), '');
      if (!RegExp(r'^\d{12}$').hasMatch(out)) {
        if (mounted) showErrorSnack(context, 'Số CCCD phải đủ 12 chữ số.');
        return;
      }
    }
    try {
      await SmallGroupApi.setCell(
        widget.spaceId,
        widget.listId,
        '${row['id']}',
        '${col['id']}',
        out,
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
      if (mounted && bad > 0) {
        showErrorSnack(
          context,
          '$bad dòng không thêm được (không tìm thấy hoặc đã có).',
        );
      }
      await _load();
    } catch (e) {
      if (mounted) await _fail(context, e);
    }
  }
}
