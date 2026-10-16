import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

/// Viễn Đông Infinite: be at school, do a small quest, unlock a cosmetic.
///
/// Everything a student sees comes from Remote Config `infinite_book_v2`
/// (JSON). The app only knows a few quest kinds; quests, cosmetics, the map
/// picture and its pins are data, so they change without an app build.
/// Cosmetics only — nothing here touches grades, money or attendance.
///
/// Robustness rules: a bad quest or cosmetic is skipped, never the whole
/// book; an unknown quest kind shows as "update the app"; unknown reward ids
/// are ignored. Codes are never shipped — only `code_sha256`, the SHA-256 of
/// `"<quest id>:<normalized code>"`.

class School {
  const School(this.lat, this.lng, this.radiusM);
  final double lat;
  final double lng;
  final double radiusM;
}

/// Where a quest sits on the map picture, as fractions of width and height.
class Spot {
  const Spot(this.x, this.y, this.label);
  final double x;
  final double y;
  final String label;
}

/// The lobby picture: a bundled asset, optionally replaced by a URL.
class MapArt {
  const MapArt({
    this.asset = defaultMapAsset,
    this.url,
    this.aspect = 1678 / 937,
    this.focusX = 0.5,
  });
  final String asset;
  final String? url;

  /// Width ÷ height of the picture.
  final double aspect;

  /// Horizontal point (0–1) centred when the map opens.
  final double focusX;
}

const defaultMapAsset = 'assets/infinite/school_map.webp';

enum QuestKind { checkin, link, code, qr, quiz, unknown }

class Quest {
  const Quest({
    required this.id,
    required this.title,
    this.kind = QuestKind.checkin,
    this.desc = '',
    this.rewards = const [],
    this.url,
    this.codeHash,
    this.hint,
    this.question,
    this.choices = const [],
    this.from,
    this.to,
    this.place,
    this.spot,
    this.atSchool = true,
  });

  final String id;
  final QuestKind kind;
  final String title;
  final String desc;
  final List<String> rewards;

  /// Link the student must open first (school TikTok, Fanpage, website).
  final String? url;

  /// SHA-256 of the accepted code / QR value / quiz answer; null = none.
  final String? codeHash;

  /// Where to find the code (shown under the input).
  final String? hint;
  final String? question;
  final List<String> choices;
  final DateTime? from;
  final DateTime? to;

  /// Own location (e.g. a test spot); null = the school point.
  final School? place;
  final Spot? spot;

  /// Claim needs a GPS fix inside the school (or [place]).
  final bool atSchool;

  bool get playable => kind != QuestKind.unknown;
  bool get needsCode => codeHash != null;

  bool activeOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (from != null && d.isBefore(from!)) return false;
    if (to != null && d.isAfter(to!)) return false;
    return true;
  }

  bool codeMatches(String typed) =>
      codeHash == null || codeSha256(id, typed) == codeHash;
}

/// Cosmetic catalogue entry. Colours are names of `context.vd` tokens.
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

class QuestBook {
  const QuestBook({
    required this.school,
    required this.quests,
    this.cosmetics = builtInCosmetics,
    this.map = const MapArt(),
    this.enabled = true,
    this.notice,
    this.skipped = 0,
  });
  final School school;
  final List<Quest> quests;
  final List<Cosmetic> cosmetics;
  final MapArt map;

  /// Kill switch: false shows [notice] instead of quests.
  final bool enabled;
  final String? notice;

  /// Entries dropped while parsing (reported, never fatal).
  final int skipped;

  Cosmetic? cosmeticById(String id) =>
      cosmetics.where((c) => c.id == id).firstOrNull;
}

String normalizeCode(String s) =>
    s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

String codeSha256(String questId, String code) =>
    sha256.convert(utf8.encode('$questId:${normalizeCode(code)}')).toString();

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

String? _text(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

double? _num(Object? v) => v is num ? v.toDouble() : null;

final _idPattern = RegExp(r'^[a-z0-9-]{1,40}$');

School? _point(Object? v) {
  if (v is! Map) return null;
  final lat = _num(v['lat']), lng = _num(v['lng']);
  if (lat == null || lng == null) return null;
  return School(lat, lng, _num(v['radius_m']) ?? 150);
}

Spot? _spot(Object? v) {
  if (v is! Map) return null;
  final x = _num(v['x']), y = _num(v['y']);
  if (x == null || y == null || x < 0 || x > 1 || y < 0 || y > 1) return null;
  return Spot(x, y, _text(v['label']) ?? '');
}

QuestKind _kind(Object? v) => switch (v) {
  null || 'checkin' => QuestKind.checkin,
  'link' => QuestKind.link,
  'code' => QuestKind.code,
  'qr' => QuestKind.qr,
  'quiz' => QuestKind.quiz,
  _ => QuestKind.unknown,
};

Quest? _quest(Object? v) {
  if (v is! Map) return null;
  final id = v['id'], title = _text(v['title']);
  if (id is! String || !_idPattern.hasMatch(id) || title == null) return null;
  final kind = _kind(v['kind']);
  final url = _text(v['url']);
  final hash = _text(v['code_sha256'])?.toLowerCase();
  final choices = [
    for (final c in v['choices'] is List ? v['choices'] as List : const [])
      ?_text(c),
  ];
  // A kind without what it needs would be unwinnable: drop it.
  if (kind == QuestKind.link && url == null) return null;
  if ((kind == QuestKind.code || kind == QuestKind.qr) && hash == null) {
    return null;
  }
  if (kind == QuestKind.quiz && (hash == null || choices.length < 2)) {
    return null;
  }
  return Quest(
    id: id,
    kind: kind,
    title: title,
    desc: _text(v['desc']) ?? '',
    rewards: [
      for (final r in v['rewards'] is List ? v['rewards'] as List : const [])
        if (r is String) r,
    ],
    url: url,
    codeHash: hash,
    hint: _text(v['hint']),
    question: _text(v['question']),
    choices: choices,
    from: _date(v['from']),
    to: _date(v['to']),
    place: _point(v['place']),
    spot: _spot(v['spot']),
    atSchool: v['at_school'] is bool ? v['at_school'] as bool : true,
  );
}

Cosmetic? _cosmetic(Object? v) {
  if (v is! Map) return null;
  final id = v['id'], name = _text(v['name']);
  if (id is! String || !_idPattern.hasMatch(id.replaceAll('_', '-'))) {
    return null;
  }
  if (name == null) return null;
  final frame = _text(v['frame']), title = _text(v['title']);
  if (frame == null && title == null) return null;
  return Cosmetic(id, name, title: title, frameToken: frame);
}

/// Parses `infinite_book_v2`. Returns null only when the whole document is
/// unusable (not JSON, no school point) so the caller keeps its last good
/// book. Single bad quests or cosmetics are skipped and counted.
QuestBook? parseQuestBook(String raw) {
  final Object? j;
  try {
    j = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final school = _point(j['school']);
  if (school == null) return null;

  var skipped = 0;
  final quests = <Quest>[];
  final seen = <String>{};
  for (final q in j['quests'] is List ? j['quests'] as List : const []) {
    final parsed = _quest(q);
    if (parsed == null || !seen.add(parsed.id)) {
      skipped++;
    } else {
      quests.add(parsed);
    }
  }

  final byId = {for (final c in builtInCosmetics) c.id: c};
  for (final c in j['cosmetics'] is List ? j['cosmetics'] as List : const []) {
    final parsed = _cosmetic(c);
    if (parsed == null) {
      skipped++;
    } else {
      byId[parsed.id] = parsed;
    }
  }

  final m = j['map'];
  final map = m is Map
      ? MapArt(
          url: _text(m['url']),
          aspect: (_num(m['aspect']) ?? 0) > 0.3
              ? _num(m['aspect'])!
              : const MapArt().aspect,
          focusX: (_num(m['focus_x']) ?? 0.5).clamp(0.0, 1.0),
        )
      : const MapArt();

  return QuestBook(
    school: school,
    quests: quests,
    cosmetics: byId.values.toList(),
    map: map,
    enabled: j['enabled'] is bool ? j['enabled'] as bool : true,
    notice: _text(j['notice']),
    skipped: skipped,
  );
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

/// Always available, so old rewards keep their names if a config drops them.
const builtInCosmetics = <Cosmetic>[
  Cosmetic('frame_blue', 'Khung Viễn Đông', frameToken: 'primary'),
  Cosmetic('frame_gold', 'Khung Vàng', frameToken: 'warning'),
  Cosmetic('frame_red', 'Khung Đỏ Rực', frameToken: 'danger'),
  Cosmetic('frame_night', 'Khung Đêm', frameToken: 'evening'),
  Cosmetic('frame_green', 'Khung Sân Cỏ', frameToken: 'success'),
  Cosmetic('frame_teal', 'Khung Thông Thái', frameToken: 'accent'),
  Cosmetic('title_explorer', 'Danh hiệu', title: 'Thám hiểm Viễn Đông'),
  Cosmetic('title_tiktok', 'Danh hiệu', title: 'Fan TikTok'),
  Cosmetic('title_fanpage', 'Danh hiệu', title: 'Fan Fanpage'),
  Cosmetic('title_hunter', 'Danh hiệu', title: 'Thợ Săn Mã'),
  Cosmetic('title_scholar', 'Danh hiệu', title: 'Thông Thái Viễn Đông'),
  Cosmetic('title_striker', 'Danh hiệu', title: 'Chân Sút Sân Trường'),
];

/// Built in so the game works before Remote Config is published or when the
/// device has never fetched it. Kept identical to remoteconfig.template.json.
const defaultQuestsJson = '''
{
  "v": 2,
  "enabled": true,
  "school": {"lat": 10.851835539538312, "lng": 106.62820562524071, "radius_m": 150},
  "map": {"aspect": 1.7908, "focus_x": 0.45},
  "quests": [
    {"id": "checkin-1", "kind": "checkin", "title": "Có mặt ở trường",
     "desc": "Đến cổng chính và bấm Nhận thưởng khi đang ở trong khuôn viên.",
     "spot": {"x": 0.426, "y": 0.6, "label": "Cổng chính"},
     "rewards": ["frame_blue", "title_explorer"]},
    {"id": "tiktok-1", "kind": "link", "title": "Ghé TikTok của trường",
     "desc": "Mở TikTok của trường, xem một video, rồi nhận thưởng khi ở trường.",
     "url": "https://www.tiktok.com/@caodangviendong",
     "spot": {"x": 0.43, "y": 0.21, "label": "Bảng tên trường"},
     "rewards": ["frame_night", "title_tiktok"]},
    {"id": "fanpage-1", "kind": "link", "title": "Ghé Fanpage của trường",
     "desc": "Mở Fanpage của trường, đọc bài mới nhất, rồi nhận thưởng khi ở trường.",
     "url": "https://www.facebook.com/Tuyensinhcaodangviendong/",
     "spot": {"x": 0.79, "y": 0.72, "label": "Đường vào trường"},
     "rewards": ["frame_gold", "title_fanpage"]},
    {"id": "qr-1", "kind": "qr", "title": "Săn mã ở băng rôn",
     "desc": "Tìm mã QR Viễn Đông Infinite gần băng rôn tuyển sinh và quét nó.",
     "hint": "Không quét được? Nhập dòng chữ in dưới mã QR.",
     "code_sha256": "c3fcda789e2527a5bd6639429e6e19d2059a4e4eb5abf51c9ceb52970ee48087",
     "spot": {"x": 0.614, "y": 0.43, "label": "Băng rôn"},
     "rewards": ["frame_red", "title_hunter"]},
    {"id": "quiz-1", "kind": "quiz", "title": "Câu đố vườn cây",
     "desc": "Trả lời đúng một câu hỏi nhỏ về Viễn Đông Infinite.",
     "question": "Hoàn thành nhiệm vụ Infinite, bạn nhận được gì?",
     "choices": ["Điểm cộng môn học", "Khung và danh hiệu", "Giảm học phí"],
     "code_sha256": "932ece8be829495902ee21ecca3d4e102407b5e8f6fa69c994014046ea315573",
     "at_school": false,
     "spot": {"x": 0.18, "y": 0.62, "label": "Vườn cây"},
     "rewards": ["frame_teal", "title_scholar"]},
    {"id": "field-1", "kind": "code", "title": "Mật mã sân bóng",
     "desc": "Mật mã được đọc ở sân bóng trong các buổi sinh hoạt và sự kiện thể thao.",
     "hint": "Mật mã gồm chữ in hoa, không dấu.",
     "code_sha256": "198172f2e4d665ed91037182b6d0b963d754cff7f4fc03ca5a4be6b5e7e1c606",
     "spot": {"x": 0.38, "y": 0.75, "label": "Sân bóng"},
     "rewards": ["frame_green", "title_striker"]}
  ]
}
''';
