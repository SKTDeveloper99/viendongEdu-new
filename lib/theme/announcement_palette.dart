import 'package:flutter/material.dart';

/// Colours in server-provided announcement formatting, shared with the CRM
/// preview. Keep these separate from app UI tokens to preserve authored colours.
abstract final class AnnouncementPalette {
  static const _named = {
    'red': (Color(0xFFDC2626), Color(0xFFF87171)),
    'blue': (Color(0xFF2563EB), Color(0xFF60A5FA)),
    'green': (Color(0xFF16A34A), Color(0xFF4ADE80)),
    'orange': (Color(0xFFEA580C), Color(0xFFFB923C)),
    'purple': (Color(0xFF9333EA), Color(0xFFC084FC)),
    'pink': (Color(0xFFDB2777), Color(0xFFF472B6)),
    'gray': (Color(0xFF6B7280), Color(0xFF9CA3AF)),
  };

  /// Unknown or invalid values return null so the inherited text colour stays.
  /// Explicit hex colours are opaque and unchanged by theme brightness.
  static Color? parse(String value, Brightness brightness) {
    final v = value.trim().toLowerCase();
    final pair = _named[v];
    if (pair != null) return brightness == Brightness.dark ? pair.$2 : pair.$1;
    final hex = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$').firstMatch(v)?[1];
    if (hex == null) return null;
    final full = hex.length == 3
        ? hex.split('').map((c) => '$c$c').join()
        : hex;
    return Color(0xFF000000 | int.parse(full, radix: 16));
  }

  static Color link(Brightness brightness) => parse('blue', brightness)!;

  static Color highlight(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0x66CA8A04)
      : const Color(0xFFFEF08A);
}
