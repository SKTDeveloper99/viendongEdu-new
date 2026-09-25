import 'package:flutter/material.dart';
import '../services/crm_session_guard.dart';
import '../services/ems_api_service.dart';

/// Danh sách thông báo — CHỈ giảng viên (route '/teacher/notifications',
/// CRM). Học viên đọc thông báo qua Bảng tin ('/student_board',
/// [EmsApiService.board]) kể từ khi gỡ backend Vercel “noti-backend-eight” (bot
/// A5, 2026-09-25) — xem `hv_home_screen.dart`, không còn nút nào trỏ vào
/// màn hình này cho học viên.
class _Noti {
  final String id;
  final String title;
  final String body;
  final String status;
  final DateTime? sentAt;

  _Noti({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    this.sentAt,
  });

  bool get isRead => status == 'read';

  factory _Noti.fromJson(Map<String, dynamic> j) => _Noti(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        status: j['status'] as String? ?? 'unread',
        sentAt: j['sentAt'] != null ? DateTime.tryParse(j['sentAt'] as String) : null,
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<_Noti> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await EmsApiService.teacherNotifications();
      if (!mounted) return;
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(_Noti.fromJson)
          .toList();
      setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() { _error = 'Không thể tải thông báo'; _loading = false; });
    }
  }

  Future<void> _markRead(String notifyID) async {
    try {
      await EmsApiService.markTeacherNotificationRead(notifyID);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((n) => n.id == notifyID
                ? _Noti(id: n.id, title: n.title, body: n.body, status: 'read', sentAt: n.sentAt)
                : n)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      await handleCrmAuthError(context, e);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await EmsApiService.markAllTeacherNotificationsRead();
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((n) => _Noti(id: n.id, title: n.title, body: n.body, status: 'read', sentAt: n.sentAt))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      await handleCrmAuthError(context, e);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Thông báo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Đọc tất cả',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE65100)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.grey, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _fetch,
                              child: const Text('Thử lại',
                                  style: TextStyle(color: Color(0xFFE65100))),
                            ),
                          ],
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_none,
                                    color: Colors.grey, size: 56),
                                SizedBox(height: 12),
                                Text('Chưa có thông báo nào',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 15)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFE65100),
                            onRefresh: _fetch,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final n = _items[i];
                                return _NotiCard(
                                  noti: n,
                                  formatDate: _formatDate,
                                  onTap: () {
                                    if (!n.isRead) _markRead(n.id);
                                    _showDetail(n);
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showDetail(_Noti n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(n.title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_formatDate(n.sentAt),
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 24),
            Text(n.body,
                style:
                    const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NotiCard extends StatelessWidget {
  final _Noti noti;
  final String Function(DateTime?) formatDate;
  final VoidCallback onTap;

  const _NotiCard({
    required this.noti,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: noti.isRead ? Colors.white : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
          border: noti.isRead
              ? null
              : Border.all(color: const Color(0xFFFFCC80), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: noti.isRead
                    ? Colors.grey[200]
                    : const Color(0xFFE65100).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                noti.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: noti.isRead ? Colors.grey : const Color(0xFFE65100),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          noti.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: noti.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!noti.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE65100),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    noti.body,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatDate(noti.sentAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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
