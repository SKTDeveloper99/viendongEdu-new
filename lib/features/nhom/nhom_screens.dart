import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../common/load_error.dart';
import '../work/piece_screen.dart';
import '../work/work_api.dart';
import 'nhom_api.dart';
import 'small_group_api.dart';
import 'small_group_screens.dart';
import '../notices/notice_screens.dart';

part 'nhom_screens_parts_1.dart';
part 'nhom_screens_parts_2.dart';

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
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        await _guard(context, e, (m) {
          if (_rows == null) {
            setState(() => _error = m);
          } else {
            showErrorSnack(context, m);
          }
        });
      }
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
              this.context,
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
          ? LoadError(
              message: _error!,
              onRetry: () {
                setState(() => _error = null);
                _load();
              },
            )
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

  /// A post is on its way: a second tap does nothing (no double post).
  bool _posting = false;

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

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: vd.bg,
        appBar: AppBar(
          title: Text(
            // Opened from the bell, a push or a notice it is given no name:
            // the loaded group's own name wins once it is here.
            '${_space['name'] ?? ''}'.trim().isNotEmpty
                ? '${_space['name']}'
                : widget.name,
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
            ? LoadError(
                message: _error!,
                onRetry: () {
                  _set(() => _error = null);
                  _load();
                },
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

  // Lets the extensions in this library's parts call setState.
  void _set(VoidCallback f) => setState(f);
}
