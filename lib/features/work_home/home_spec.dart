/// The home as the server sends it (`home` in `GET /auth/app/me`, server
/// `lib/app-home.js`, proposed LAW P-50): tiles, the Văn phòng and Thêm rows,
/// and a few button words. Anything this build does not know is dropped; when
/// nothing usable is left, [HomeSpec.parse] returns null and the home shows
/// its own built-in tiles, exactly as before.
library;

import 'dart:convert';

/// Where a tile or row goes: a native screen this build has ([AppOpen]) or a
/// Viva page by its relative path ([WebOpen]).
sealed class HomeOpen {
  const HomeOpen();

  static HomeOpen? parse(Object? raw, {required bool teacher}) {
    if (raw is! String) return null;
    if (raw.startsWith('app:')) {
      final name = raw.substring(4);
      if (!AppOpen.names.contains(name)) return null;
      if (!teacher && AppOpen.teacherOnly.contains(name)) return null;
      return AppOpen(name);
    }
    if (raw.startsWith('web:')) {
      final path = raw.substring(4);
      return webPathOk(path) ? WebOpen(path) : null;
    }
    return null;
  }

  /// Relative, one leading slash, one to four plain segments: no scheme, no
  /// `//`, no `..`, no backslash, no control characters, no query or
  /// fragment. Same rule as the server (`lib/app-home.js` webPathOk). The
  /// server still decides which of these pages exist: it refuses a pass for
  /// any path it does not list, and the view loads only our own host.
  static bool webPathOk(String p) =>
      p.length <= 120 && RegExp(r'^(?:/[A-Za-z0-9_-]{1,40}){1,4}$').hasMatch(p);
}

class AppOpen extends HomeOpen {
  final String name;
  const AppOpen(this.name);

  /// Native screens this build can open (server `APP_OPENS`).
  static const names = {
    'viec',
    'nhom',
    'lich',
    'lop',
    'van_phong',
    'them',
    'sent_notices',
    'give_work',
    'notice',
    'attendance',
    'gv_schedule',
    'lich_thi',
    'danh_sach_thi',
    'my_classes',
    'my_students',
    'bell',
    'messages',
  };

  /// Screens that need the teacher's own schedule or classes.
  static const teacherOnly = {
    'lop',
    'attendance',
    'gv_schedule',
    'lich_thi',
    'danh_sach_thi',
    'my_classes',
    'my_students',
    'messages',
  };

  @override
  bool operator ==(Object other) => other is AppOpen && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

class WebOpen extends HomeOpen {
  final String path;
  const WebOpen(this.path);

  @override
  bool operator ==(Object other) => other is WebOpen && other.path == path;
  @override
  int get hashCode => path.hashCode;
}

/// One tile (with [id]) or one page row (with [sub]).
class HomeItem {
  final String? id;
  final String label;
  final String? sub;
  final String? icon;
  final String? badge;
  final HomeOpen open;
  const HomeItem({
    this.id,
    required this.label,
    this.sub,
    this.icon,
    this.badge,
    required this.open,
  });
}

class HomePage {
  final String title;
  final List<HomeItem> rows;
  const HomePage(this.title, this.rows);
}

class HomeSpec {
  static const maxTiles = 12;
  static const maxRows = 12;

  final List<HomeItem> tiles;
  final Map<String, HomePage> pages;
  final Map<String, String> words;

  /// The server's own answer, kept so the phone can show it at the next
  /// cold start before `/app/me` answers ([HomePrefs.homeSpec]).
  final Map<String, dynamic> raw;

  const HomeSpec._(this.tiles, this.pages, this.words, this.raw);

  String word(String key, String fallback) => words[key] ?? fallback;

  static String? _text(Object? v, int max) {
    if (v is! String) return null;
    final s = v.trim();
    if (s.isEmpty || s.length > max) return null;
    if (RegExp(r'[\u0000-\u001f\u007f]').hasMatch(s)) return null;
    return s;
  }

  static HomeItem? _item(
    Object? raw, {
    required bool tile,
    required bool teacher,
  }) {
    if (raw is! Map) return null;
    final label = _text(raw['label'], 24);
    final open = HomeOpen.parse(raw['open'], teacher: teacher);
    if (label == null || open == null) return null;
    final id = raw['id'];
    if (tile && (id is! String || !RegExp(r'^[a-z_]{1,24}$').hasMatch(id))) {
      return null;
    }
    final icon = raw['icon'];
    final badge = raw['badge'];
    return HomeItem(
      id: tile ? id as String : null,
      label: label,
      sub: tile ? null : _text(raw['sub'], 60),
      icon: icon is String ? icon : null,
      badge: tile && badge is String ? badge : null,
      open: open,
    );
  }

  static List<HomeItem> _list(
    Object? raw, {
    required bool tile,
    required bool teacher,
    required int max,
  }) {
    final out = <HomeItem>[];
    final seen = <String>{};
    for (final r in raw is List ? raw : const []) {
      final it = _item(r, tile: tile, teacher: teacher);
      if (it == null) continue;
      if (tile && !seen.add(it.id!)) continue;
      out.add(it);
      if (out.length >= max) break;
    }
    return out;
  }

  /// Null (= the built-in home) unless the server sent version 1 with at
  /// least one tile this build can show. [teacher]: screens that need the
  /// teacher's schedule are dropped for anyone else.
  static HomeSpec? parse(Object? raw, {required bool teacher}) {
    if (raw is! Map || raw['v'] != 1) return null;
    final m = raw.cast<String, dynamic>();
    final tiles = _list(
      m['tiles'],
      tile: true,
      teacher: teacher,
      max: maxTiles,
    );
    if (tiles.isEmpty) return null;
    final pages = <String, HomePage>{};
    final rawPages = m['pages'];
    if (rawPages is Map) {
      for (final id in const ['van_phong', 'them']) {
        final p = rawPages[id];
        if (p is! Map) continue;
        final title = _text(p['title'], 24);
        if (title == null) continue;
        pages[id] = HomePage(
          title,
          _list(p['rows'], tile: false, teacher: teacher, max: maxRows),
        );
      }
    }
    final words = <String, String>{};
    final rawWords = m['words'];
    if (rawWords is Map) {
      for (final e in rawWords.entries) {
        final s = _text(e.value, 24);
        if (e.key is String && s != null) words[e.key as String] = s;
      }
    }
    return HomeSpec._(tiles, pages, words, m);
  }

  /// The cached form (`{"user": id, "home": raw}`) back to a spec, only for
  /// the same account.
  static HomeSpec? fromCache(
    String? stored, {
    required String? userId,
    required bool teacher,
  }) {
    if (stored == null || userId == null || userId.isEmpty) return null;
    try {
      final m = jsonDecode(stored);
      if (m is! Map || m['user'] != userId) return null;
      return parse(m['home'], teacher: teacher);
    } catch (_) {
      return null;
    }
  }

  String toCache(String userId) => jsonEncode({'user': userId, 'home': raw});
}
