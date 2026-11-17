part of 'small_group_screens.dart';

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

  // Lets the extensions in this library's parts call setState.
  void _set(VoidCallback f) => setState(f);
}
