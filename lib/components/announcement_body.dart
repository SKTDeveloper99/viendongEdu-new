import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/announcement_palette.dart';

/// A small text format shared with CRM's announcement preview. Never HTML.
/// Existing plain messages also gain tappable HTTP(S) links. Same grammar as
/// crm-clean public/js/pages/studentAnnouncements.js (saFormattedBody).
class AnnouncementBody extends StatefulWidget {
  final String body;
  final Future<bool> Function(Uri)? openLink;
  const AnnouncementBody({super.key, required this.body, this.openLink});

  static final tokens = RegExp(
    r'\[(red|blue|green|orange|purple|pink|gray)\]([\s\S]*?)\[/\1\]'
    r'|\[color=([^\]\n]+)\]([\s\S]*?)\[/color\]'
    r'|\[([^\]\n]+)\]\((https?://[^\s()<>]+)\)'
    r'|\*\*(?=\S)([\s\S]*?\S)\*\*'
    r'|__(?=\S)([\s\S]*?\S)__'
    r'|~~(?=\S)([\s\S]*?\S)~~'
    r'|==(?=\S)([\s\S]*?\S)=='
    r'|\*(?=[^\s*])([^*\n]*?[^\s*])\*'
    r'|https?://[^\s<>]+',
  );

  static String plainText(String value, [int depth = 0]) {
    if (depth > 4) return value;
    return value.replaceAllMapped(tokens, (m) {
      for (final g in [2, 4, 5, 7, 8, 9, 10, 11]) {
        if (m[g] != null) return plainText(m[g]!, depth + 1);
      }
      return m[0]!;
    });
  }

  @override
  State<AnnouncementBody> createState() => _AnnouncementBodyState();
}

class _AnnouncementBodyState extends State<AnnouncementBody> {
  final _recognizers = <TapGestureRecognizer>[];
  AnnouncementPalette get _palette =>
      AnnouncementPalette(Theme.of(context).brightness);

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  Future<void> _open(String value) async {
    bool opened = false;
    try {
      final uri = Uri.parse(value);
      if ((uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty) {
        opened =
            await (widget.openLink?.call(uri) ??
                launchUrl(uri, mode: LaunchMode.externalApplication));
      }
    } catch (_) {
      // Keep the readable/copyable URL when the external app cannot open it.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không mở được liên kết. Vui lòng sao chép để mở trong trình duyệt.',
          ),
        ),
      );
    }
  }

  /// Labels are flattened to plain text: recognizers fire only on leaf spans.
  InlineSpan _link(String url, String label, TextStyle style) {
    final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
    _recognizers.add(recognizer);
    return TextSpan(
      text: label,
      recognizer: recognizer,
      style: style.copyWith(
        color: _palette.link,
        decoration: TextDecoration.underline,
      ),
    );
  }

  List<InlineSpan> _spans(String text, TextStyle style, int depth) {
    if (depth > 4) return [TextSpan(text: text, style: style)];
    List<InlineSpan> inner(String v, TextStyle s) => _spans(v, s, depth + 1);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in AnnouncementBody.tokens.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: style));
      if (m[1] != null || m[3] != null) {
        final color = _palette.color(m[1] ?? m[3]!);
        spans.addAll(
          inner(
            m[2] ?? m[4]!,
            color == null ? style : style.copyWith(color: color),
          ),
        );
      } else if (m[5] != null) {
        spans.add(_link(m[6]!, AnnouncementBody.plainText(m[5]!), style));
      } else if (m[7] != null) {
        spans.addAll(inner(m[7]!, style.copyWith(fontWeight: FontWeight.bold)));
      } else if (m[8] != null) {
        spans.addAll(
          inner(m[8]!, style.copyWith(decoration: TextDecoration.underline)),
        );
      } else if (m[9] != null) {
        spans.addAll(
          inner(m[9]!, style.copyWith(decoration: TextDecoration.lineThrough)),
        );
      } else if (m[10] != null) {
        spans.addAll(
          inner(m[10]!, style.copyWith(backgroundColor: _palette.highlight)),
        );
      } else if (m[11] != null) {
        spans.addAll(
          inner(m[11]!, style.copyWith(fontStyle: FontStyle.italic)),
        );
      } else {
        final raw = m[0]!;
        final url = raw.replaceFirst(RegExp(r'[.,;!?)\]]+$'), '');
        spans.add(_link(url, url, style));
        spans.add(TextSpan(text: raw.substring(url.length), style: style));
      }
      last = m.end;
    }
    spans.add(TextSpan(text: text.substring(last), style: style));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    const style = TextStyle(fontSize: 15, height: 1.65);
    return SelectableText.rich(
      TextSpan(children: _spans(widget.body, style, 0)),
    );
  }
}
