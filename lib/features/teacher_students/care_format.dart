/// Formatting for the teacher student view. Shows the server's numbers as
/// they are — no arithmetic on the phone.
library;

const unknownText = 'Đang đối chiếu';

/// Midterm deadline shown with the debt reminder (same date as the student
/// app's banner in lib/components/tuition_notes.dart).
const midtermLabel = '02/11';

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
  final t = score.toStringAsFixed(2);
  return t.replaceFirst(RegExp(r'\.?0+$'), '');
}
