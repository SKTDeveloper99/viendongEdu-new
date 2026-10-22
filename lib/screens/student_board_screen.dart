import '../components/skeleton.dart';
import '../components/announcement_body.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'stale_note.dart';
import 'package:flutter/material.dart';
import '../services/ems_api_service.dart';
import '../data/api/board_api.dart';
import '../components/vd_fade_in.dart';
import '../theme/vd_motion.dart';
import '../theme/vd_tokens.dart';

part 'widgets/student_board_widgets.dart';

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
  List<AnnouncementItem> _items = [];
  DateTime? _staleAt;
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
      final r = await BoardApi.boardCached(
        onStored: (stored, _) {
          if (!mounted || _items.isNotEmpty) return;
          setState(() {
            _items = stored;
            _loading = false;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _staleAt = r.fresh ? null : r.savedAt;
        _items = r.data;
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
        await BoardApi.markRead(item.id);
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
      await BoardApi.acknowledge(item.id);
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() => item.acknowledgedAt = before);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showDetail(AnnouncementItem item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.vd.surface,
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
                      color: context.vd.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _CategoryChip(item: item),
                    Text(
                      _formatDate(item.publishedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.vd.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                AnnouncementBody(body: item.body),
                if (item.images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final img in item.images)
                    _BoardImage(image: img, width: 1080),
                ],
                const SizedBox(height: 24),
                if (item.mustRead)
                  item.acknowledgedAt != null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: context.vd.success,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Đã xác nhận',
                              style: TextStyle(
                                color: context.vd.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.vd.primary,
                              foregroundColor: context.vd.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              await _acknowledge(item);
                              setSheetState(() {});
                            },
                            child: const Text(
                              'Tôi đã đọc và hiểu',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
      backgroundColor: context.vd.bg,
      appBar: AppBar(
        backgroundColor: context.vd.primary,
        foregroundColor: context.vd.onPrimary,
        elevation: 0,
        title: const Text(
          'Bảng tin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: context.vd.primary,
        onRefresh: _load,
        child: AnimatedSwitcher(
          duration: VdMotion.of(context).standard,
          child: KeyedSubtree(
            key: ValueKey<bool>(_loading),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return skeletonList(accentColor: context.vd.primary);

    // Trạng thái lỗi phải CUỘN ĐƯỢC, nếu không RefreshIndicator không kéo được
    // và người dùng kẹt lại với một màn hình chết.
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.cloud_off, size: 56, color: context.vd.inkFaint),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.vd.inkMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.vd.primary,
                side: BorderSide(color: context.vd.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
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
          Icon(Icons.inbox_outlined, size: 56, color: context.vd.inkFaint),
          const SizedBox(height: 16),
          Text(
            'Chưa có thông báo nào.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.vd.inkMuted),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (_staleAt != null) StaleNote(_staleAt!),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: _items.length,
            itemBuilder: (_, i) => VdFadeIn(
              index: i,
              child: _AnnouncementCard(
                item: _items[i],
                onTap: () => _open(_items[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ảnh của bảng tin. Nằm sau Bearer token nên phải gửi kèm header; giữ đúng tỉ
/// lệ thật để danh sách không nhảy khi ảnh tải xong, và hỏng ảnh thì hiện ô
/// xám có biểu tượng chứ không phải một vệt đỏ giữa thông báo.
