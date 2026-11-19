// Pure rules for one person's parts, as the web and the server decide them:
// which section a part sits in, what comes next, what a hand-in must carry,
// and how a description and a file name read on the phone.
import 'work_api.dart' show asInt;

/// A part closes for good ("Không hoàn thành") after this many returns, or
/// this long after its deadline (CRM lib/tasks/transition.js; the web's
/// public/js/pages/myTasks.js mtSectionOf says the same).
const int workStrikes = 3;
const Duration workGrace = Duration(days: 7);

/// Where one of my parts sits, as the web's "Nhiệm vụ của tôi" sorts it:
/// `open` (can still be handed in), `wait` (handed in, with the reviewer),
/// `done`, or `closed` (Không hoàn thành: locked, cancelled or denied).
/// [dueAt] is the piece's deadline when [a] does not carry it.
String workSection(Map a, {DateTime? now, Object? dueAt}) {
  final status = '${a['status']}';
  if (a['work_process_decision'] == 'denied') return 'closed';
  if (status == 'done') return 'done';
  if (status == 'cancelled') return 'closed';
  if (workLockReason(a, now: now, dueAt: dueAt) != null) return 'closed';
  if (status == 'submitted' || status == 'in_review') return 'wait';
  return 'open';
}

/// Why a part can no longer be handed in, in the web's words; null if it can.
String? workLockReason(Map a, {DateTime? now, Object? dueAt}) {
  if (asInt(a['returned_count']) >= workStrikes) {
    return 'Đã bị trả lại $workStrikes lần — việc đã chốt "Không hoàn thành", '
        'không nộp lại được.';
  }
  final due = DateTime.tryParse('${a['due_at'] ?? dueAt ?? ''}');
  if (due != null && (now ?? DateTime.now()).isAfter(due.add(workGrace))) {
    return 'Đã quá hạn hơn 7 ngày — việc đã chốt "Không hoàn thành", '
        'không nộp lại được.';
  }
  return null;
}

/// Parts that can still be handed in: the web's "còn N việc".
List<Map<String, dynamic>> stillOpen(
  List<Map<String, dynamic>> rows, {
  DateTime? now,
}) => rows.where((a) => workSection(a, now: now) == 'open').toList();

/// What comes next among the parts that can still be handed in: the nearest
/// deadline still ahead first, then those just past their deadline (most
/// recent first, still within the grace), then those with no deadline.
List<Map<String, dynamic>> nextDue(
  List<Map<String, dynamic>> rows, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  DateTime? due(Map a) => DateTime.tryParse('${a['due_at'] ?? ''}');
  final open = stillOpen(rows, now: at);
  final ahead = open.where((a) => due(a)?.isBefore(at) == false).toList()
    ..sort((x, y) => due(x)!.compareTo(due(y)!));
  final late = open.where((a) => due(a)?.isBefore(at) == true).toList()
    ..sort((x, y) => due(y)!.compareTo(due(x)!));
  return [...ahead, ...late, ...open.where((a) => due(a) == null)];
}

/// What a hand-in must carry (CRM lib/tasks/report-policy.js): at least
/// [minWords] words, at least [minPhotos] photos on the part, at most
/// [maxPhotos] in one sending; [isReport] goes through the report form.
class ReportRule {
  final bool isReport;
  final int minWords;
  final int minPhotos;
  final int? maxPhotos;
  final int minFiles;
  const ReportRule({
    this.isReport = false,
    this.minWords = 0,
    this.minPhotos = 0,
    this.maxPhotos,
    this.minFiles = 0,
  });

  factory ReportRule.of(Map<String, dynamic> r) {
    final max = asInt(r['max_photos']);
    return ReportRule(
      isReport: r['is_report'] == true,
      minWords: asInt(r['min_words']),
      minPhotos: asInt(r['min_photos']),
      maxPhotos: max > 0 ? max : null,
      minFiles: asInt(r['min_submission_files']),
    );
  }

  /// A long text and photos: the report sheet, not the short note.
  bool get needsReportSheet => isReport || minWords > 0 || minPhotos > 0;

  /// The server's one request takes at most this many photos.
  int get photoCap => maxPhotos == null ? 8 : (maxPhotos! < 8 ? maxPhotos! : 8);
}

/// Words as the server counts them: runs of non-space.
int wordCount(String text) {
  final t = text.trim();
  return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
}

const _plain = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

/// A file name in plain ASCII: Vietnamese letters lose their marks
/// ("Ảnh 19-11.jpg" → "Anh 19-11.jpg"), anything else outside ASCII is "_".
String asciiName(String name) {
  final out = StringBuffer();
  for (final ch in name.runes.map(String.fromCharCode)) {
    final low = ch.toLowerCase();
    String? base;
    for (final e in _plain.entries) {
      if (e.value.contains(low)) base = e.key;
    }
    if (base != null) {
      out.write(ch == low ? base : base.toUpperCase());
    } else {
      out.write(ch.codeUnitAt(0) < 128 ? ch : '_');
    }
  }
  return out.toString();
}

/// A piece's description as plain text. The web's rich editor stores
/// `<!--task-rich-v1-->` + HTML (b, i, br, p, div, li, a, …) and may end with
/// `<!--task-link:…-->`; the phone shows the words, a line per block.
String plainDescription(Object? raw) {
  var s = '${raw ?? ''}';
  String? link;
  final m = RegExp(r'<!--task-link:([^>]*)-->\s*$').firstMatch(s);
  if (m != null) {
    try {
      link = Uri.decodeComponent(m.group(1)!);
    } catch (_) {}
    s = s.substring(0, m.start);
  }
  const rich = '<!--task-rich-v1-->';
  if (s.startsWith(rich)) {
    s = s
        .substring(rich.length)
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
  s = s.trim();
  if (link != null && link.isNotEmpty) s = s.isEmpty ? link : '$s\n$link';
  return s;
}
