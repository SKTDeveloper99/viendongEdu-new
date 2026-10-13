/// Formatting for the teacher student view. Shows the server's numbers as
/// they are — no arithmetic on the phone.
library;

const unknownText = 'Đang đối chiếu';

/// Midterm deadline shown with the debt reminder (same date as the student
/// app's banner in lib/components/tuition_notes.dart).
const midtermLabel = '02/11';

String formatCareTime(DateTime time) {
  final vn = time.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(vn.hour)}:${two(vn.minute)} ${two(vn.day)}/${two(vn.month)}';
}

String formatVnd(num amount) {
  final s = amount.abs().round().toString();
  final buf = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '$buf đ';
}

/// 7.50 → "7.5", 8 → "8"; null → "Chưa có điểm".
String formatScore(num? score) {
  if (score == null) return 'Chưa có điểm';
  final t = score.toString();
  return t.endsWith('.0') ? t.substring(0, t.length - 2) : t;
}
