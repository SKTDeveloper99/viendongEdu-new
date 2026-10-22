import '../../core/network/ems_exception.dart';
import '../../utils/user_error_text.dart';

/// Show Vietnamese server guidance or a safe Vietnamese fallback.
String conversationErrorText(Object error) => userErrorText(error);

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
