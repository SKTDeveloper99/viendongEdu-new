import 'package:flutter/material.dart';

import '../../services/ems_api_service.dart' show EmsApiService;
import '../../theme/vd_tokens.dart';
import '../nhom/small_group_api.dart';
import '../nhom/small_group_screens.dart';

/// On a piece given in a Nhóm with a table to fill (LAW T-49, proposed T-58):
/// the table, what each person filled, and "Mở dòng của bạn" / "Mở bảng".
/// Reads `GET /spaces/:id/tasks/:taskId`; in an own-rows table a member gets
/// only their own line, the head and the table's maker every line. Shows
/// nothing when the piece has no table or the read fails.
class PieceTableLink extends StatefulWidget {
  final String spaceId;
  final String taskId;

  /// My part of this piece, if I am a receiver.
  final Map<String, dynamic>? mine;
  final bool review;
  final Widget Function(String title) section;

  /// After the table was open: the piece reloads (a hand-in may have gone).
  final VoidCallback onBack;
  const PieceTableLink({
    super.key,
    required this.spaceId,
    required this.taskId,
    required this.section,
    required this.onBack,
    this.mine,
    this.review = true,
  });

  @override
  State<PieceTableLink> createState() => _PieceTableLinkState();
}

class _PieceTableLinkState extends State<PieceTableLink> {
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    SmallGroupApi.boardTask(widget.spaceId, widget.taskId)
        .then((d) {
          if (mounted) setState(() => _d = d);
        })
        .catchError((_) {});
  }

  bool get _mineOpen => const {
    'assigned',
    'in_progress',
    'blocked',
  }.contains(widget.mine?['status']);

  @override
  Widget build(BuildContext context) {
    final list = (_d?['linked_list'] as Map?)?.cast<String, dynamic>();
    if (list == null) return const SizedBox.shrink();
    final vd = context.vd;
    final cols = EmsApiService.rows(list['columns'] ?? const []);
    final people = EmsApiService.rows(_d?['assignee_rows'] ?? const []);
    final own = list['own_rows_only'] == true;
    final filled = people.where((p) => _filled(p, cols)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.section('Bảng cần điền'),
        Container(
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
                '${list['title'] ?? ''}',
                style: TextStyle(fontWeight: FontWeight.w600, color: vd.ink),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (own)
                    widget.mine != null && people.length <= 1
                        ? 'Bạn chỉ thấy và điền dòng của mình'
                        : 'Mỗi người chỉ thấy dòng của mình',
                  if (people.length > 1) 'Đã điền $filled/${people.length}',
                ].join(' · '),
                style: TextStyle(color: vd.inkMuted, fontSize: 13),
              ),
              for (final p in people) ..._person(vd, p, cols),
              const SizedBox(height: 8),
              _mineOpen
                  ? FilledButton.icon(
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('Mở dòng của bạn'),
                      onPressed: () => _open(list),
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.table_rows_outlined, size: 18),
                      label: const Text('Mở bảng'),
                      onPressed: () => _open(list),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _person(
    VdTokens vd,
    Map<String, dynamic> p,
    List<Map<String, dynamic>> cols,
  ) {
    final rows = EmsApiService.rows(p['rows'] ?? const []);
    return [
      const SizedBox(height: 10),
      Text(
        '${p['name'] ?? '—'}',
        style: TextStyle(fontWeight: FontWeight.w600, color: vd.ink),
      ),
      if (rows.isEmpty)
        Text('Chưa có dòng.', style: TextStyle(color: vd.inkFaint)),
      for (final r in rows)
        for (final c in cols)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${c['name']}: ${_show('${c['kind']}', _value(r, c)) ?? '—'}',
              style: TextStyle(color: vd.inkMuted, fontSize: 13),
            ),
          ),
    ];
  }

  static String? _value(Map r, Map c) {
    final cell = ((r['cells'] as Map?) ?? const {})['${c['id']}'] as Map?;
    final v = '${cell?['value'] ?? ''}'.trim();
    return v.isEmpty ? null : v;
  }

  static bool _filled(Map<String, dynamic> p, List<Map<String, dynamic>> c) {
    final rows = EmsApiService.rows(p['rows'] ?? const []);
    return rows.isNotEmpty &&
        rows.every((r) => c.every((col) => _value(r, col) != null));
  }

  static String? _show(String kind, String? v) {
    if (v == null) return null;
    if (kind == 'yes_no') return v == 'yes' ? 'Có' : 'Không';
    if (kind == 'date' && v.length >= 10) {
      return '${v.substring(8, 10)}/${v.substring(5, 7)}/${v.substring(0, 4)}';
    }
    return v;
  }

  Future<void> _open(Map<String, dynamic> list) async {
    final m = widget.mine;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TableScreen(
          spaceId: widget.spaceId,
          listId: '${list['id']}',
          title: '${list['title'] ?? ''}',
          handIn: [
            if (_mineOpen && m != null)
              TablePiece(
                assignmentId: '${m['id']}',
                status: '${m['status']}',
                title: '',
                review: widget.review,
              ),
          ],
        ),
      ),
    );
    widget.onBack();
  }
}
