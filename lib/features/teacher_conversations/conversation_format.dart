import '../../core/network/ems_exception.dart';

/// The text to show for a failed call. Server refusals (403/404/422...) carry
/// their own message and are shown as-is; only real network failures (no
/// status code) get the network wording, which [EmsException] already holds.
String conversationErrorText(Object error) {
  if (error is EmsException) return error.message;
  return 'Đã xảy ra lỗi. Vui lòng thử lại.';
}

bool isAuthError(Object error) =>
    error is EmsException && error.statusCode == 401;

String _two(int n) => n.toString().padLeft(2, '0');

/// "14:05" for today, "30/09" for this year, "30/09/2025" otherwise.
String conversationTime(DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final n = now ?? DateTime.now();
  if (t.year == n.year && t.month == n.month && t.day == n.day) {
    return '${_two(t.hour)}:${_two(t.minute)}';
  }
  if (t.year == n.year) return '${_two(t.day)}/${_two(t.month)}';
  return '${_two(t.day)}/${_two(t.month)}/${t.year}';
}
