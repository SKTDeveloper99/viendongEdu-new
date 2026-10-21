import 'package:flutter/material.dart';

/// Announcement author colours are content, independent of the app's semantic
/// UI tokens. Keep their light/dark variants and hex parsing in the theme layer.
class AnnouncementPalette {
  const AnnouncementPalette(this.brightness);

  final Brightness brightness;
  bool get _dark => brightness == Brightness.dark;

  static const _named = {
    'red': (Color(0xFFDC2626), Color(0xFFF87171)),
    'blue': (Color(0xFF2563EB), Color(0xFF60A5FA)),
    'green': (Color(0xFF16A34A), Color(0xFF4ADE80)),
    'orange': (Color(0xFFEA580C), Color(0xFFFB923C)),
    'purple': (Color(0xFF9333EA), Color(0xFFC084FC)),
    'pink': (Color(0xFFDB2777), Color(0xFFF472B6)),
    'gray': (Color(0xFF6B7280), Color(0xFF9CA3AF)),
  };

  Color get link => color('blue')!;
  Color get highlight =>
      _dark ? const Color(0x66CA8A04) : const Color(0xFFFEF08A);

  /// Unknown colour names keep their text uncoloured.
  Color? color(String name) {
    final v = name.trim().toLowerCase();
    final pair = _named[v];
    if (pair != null) return _dark ? pair.$2 : pair.$1;
    final hex = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$').firstMatch(v)?[1];
    if (hex == null) return null;
    final full = hex.length == 3
        ? hex.split('').map((c) => '$c$c').join()
        : hex;
    return Color(0xFF000000 | int.parse(full, radix: 16));
  }
}
