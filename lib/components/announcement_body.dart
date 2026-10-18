import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A small text format shared with CRM's announcement preview. Never HTML.
/// Existing plain messages also gain tappable HTTP(S) links.
class AnnouncementBody extends StatefulWidget {
  final String body;
  final Future<bool> Function(Uri)? openLink;
  const AnnouncementBody({super.key, required this.body, this.openLink});

  static String plainText(String value) => value
      .replaceAll('[red]', '')
      .replaceAll('[/red]', '')
      .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1]!);

  @override
  State<AnnouncementBody> createState() => _AnnouncementBodyState();
}

class _AnnouncementBodyState extends State<AnnouncementBody> {
  final _recognizers = <TapGestureRecognizer>[];
  static final _tokens = RegExp(
    r'\[red\]([\s\S]*?)\[/red\]|\*\*([^*]+)\*\*|https?://[^\s<>]+',
  );

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

  List<InlineSpan> _spans(String text, TextStyle style, int depth) {
    if (depth > 4) return [TextSpan(text: text, style: style)];
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _tokens.allMatches(text)) {
      spans.add(
        TextSpan(text: text.substring(last, match.start), style: style),
      );
      if (match[1] != null) {
        final red = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFF87171)
            : const Color(0xFFDC2626);
        spans.addAll(_spans(match[1]!, style.copyWith(color: red), depth + 1));
      } else if (match[2] != null) {
        spans.addAll(
          _spans(
            match[2]!,
            style.copyWith(fontWeight: FontWeight.bold),
            depth + 1,
          ),
        );
      } else {
        final raw = match[0]!;
        final url = raw.replaceFirst(RegExp(r'[.,;!?)\]]+$'), '');
        final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: url,
            style: style.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF60A5FA)
                  : const Color(0xFF2563EB),
              decoration: TextDecoration.underline,
            ),
            recognizer: recognizer,
          ),
        );
        spans.add(TextSpan(text: raw.substring(url.length), style: style));
      }
      last = match.end;
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
