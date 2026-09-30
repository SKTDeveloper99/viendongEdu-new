import '../services/ems_api_service.dart';

/// Một tấm ảnh kèm theo thông báo.
///
/// [url] là đường dẫn tương đối server trả về; [absoluteUrl] ghép với base để
/// widget ảnh dùng trực tiếp. Ảnh cần Bearer token nên phải kèm [authHeaders].
class AnnouncementImage {
  final String id;
  final String url;
  final int? width;
  final int? height;

  const AnnouncementImage({
    required this.id,
    required this.url,
    this.width,
    this.height,
  });

  factory AnnouncementImage.fromJson(Map<String, dynamic> j) =>
      AnnouncementImage(
        id: j['id']?.toString() ?? '',
        url: j['url']?.toString() ?? '',
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
      );

  /// Server trả '/api/v1/...' còn baseUrl đã kết thúc bằng '/api' — cắt phần
  /// '/api' trùng để không thành '/api/api/v1/...'.
  String get absoluteUrl {
    final base = EmsApiService.baseUrl;
    final path = url.startsWith('/api') ? url.substring(4) : url;
    return '$base$path';
  }

  double? get aspectRatio => (width != null && height != null && height! > 0)
      ? width! / height!
      : null;
}

class BoardUnread {
  final int unread;
  final int mustReadPending;
  const BoardUnread({required this.unread, required this.mustReadPending});
}

/// Một thông báo đã đến tay học viên này.
///
/// `body` là NGUYÊN VĂN server đã đóng băng lúc phát hành — app không ghép
/// trường, không dựng lại từ mẫu.
class AnnouncementItem {
  final String id;
  final String title;
  final String body;
  final String? category;
  final bool mustRead;
  final bool isCorrection;
  final DateTime? publishedAt;
  final List<AnnouncementImage> images;
  DateTime? readAt;
  DateTime? acknowledgedAt;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    this.category,
    this.mustRead = false,
    this.isCorrection = false,
    this.publishedAt,
    this.images = const [],
    this.readAt,
    this.acknowledgedAt,
  });

  bool get isUnread => readAt == null;
  bool get needsAcknowledgement => mustRead && acknowledgedAt == null;

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  factory AnnouncementItem.fromJson(Map<String, dynamic> j) => AnnouncementItem(
    id: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString() ?? '',
    category: j['category']?.toString(),
    mustRead: j['must_read'] == true,
    isCorrection: j['is_correction'] == true,
    publishedAt: _date(j['published_at']),
    images: (j['images'] is List)
        ? (j['images'] as List)
              .whereType<Map<String, dynamic>>()
              .map(AnnouncementImage.fromJson)
              .toList()
        : const [],
    readAt: _date(j['read_at']),
    acknowledgedAt: _date(j['acknowledged_at']),
  );

  static const Map<String, String> categoryLabels = {
    'general': 'Thông báo chung',
    'schedule': 'Lịch học / lịch thi',
    'deadline': 'Hạn chót',
    'urgent': 'Khẩn',
  };

  String get categoryLabel => categoryLabels[category] ?? 'Thông báo';
}
