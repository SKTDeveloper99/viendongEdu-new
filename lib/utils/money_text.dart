/// `1234567` → `1.234.567 đ` (Vietnamese thousands dots). Decimals from the
/// server (e.g. `1500000.0`) are rounded to whole đồng; null → [unknown].
String vndText(num? amount, {required String unknown}) {
  if (amount == null) return unknown;
  final whole = amount.round();
  final s = whole.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${whole < 0 ? '-' : ''}$buf đ';
}
