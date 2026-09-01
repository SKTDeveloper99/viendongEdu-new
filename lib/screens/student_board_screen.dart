import 'package:flutter/material.dart';
import '../services/ems_api_service.dart';

/// Bảng tin — thông tin trung tâm gửi cho học viên này.
///
/// Chỉ ĐỌC. Nội dung hiển thị là nguyên văn server đã đóng băng lúc phát hành;
/// app không ghép trường và không dựng lại từ mẫu.
///
/// Khi EMS không truy cập được: hiện trạng thái lỗi CÓ NÚT THỬ LẠI ngay trong
/// màn hình này — không bao giờ để trắng màn, và không ảnh hưởng màn hình IMS.
class StudentBoardScreen extends StatefulWidget {
  const StudentBoardScreen({super.key});

  @override
  State<StudentBoardScreen> createState() => _StudentBoardScreenState();
}

class _StudentBoardScreenState extends State<StudentBoardScreen>
    with WidgetsBindingObserver {
  static const _orange = Color(0xFFE65100);

  List<AnnouncementItem> _items = [];
  bool _loading = true;
  String? _error;

  /// Chặn gọi chồng khi người dùng bấm liên tục hoặc app resume nhiều lần.
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_inFlight) return;
    _inFlight = true;
    if (mounted && _items.isEmpty) setState(() => _loading = true);
    try {
      final items = await EmsApiService.board();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } finally {
      _inFlight = false;
    }
  }

  /// Mở một thông báo: đóng dấu đã đọc (idempotent) rồi hiện toàn văn.
  ///
  /// Cập nhật giao diện TRƯỚC khi chờ mạng, và hoàn nguyên nếu server từ chối:
  /// người đọc không phải chờ một vòng round-trip để thấy mình vừa mở cái gì.
  Future<void> _open(AnnouncementItem item) async {
    final wasUnread = item.isUnread;
    if (wasUnread) {
      setState(() => item.readAt = DateTime.now());
      try {
        await EmsApiService.markRead(item.id);
      } on EmsException {
        if (mounted) setState(() => item.readAt = null);
      }
    }
    if (!mounted) return;
    await _showDetail(item);
  }

  Future<void> _acknowledge(AnnouncementItem item) async {
    final before = item.acknowledgedAt;
    setState(() => item.acknowledgedAt = DateTime.now());
    try {
      await EmsApiService.acknowledge(item.id);
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() => item.acknowledgedAt = before);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showDetail(AnnouncementItem item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (_, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(children: [
                  _CategoryChip(item: item),
                  const Spacer(),
                  Text(_formatDate(item.publishedAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
                const SizedBox(height: 12),
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, height: 1.35)),
                const SizedBox(height: 14),
                SelectableText(item.body,
                    style: const TextStyle(fontSize: 15, height: 1.65)),
                if (item.images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final img in item.images) _BoardImage(image: img),
                ],
                const SizedBox(height: 24),
                if (item.mustRead)
                  item.acknowledgedAt != null
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text('Đã xác nhận',
                              style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600)),
                        ])
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await _acknowledge(item);
                              setSheetState(() {});
                            },
                            child: const Text('Tôi đã đọc và hiểu',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Bảng tin',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }

    // Trạng thái lỗi phải CUỘN ĐƯỢC, nếu không RefreshIndicator không kéo được
    // và người dùng kẹt lại với một màn hình chết.
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.cloud_off, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.5)),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _orange,
                side: const BorderSide(color: _orange),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              onPressed: _load,
              child: const Text('Thử lại'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Chưa có thông báo nào.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _items.length,
      itemBuilder: (_, i) => _AnnouncementCard(
        item: _items[i],
        onTap: () => _open(_items[i]),
      ),
    );
  }
}

/// Ảnh của bảng tin. Nằm sau Bearer token nên phải gửi kèm header; giữ đúng tỉ
/// lệ thật để danh sách không nhảy khi ảnh tải xong, và hỏng ảnh thì hiện ô
/// xám có biểu tượng chứ không phải một vệt đỏ giữa thông báo.
class _BoardImage extends StatelessWidget {
  const _BoardImage({required this.image, this.inCard = false});
  final AnnouncementImage image;
  final bool inCard;

  @override
  Widget build(BuildContext context) {
    final img = Image.network(
      image.absoluteUrl,
      headers: EmsApiService.authHeaders,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              height: inCard ? null : 180,
              color: Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFE65100)),
                ),
              ),
            ),
      errorBuilder: (_, __, ___) => Container(
        height: inCard ? null : 140,
        color: Colors.grey[200],
        child: Icon(Icons.broken_image_outlined,
            color: Colors.grey[500], size: 28),
      ),
    );

    if (inCard) return img;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: image.aspectRatio != null
            ? AspectRatio(aspectRatio: image.aspectRatio!, child: img)
            : img,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.item});
  final AnnouncementItem item;

  @override
  Widget build(BuildContext context) {
    final urgent = item.category == 'urgent';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFEE2E2) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.isCorrection ? 'Đính chính' : item.categoryLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: urgent ? const Color(0xFFB91C1C) : const Color(0xFFE65100),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item, required this.onTap});
  final AnnouncementItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: item.isUnread
            ? Border.all(color: const Color(0xFFFFCC80), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _CategoryChip(item: item),
                  const SizedBox(width: 6),
                  if (item.needsAcknowledgement)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Bắt buộc đọc',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB91C1C))),
                    ),
                  const Spacer(),
                  if (item.isUnread)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                          color: Color(0xFFE65100), shape: BoxShape.circle),
                    ),
                ]),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight:
                        item.isUnread ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.body.replaceAll('\n', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, height: 1.45, color: Colors.grey[700]),
                ),
                if (item.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: item.images.first.aspectRatio ?? 16 / 9,
                      child: _BoardImage(image: item.images.first, inCard: true),
                    ),
                  ),
                  if (item.images.length > 1) ...[
                    const SizedBox(height: 6),
                    Text('+${item.images.length - 1} ảnh nữa',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.schedule, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(_StudentBoardScreenState._formatDate(item.publishedAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if (item.acknowledgedAt != null) ...[
                    const Spacer(),
                    const Icon(Icons.check_circle,
                        size: 13, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('Đã xác nhận',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
