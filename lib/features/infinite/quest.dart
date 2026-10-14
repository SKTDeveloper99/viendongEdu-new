import 'dart:convert';
import 'dart:math' as math;

/// Viễn Đông Infinite: be at school, do a small quest, unlock a cosmetic.
///
/// Quests come from Firebase Remote Config (`infinite_quests`, JSON); the
/// built-in [defaultQuestsJson] is used until the first fetch succeeds.
/// Cosmetics only — nothing here touches grades, money or attendance.

class School {
  const School(this.lat, this.lng, this.radiusM);
  final double lat;
  final double lng;
  final double radiusM;
}

class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.desc,
    required this.rewards,
    this.url,
    this.code,
    this.from,
    this.to,
  });

  final String id;
  final String title;
  final String desc;
  final List<String> rewards;

  /// Link the student must open first (school TikTok, Fanpage, website).
  final String? url;

  /// Code word hidden in the post; null = no code needed.
  final String? code;
  final DateTime? from;
  final DateTime? to;

  bool activeOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (from != null && d.isBefore(from!)) return false;
    if (to != null && d.isAfter(to!)) return false;
    return true;
  }

  bool codeMatches(String typed) =>
      code == null || normalizeCode(typed) == normalizeCode(code!);
}

class QuestBook {
  const QuestBook(this.school, this.quests);
  final School school;
  final List<Quest> quests;
}

String normalizeCode(String s) =>
    s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

String? _text(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Parses the Remote Config JSON; returns null when it is unusable so the
/// caller keeps the built-in book.
QuestBook? parseQuestBook(String raw) {
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final s = j['school'] as Map<String, dynamic>;
    final school = School(
      (s['lat'] as num).toDouble(),
      (s['lng'] as num).toDouble(),
      (s['radius_m'] as num? ?? 150).toDouble(),
    );
    final quests = <Quest>[
      for (final q in (j['quests'] as List).cast<Map<String, dynamic>>())
        Quest(
          id: q['id'] as String,
          title: q['title'] as String,
          desc: _text(q['desc']) ?? '',
          rewards: (q['rewards'] as List? ?? const []).cast<String>(),
          url: _text(q['url']),
          code: _text(q['code']),
          from: _date(q['from']),
          to: _date(q['to']),
        ),
    ];
    return QuestBook(school, quests);
  } catch (_) {
    return null;
  }
}

/// Great-circle distance in metres.
double distanceM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// At school when the fix lies inside the radius, forgiving up to 50 m of
/// reported GPS inaccuracy (indoors a phone often reports 20–40 m).
bool atSchool(School s, double lat, double lng, double accuracyM) =>
    distanceM(s.lat, s.lng, lat, lng) <= s.radiusM + math.min(accuracyM, 50);

/// Cosmetic catalogue. Colours are names of `context.vd` tokens.
class Cosmetic {
  const Cosmetic(this.id, this.name, {this.title, this.frameToken});
  final String id;
  final String name;

  /// Shown under the student's name when equipped.
  final String? title;

  /// Frame colour token: primary, accent, warning, danger, success, evening.
  final String? frameToken;
  bool get isFrame => frameToken != null;
}

const cosmetics = <Cosmetic>[
  Cosmetic('frame_blue', 'Khung Viễn Đông', frameToken: 'primary'),
  Cosmetic('frame_gold', 'Khung Vàng', frameToken: 'warning'),
  Cosmetic('frame_red', 'Khung Đỏ Rực', frameToken: 'danger'),
  Cosmetic('frame_night', 'Khung Đêm', frameToken: 'evening'),
  Cosmetic('title_explorer', 'Danh hiệu', title: 'Thám hiểm Viễn Đông'),
  Cosmetic('title_tiktok', 'Danh hiệu', title: 'Fan TikTok'),
  Cosmetic('title_fanpage', 'Danh hiệu', title: 'Fan Fanpage'),
];

Cosmetic? cosmeticById(String id) =>
    cosmetics.where((c) => c.id == id).firstOrNull;

/// Built in so the game works before Remote Config is published.
const defaultQuestsJson = '''
{
  "school": {"lat": 10.851835539538312, "lng": 106.62820562524071, "radius_m": 150},
  "quests": [
    {"id": "checkin-1", "title": "Có mặt ở trường",
     "desc": "Đến trường và bấm Nhận thưởng khi đang ở trong khuôn viên.",
     "rewards": ["frame_blue", "title_explorer"]},
    {"id": "tiktok-1", "title": "Ghé TikTok của trường",
     "desc": "Mở TikTok của trường, xem một video, rồi nhận thưởng khi ở trường.",
     "url": "https://www.tiktok.com/@caodangviendong",
     "rewards": ["frame_night", "title_tiktok"]},
    {"id": "fanpage-1", "title": "Ghé Fanpage của trường",
     "desc": "Mở Fanpage của trường, đọc bài mới nhất, rồi nhận thưởng khi ở trường.",
     "url": "https://www.facebook.com/Tuyensinhcaodangviendong/",
     "rewards": ["frame_gold", "title_fanpage"]}
  ]
}
''';
