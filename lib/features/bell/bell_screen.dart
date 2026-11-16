import 'package:flutter/material.dart';

import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../work/piece_screen.dart';
import '../work/work_api.dart';

/// The bell for office accounts and teachers with office duties (Overlord
/// slice): `GET /v1/notifications?work=1` (work bells only; system rows stay
/// on the server, untouched). A bell about a piece opens that piece natively.
class BellScreen extends StatefulWidget {
  const BellScreen({super.key});

  @override
  State<BellScreen> createState() => _BellScreenState();
}

class _BellScreenState extends State<BellScreen> {
  List<Map<String, dynamic>>? _rows;

  /// The same number the home shows: /auth/app/me counts.bell_work_unread.
  int? _unread;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await EmsApiService.sendMap(
        'GET',
        '/v1/notifications',
        query: const {'limit': '50', 'work': '1'},
      );
      final rows = EmsApiService.rows(b['notifications'] ?? const []);
      try {
        final me = await EmsApiService.sendMap('GET', '/auth/app/me');
        _unread = asInt((me['counts'] as Map?)?['bell_work_unread']);
      } catch (_) {}
      if (mounted)
        setState(() {
          _rows = rows;
          _error = null;
        });
    } on EmsException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        handleCrmAuthError(context, e);
        return;
      }
      setState(() => _error = e.message);
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    if (n['read_at'] == null) {
      EmsApiService.sendMap(
        'PATCH',
        '/v1/notifications/${n['kind']}/${n['id']}/read',
      ).catchError((_) => <String, dynamic>{});
      setState(() {
        n['read_at'] = DateTime.now().toIso8601String();
        if (_unread != null && _unread! > 0) _unread = _unread! - 1;
      });
    }
    final p = (n['payload'] as Map?) ?? const {};
    final taskId = p['task_id']?.toString();
    if (taskId != null && taskId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PieceScreen(taskId: taskId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final rows = _rows;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: Text(
          _unread == null || _unread == 0
              ? 'Thông báo'
              : 'Thông báo · $_unread chưa đọc',
        ),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : rows == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: rows.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Chưa có thông báo việc nào.')),
                      ],
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: vd.hairline),
                      itemBuilder: (_, i) {
                        final n = rows[i];
                        final unread = n['read_at'] == null;
                        final hasPiece =
                            ((n['payload'] as Map?)?['task_id']) != null;
                        return ListTile(
                          onTap: () => _open(n),
                          leading: Icon(
                            hasPiece
                                ? Icons.task_alt
                                : Icons.notifications_none,
                            color: unread ? vd.accent : vd.inkFaint,
                          ),
                          title: Text(
                            '${n['title'] ?? ''}',
                            style: TextStyle(
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          subtitle: Text(
                            '${n['body'] ?? ''}\n${whenLabel(n['created_at'])}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: hasPiece
                              ? const Icon(Icons.chevron_right)
                              : null,
                        );
                      },
                    ),
            ),
    );
  }
}
