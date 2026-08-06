import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _notiBase = 'https://noti-backend-eight.vercel.app';

class _UserItem {
  final String hocVienId;
  final String mssv;
  final String hoTen;
  final String? userid;
  final bool isOnline;
  final int tokenCount;
  final DateTime? updatedAt;

  const _UserItem({
    required this.hocVienId,
    required this.mssv,
    required this.hoTen,
    this.userid,
    required this.isOnline,
    required this.tokenCount,
    this.updatedAt,
  });

  factory _UserItem.fromJson(Map<String, dynamic> j) => _UserItem(
        hocVienId: j['hocVienId'] as String? ?? '',
        mssv: j['mssv'] as String? ?? '',
        hoTen: j['hoTen'] as String? ?? '',
        userid: j['userid'] as String?,
        isOnline: j['isOnline'] as bool? ?? false,
        tokenCount: j['tokenCount'] as int? ?? 0,
        updatedAt: j['updatedAt'] != null
            ? DateTime.tryParse(j['updatedAt'] as String)
            : null,
      );
}

class GvUserListScreen extends StatefulWidget {
  const GvUserListScreen({super.key});

  @override
  State<GvUserListScreen> createState() => _GvUserListScreenState();
}

class _GvUserListScreenState extends State<GvUserListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<_UserItem> _all = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$_notiBase/api/token/users'))
          .timeout(const Duration(seconds: 10));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        final list = (json['data'] as List)
            .map((e) => _UserItem.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _all = list;
          _loading = false;
        });
      } else {
        setState(() {
          _error = json['message'] as String? ?? 'Lỗi không xác định';
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Không thể tải danh sách';
        _loading = false;
      });
    }
  }

  List<_UserItem> _filtered(bool online) {
    final q = _search.trim().toLowerCase();
    return _all.where((u) {
      if (u.isOnline != online) return false;
      if (q.isEmpty) return true;
      return u.hoTen.toLowerCase().contains(q) || u.mssv.toLowerCase().contains(q);
    }).toList();
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
    final onlineList = _filtered(true);
    final offlineList = _filtered(false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Người dùng',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (!_loading)
                      Text(
                        '${_all.length} người',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          color: Colors.white, size: 22),
                      onPressed: _fetch,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo tên, MSSV...',
                      hintStyle:
                          TextStyle(color: Colors.white60, fontSize: 14),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.white70, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tabs
                TabBar(
                  controller: _tab,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: [
                    Tab(
                        text:
                            'Đang đăng nhập (${_filtered(true).length})'),
                    Tab(
                        text:
                            'Đã đăng nhập (${_filtered(false).length})'),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFE65100)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.grey, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style:
                                    const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _fetch,
                              child: const Text('Thử lại',
                                  style:
                                      TextStyle(color: Color(0xFFE65100))),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tab,
                        children: [
                          _UserListView(
                            items: onlineList,
                            online: true,
                            formatDate: _formatDate,
                          ),
                          _UserListView(
                            items: offlineList,
                            online: false,
                            formatDate: _formatDate,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserListView extends StatelessWidget {
  final List<_UserItem> items;
  final bool online;
  final String Function(DateTime?) formatDate;

  const _UserListView({
    required this.items,
    required this.online,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              online ? Icons.person_off : Icons.history,
              color: Colors.grey,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              online
                  ? 'Không có ai đang đăng nhập'
                  : 'Chưa có lịch sử đăng nhập',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFE65100),
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, i) => _UserCard(
          item: items[i],
          formatDate: formatDate,
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final _UserItem item;
  final String Function(DateTime?) formatDate;

  const _UserCard({required this.item, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
        border: item.isOnline
            ? Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: item.isOnline
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                    : Colors.grey[200],
                child: Text(
                  item.hoTen.isNotEmpty
                      ? item.hoTen[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: item.isOnline
                        ? const Color(0xFF4CAF50)
                        : Colors.grey[600],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.isOnline
                        ? const Color(0xFF4CAF50)
                        : Colors.grey[400],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.hoTen.isNotEmpty ? item.hoTen : 'ID: ${item.hocVienId}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (item.mssv.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.mssv,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
                if (item.userid != null && item.userid!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'TK: ${item.userid}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  formatDate(item.updatedAt),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.isOnline
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: item.isOnline
                        ? const Color(0xFF4CAF50)
                        : Colors.grey[500],
                  ),
                ),
              ),
              if (item.tokenCount > 1) ...[
                const SizedBox(height: 4),
                Text(
                  '${item.tokenCount} thiết bị',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
