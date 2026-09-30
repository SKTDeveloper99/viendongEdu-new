import '../../services/ems_api_service.dart';

abstract final class AttendanceApi {
  // ── Điểm danh EMS ──────────────────────────────────────────────────────────
  //
  // EMS là nguồn dữ liệu điểm danh chính thức. Không đọc/ghi IMS khi vận hành.
  //
  // Khác biệt cốt lõi so với IMS, và cũng là lý do màn hình này tồn tại:
  //   - chưa điểm danh KHÔNG phải là vắng (status = null, không mặc định absent);
  //   - lưu lại nhiều lần cũng chỉ ra một dòng (UNIQUE session_key + mssv);
  //   - trường hợp lạ vẫn được ghi và gắn cờ để xem lại, không bị chặn.

  static Future<List<EmsSession>> mySessions({String? date}) async {
    final q = (date == null || date.isEmpty) ? '' : '?date=$date';
    final body = await EmsApiService.sendMap('GET', '/attendance/my-sessions$q');
    // `from_schedule: false` = máy chủ KHÔNG có buổi nào hôm nay và đang trả
    // về danh sách mọi lớp của giáo viên (không giờ, không phòng) thay thế.
    // Đó không phải buổi học hôm nay: lưu điểm danh vào đó bị từ chối (422)
    // và ngày 14/09 nó đã sinh ra 21 dấu điểm danh cho lớp chưa khai giảng.
    // Hiện danh sách trống — hôm nay không có buổi học là hôm nay không có.
    if (body['from_schedule'] == false) return <EmsSession>[];
    final list = body['sessions'];
    if (list is! List) return <EmsSession>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(EmsSession.fromJson)
        .toList();
  }

  static Future<EmsRoster> roster(EmsSession s) async {
    final q =
        '?section_id=${Uri.encodeQueryComponent(s.sectionId)}'
        '&date=${Uri.encodeQueryComponent(s.sessionDate)}'
        '&start_time=${Uri.encodeQueryComponent(s.startTime ?? '')}'
        '&end_time=${Uri.encodeQueryComponent(s.endTime ?? '')}';
    final body = await EmsApiService.sendMap('GET', '/attendance/roster$q');
    return EmsRoster.fromJson(body);
  }

  /// Trạng thái EMS của MỘT buổi, theo `session_key` (`<lmhid>:<HH-MM>:<yyyy-MM-dd>`).
  /// Dùng khi chỉ có dữ liệu lịch IMS trong tay (Quản lý lớp): danh sách lớp
  /// vẫn là của IMS, nhưng ai có mặt / vắng là EMS nói — không phải IMS.
  /// Trả về map mssv → status ('present' | 'late' | 'absent' | 'excused').
  static Future<Map<String, String>> sessionMarks(String sessionKey) async {
    final body = await EmsApiService.sendMap(
      'GET',
      '/attendance/session-marks?session_key=${Uri.encodeQueryComponent(sessionKey)}',
    );
    final list = body['marks'];
    final out = <String, String>{};
    if (list is List) {
      for (final m in list.whereType<Map<String, dynamic>>()) {
        final mssv = m['mssv']?.toString();
        final st = m['status']?.toString();
        if (mssv != null && st != null) out[mssv] = st;
      }
    }
    return out;
  }

  /// `session_key` đúng như máy chủ tạo (repositories/attendance-write-repo.js):
  /// `<ims lopmonhoc id>:<HH-MM>:<yyyy-MM-dd>`.
  static String sessionKeyFor({
    required String lmhId,
    required String date,
    required String startTime,
  }) {
    final t = startTime.trim();
    final hhmm = t.length >= 5
        ? t.substring(0, 5).replaceAll(':', '-')
        : t.replaceAll(':', '-');
    return '$lmhId:$hhmm:$date';
  }

  /// Lưu điểm danh. Những trường hợp lạ vẫn được lưu và gắn cờ để xem lại.
  static Future<EmsSaveResult> saveMarks(
    EmsSession s,
    List<EmsMark> marks, {
    List<String> remove = const [],
  }) async {
    final body = await EmsApiService.sendMap(
      'POST',
      '/attendance/marks',
      body: {
        'section_id': s.sectionId,
        'date': s.sessionDate,
        'start_time': ?s.startTime,
        'end_time': ?s.endTime,
        'marks': marks.map((m) => m.toJson()).toList(),
        // Bỏ điểm danh những học viên giáo viên đã bỏ chọn.
        if (remove.isNotEmpty) 'remove': remove,
      },
    );
    return EmsSaveResult.fromJson(body);
  }

  /// Học viên xem điểm danh EMS của chính mình.
  static Future<List<EmsStudentMark>> myAttendance({int limit = 100}) async {
    final body = await EmsApiService.sendMap('GET', '/student/me/attendance-ems?limit=$limit');
    final list = body['marks'] ?? body['history'] ?? body['items'];
    if (list is! List) return <EmsStudentMark>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(EmsStudentMark.fromJson)
        .toList();
  }
}
