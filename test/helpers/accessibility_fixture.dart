// Fictional API responses; MockClient intercepts every request before transport.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'teacher_care_fixture.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
http.Response _ok(Object body) =>
    http.Response(jsonEncode(body), 200, headers: _json);
const _conversation = {
  'id': 'TEST26',
  'subject': 'Câu hỏi thử nghiệm',
  'status': 'open',
  'student_name': 'THUNGHIEM',
  'student_mssv': 'TEST260001',
  'last_message': {'body': 'Nội dung thử nghiệm', 'sender_type': 'student'},
};
Map<String, dynamic> _todayClass(String name, String start, String end) => {
  'subject_code': 'TN101',
  'subject_name': name,
  'semester_code': '262',
  'section_code': '06CDTHUNGHIEM-$start',
  'day_code': dayCodeForWeekday(DateTime.now().weekday),
  'start_time': start,
  'end_time': end,
  'room_name': 'P.101',
  'teacher_name': 'GV Thử Nghiệm',
};

Map<String, dynamic> _grade(
  int id,
  String sem,
  String code,
  String name,
  int credits,
  double? score,
) => {
  'grade_id': id,
  'semester_code': sem,
  'class_code': '06CD15THUNGHIEM',
  'final_score': score,
  'recorded_at': '2026-0${id + 1}-01T00:00:00.000Z',
  'subject_code': code,
  'subject_name': name,
  'credits': credits,
  'teacher_name': 'GV Thử Nghiệm',
};

Map<String, dynamic> _boardItem(
  String id,
  String title,
  String category,
  bool mustRead,
  String? readAt,
) => {
  'id': id,
  'title': title,
  'body': 'Nội dung thử nghiệm cho thông báo này.',
  'category': category,
  'must_read': false,
  'is_correction': false,
  'published_at': '2026-09-01T13:05:35.805Z',
  'read_at': readAt,
  'acknowledged_at': null,
};

Map<String, dynamic> _cmClass(
  String id,
  String code,
  String subj,
  String name,
  int credits,
  int enrolled,
  String sem,
) => {
  'section_id': id,
  'section_code': code,
  'semester_code': sem,
  'room': 'P.101',
  'ngay_bat_dau': '2026-02-16T00:00:00.000Z',
  'ngay_ket_thuc': '2026-06-20T00:00:00.000Z',
  'ngay_thi': '2026-06-28T00:00:00.000Z',
  'subject_code': subj,
  'subject_name': name,
  'credits': credits,
  'enrolled_students': enrolled,
};

Map<String, dynamic> _slot(String name, String start, String end) => {
  'lmhid': '9001',
  'lmhma': '06CDTHUNGHIEM-$start',
  'mhten': name,
  'phongten': 'P.101',
  'thoigianbd': start,
  'thoigiankt': '2026-09-30T$end:00',
};

const _rosterKey = 'TEST26';

http.Response accessibilityResponse(http.Request req) {
  final p = req.url.path;
  if (p.endsWith('/student/me/schedule')) {
    return _ok({
      'schedule': [
        _todayClass('Môn thử nghiệm sáng', '07:30', '09:30'),
        _todayClass('Môn thử nghiệm tối', '18:30', '20:30'),
      ],
    });
  }
  if (p.endsWith('/student/me/grades')) {
    return _ok({
      'mssv': 'TEST260001',
      'summary': {
        'total': 4,
        'scored': 3,
        'passed': 2,
        'failed': 1,
        'average_score': 6.0,
      },
      'grades': [
        _grade(1, '251', 'TN101', 'Môn thử nghiệm A', 3, 9.0),
        _grade(2, '251', 'TN102', 'Môn thử nghiệm B', 2, 3.0),
        _grade(3, '252', 'TN102', 'Môn thử nghiệm B', 2, 6.0),
        _grade(4, '252', 'TN103', 'Môn thử nghiệm D', 1, null),
      ],
    });
  }
  if (p.endsWith('/student/me/graduation-summary')) {
    return _ok({
      'academic': {
        'total': 4,
        'scored': 3,
        'passed': 2,
        'failed': 1,
        'average_score': 6.0,
        'has_curriculum': true,
        'required_subjects': 5,
        'required_passed': 2,
        'remaining_subjects_count': 3,
        'academically_clear': false,
      },
      'remaining_subjects': [
        {
          'subject_code': 'TN201',
          'subject_name': 'Môn thử nghiệm E',
          'credits': 2,
          'completion_status': 'pending',
        },
        {
          'subject_code': 'TN202',
          'subject_name': 'Môn thử nghiệm F',
          'credits': 3,
          'completion_status': 'failed',
        },
      ],
    });
  }
  if (p.endsWith('/teacher/me') || p.endsWith('/student/me')) {
    return _ok({
      'student': {
        'mssv': 'TEST260001',
        'full_name': 'THUNGHIEM',
        'class_code': 'TEST26',
      },
      'teacher': {'teacher_code': 'TEST26GV', 'name': 'THUNGHIEM'},
    });
  }
  if (p.endsWith('/board/unread-count')) {
    return _ok({'unread': 2, 'must_read_pending': 1});
  }
  if (p.endsWith('/v1/student/board')) {
    return _ok({
      'items': [
        _boardItem('b1', 'Thông báo thử nghiệm A', 'general', false, null),
        _boardItem('b2', 'KHẨN: kiểm thử bảng tin', 'urgent', true, null),
        _boardItem(
          'b3',
          'Thông báo đã đọc C',
          'general',
          false,
          '2026-08-02T00:00:00.000Z',
        ),
      ],
    });
  }
  if (p.endsWith('/teacher/me/overview')) {
    return _ok({
      'current_semester': '261',
      'teacher': {
        'teacher_id': 'T-TEST-1',
        'teacher_code': 'TESTGV01',
        'name': 'Giảng Viên Thử Nghiệm',
        'type': 'gvch',
      },
      'today_sessions': [
        _slot('Môn thử nghiệm sáng', '07:30', '09:30'),
        _slot('Môn thử nghiệm tối', '18:30', '20:30'),
      ],
    });
  }
  if (p.endsWith('/teacher/notifications/unread-count')) {
    return _ok({'count': 3});
  }
  if (p.endsWith('/teacher/me/semesters')) {
    return _ok([
      {'id': 252, 'ma': '252', 'ten': 'Học kỳ 2, 2025 - 2026'},
      {'id': 261, 'ma': '261', 'ten': 'Học kỳ 1, 2026 - 2027'},
    ]);
  }
  if (p.endsWith('/teacher/me/schedule/semester')) {
    return _ok({
      'data': [
        {
          ..._slot('Môn thử nghiệm', '07:30', '09:30'),
          'ngayten': 'Thứ 2',
          'ngayma': '2',
          'sotinchi': 3,
        },
      ],
    });
  }
  if (p.endsWith('/teacher/me/classes')) {
    return _ok({
      'classes': [
        _cmClass('sec-a', 'TN261A', 'TN101', 'Môn thử nghiệm A', 3, 3, '261'),
        _cmClass('sec-b', 'TN261B', 'TN102', 'Môn thử nghiệm B', 2, 2, '261'),
      ],
    });
  }
  if (p.contains('/teacher/me/classes/') && p.endsWith('/students')) {
    return _ok({
      'students': [
        {
          'enrollment_id': 'TEST26',
          'mssv': 'TEST260001',
          'full_name': 'Sinh viên thử nghiệm',
          'class_code': 'TEST26',
        },
      ],
    });
  }
  if (p.contains('/teacher/me/classes/') && p.endsWith('/attendance')) {
    return _ok({
      'attendance': [
        {
          'session_id': 'TEST26',
          'date': '2026-10-22',
          'start_time': '07:30',
          'end_time': '09:30',
          'mssv': 'TEST260001',
          'full_name': 'Sinh viên thử nghiệm',
          'status': 'present',
        },
      ],
    });
  }
  if (p.endsWith('/student/me/attendance-ems')) {
    return _ok({
      'marks': [
        for (final status in ['present', 'absent', 'late', 'excused'])
          {
            'session_key': 'TEST26-$status',
            'section_code': 'TEST26',
            'subject_name': 'Môn thử nghiệm',
            'session_date': '2026-10-22',
            'start_time': '07:30',
            'end_time': '09:30',
            'status': status,
          },
      ],
    });
  }
  if (p.endsWith('/student-cases/my-open')) {
    return _ok({
      'cases': [
        {
          'id': 'TEST26',
          'student_mssv': 'TEST260001',
          'student_name': 'Sinh viên thử nghiệm',
          'title': 'Cần phản hồi thử nghiệm',
          'description': 'Nội dung thử nghiệm',
          'priority': 'urgent',
        },
      ],
    });
  }
  if (p.endsWith('/attendance/my-sessions')) {
    return _ok({
      'sessions': [
        {
          'section_id': '11111111-1111-1111-1111-111111111111',
          'section_code': 'LOP-THU',
          'subject_name': 'Môn thử nghiệm',
          'session_date': '2026-09-08',
          'start_time': '18:00',
          'end_time': '20:30',
          'roster_size': 5,
          'marked_count': 4,
          'session_key': _rosterKey,
        },
      ],
    });
  }
  if (p.endsWith('/attendance/roster')) {
    Map<String, dynamic> s(String mssv, String name, String? st) => {
      'mssv': mssv,
      'full_name': name,
      'status': st,
    };
    return _ok({
      'session_key': _rosterKey,
      'students': [
        s('TEST260001', 'An Thử Nghiệm', 'present'),
        s('TEST260002', 'Bình Thử Nghiệm', 'late'),
        s('TEST260003', 'Chi Thử Nghiệm', 'absent'),
        s('TEST260004', 'Dũng Thử Nghiệm', 'present'),
        s('TEST260005', 'Em Thử Nghiệm', null),
      ],
    });
  }
  if (p.endsWith('/teacher/me/schedule')) {
    return _ok({
      'data': [_slot('Môn thử nghiệm', '07:30', '09:30')],
    });
  }
  if (p.endsWith('/student/me/sections')) {
    return _ok({
      'sections': [
        {
          'section_id': 1,
          'section_code': 'TEST26',
          'subject_name': 'Môn thử nghiệm',
          'subject_code': 'TEST26',
          'credits': 3,
          'semester_code': '261',
          'teacher_name': 'THUNGHIEM',
        },
      ],
    });
  }
  if (p.endsWith('/exams')) {
    return _ok({
      'exams': [
        {
          'exam_id': 'TEST26',
          'subject_name': 'Môn thử nghiệm',
          'subject_code': 'TEST26',
          'exam_date': '2026-11-02',
          'start_time': '07:30',
          'duration_minutes': 90,
          'exam_type': 'Cuối kỳ',
          'semester_code': '261',
          'room': 'TEST26',
        },
      ],
    });
  }
  if (p.endsWith('/tuition')) {
    return _ok({
      'summary': {
        'money_known': true,
        'owedTotal': 1000000,
        'paid': 500000,
        'balance': 500000,
        'payment_status': 'Còn nợ',
        'owes': true,
      },
      'payments': [
        {
          'phieu_thu_id': 'TEST26',
          'so_tien': 500000,
          'ngay_nop': '2026-10-01',
          'ghi_chu': 'Thu thử nghiệm',
          'semester_code': '261',
        },
      ],
    });
  }
  if (p.endsWith('/cong-no')) {
    return _ok({
      'computable': true,
      'phai_nop': 1000000,
      'da_nop': 500000,
      'cong_no': 500000,
    });
  }
  if (p.endsWith('/fees')) {
    return _ok({
      'totals': {'le_phi_khac': 100000},
      'items': [
        {
          'phieu_thu_id': 'TEST26',
          'so_tien': 100000,
          'ngay_nop': '2026-10-01',
          'loai_phieu_thu': 'Lệ phí thử nghiệm',
          'bucket': 'le_phi_khac',
        },
      ],
    });
  }
  if (p.endsWith('/capbu')) {
    return _ok({
      'count': 1,
      'items': [
        {
          'id': 'TEST26',
          'ma': 'TEST26',
          'ten': 'Cấp bù thử nghiệm',
          'total': 1000000,
          'ngay_cap': '2026-10-01',
          'hocky_ten': 'Học kỳ thử nghiệm',
        },
      ],
    });
  }
  if (p.endsWith('/registration/periods')) {
    return _ok({
      'periods': [
        {
          'period_id': 'TEST26',
          'period_name': 'Học kỳ thử nghiệm 2026',
          'semester_code': '261',
          'start_at': '2026-01-01',
          'end_at': '2030-01-01',
          'is_open': true,
        },
      ],
    });
  }
  if (p.endsWith('/registration/offerings')) {
    return _ok({
      'curriculum_resolved': true,
      'offerings': [
        {
          'offering_id': 'TEST26',
          'class_code': 'TEST26',
          'subject_name': 'Môn thử nghiệm',
          'subject_code': 'TEST26',
          'credits': 3,
          'max_size': 50,
          'registered_count': 10,
          'in_my_curriculum': true,
        },
      ],
    });
  }
  if (p.endsWith('/student-care')) {
    return _ok({
      'students': [careStudentJson()],
      'total': 1,
      'limit': 100,
      'page': 1,
    });
  }
  if (p.contains('/student-care/student/')) {
    return _ok({'student': careStudentJson()});
  }
  if (p.endsWith('/conversations/targets')) {
    return _ok({
      'targets': [
        {
          'type': 'teacher',
          'teacher_id': 'TEST26GV',
          'name': 'THUNGHIEM',
          'label': 'Giảng viên thử nghiệm',
        },
      ],
    });
  }
  if (p.endsWith('/conversations/TEST26')) {
    return _ok({
      'conversation': _conversation,
      'messages': [
        {
          'id': 'TEST26',
          'body': 'Nội dung thử nghiệm',
          'sender_type': 'student',
        },
      ],
    });
  }
  if (p.endsWith('/conversations')) {
    return _ok({
      'conversations': [_conversation],
    });
  }
  if (p.endsWith('/notifications')) {
    return _ok({
      'data': [
        {
          'id': 'TEST26',
          'title': 'Thông báo thử nghiệm',
          'body': 'Nội dung thử nghiệm',
          'status': 'unread',
        },
      ],
    });
  }
  return http.Response('{}', 200, headers: _json);
}
