import 'app_session.dart';

/// Route for a push whose payload says `route: '/conversations'` (server:
/// crm-clean `lib/portals/conversation-notify.js`). Teachers only; opens that
/// thread when `conversation_id` is numeric, otherwise the inbox. Null when
/// the payload is not a conversation push or the session is not a teacher.
String? conversationPushRoute(Map<String, dynamic> data, {bool? isTeacher}) {
  if (!(isTeacher ?? AppSession.instance.isGiangVien)) return null;
  if (data['route'] != '/conversations') return null;
  final id = data['conversation_id']?.toString() ?? '';
  return RegExp(r'^\d+$').hasMatch(id)
      ? '/teacher_conversations/$id'
      : '/teacher_conversations';
}
