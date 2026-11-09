/// Request status on a student conversation (contract S4, T-45).
///
/// `GET /api/student/conversations` items and the single-thread response may
/// carry `support: {status, owner_name?, due_at?}`. Missing or null means an
/// ordinary chat: no strip. An unknown status reads as `received`.
library;

enum SupportStatus {
  submitted,
  received,
  inProgress,
  awaitingConfirmation,
  resolved,
}

class SupportInfo {
  final SupportStatus status;

  /// Assigned staff member; only once someone has taken the request.
  final String? ownerName;

  /// Promised reply time (UTC); only while the school still owes an answer.
  final DateTime? dueAt;

  const SupportInfo({required this.status, this.ownerName, this.dueAt});

  static SupportInfo? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final status = switch (raw['status']) {
      'submitted' => SupportStatus.submitted,
      'received' => SupportStatus.received,
      'in_progress' => SupportStatus.inProgress,
      'awaiting_confirmation' => SupportStatus.awaitingConfirmation,
      'resolved' => SupportStatus.resolved,
      _ => SupportStatus.received,
    };
    final owner = raw['owner_name'];
    final due = raw['due_at'];
    return SupportInfo(
      status: status,
      ownerName: owner is String && owner.trim().isNotEmpty
          ? owner.trim()
          : null,
      dueAt: due is String ? DateTime.tryParse(due)?.toUtc() : null,
    );
  }

  /// The due time is shown only while the school still has to answer.
  bool get showsDue =>
      dueAt != null &&
      (status == SupportStatus.submitted ||
          status == SupportStatus.received ||
          status == SupportStatus.inProgress);

  String get label => switch (status) {
    SupportStatus.submitted => 'Đã gửi',
    SupportStatus.received => 'Đã tiếp nhận',
    SupportStatus.inProgress => 'Đang xử lý',
    SupportStatus.awaitingConfirmation => 'Chờ bạn xác nhận',
    SupportStatus.resolved => 'Đã giải quyết',
  };

  /// Steps already done: 1 = sent … 4 = confirmed (resolved).
  int get stepsDone => switch (status) {
    SupportStatus.submitted => 1,
    SupportStatus.received => 2,
    SupportStatus.inProgress => 3,
    SupportStatus.awaitingConfirmation => 3,
    SupportStatus.resolved => 4,
  };
}

/// The four steps the strip draws, in order.
const supportSteps = ['Đã gửi', 'Đã tiếp nhận', 'Đang xử lý', 'Bạn xác nhận'];

/// `HH:mm dd/MM/yyyy` in Vietnam time (UTC+7), whatever the phone's zone.
String supportDueText(DateTime dueUtc) {
  final vn = dueUtc.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(vn.hour)}:${two(vn.minute)} '
      '${two(vn.day)}/${two(vn.month)}/${vn.year}';
}

/// The two replies the CRM accepts as the T-45 confirmation
/// (`lib/student-support-policy.js` parseFeedback): sent as ordinary chat
/// messages, matched case- and accent-insensitively with the request's code.
({String satisfied, String unsatisfied}) supportConfirmationReplies(
  String code,
) => (satisfied: 'ĐÃ HÀI LÒNG $code', unsatisfied: 'CHƯA GIẢI QUYẾT $code');
