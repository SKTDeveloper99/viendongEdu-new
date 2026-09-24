// crm_student_api_test.dart — phân tích JSON cho lát cắt "học vụ sinh viên"
// (bot A3): hồ sơ, điểm, môn còn thiếu, lớp/lịch học, lịch thi.
//
// Fixture dựng theo ĐÚNG hình dạng response thật đã đọc từ crm-clean
// (routes/portals/student-portal.js, lib/portals-student-portal-service.js,
// repositories/portals-student-portal-repo.js, và
// docs/api/mobile-ims-replacement-S3.md cho /me/exams), với một sinh viên hư
// cấu theo quy ước THỬ NGHIỆM (CLAUDE.md): "Thử Nghiệm", MSSV TEST2600001.
//
//   flutter test test/crm_student_api_test.dart
//
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/models/crm_student_exams.dart';
import 'package:viendongedu2_flutter/models/crm_student_grades.dart';
import 'package:viendongedu2_flutter/models/crm_student_profile.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_student_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  tearDown(() => EmsApiService.client = http.Client());

  group('CrmStudentProfile.fromJson', () {
    test('đọc đủ trường từ GET /api/student/me', () {
      final profile = CrmStudentProfile.fromJson({
        'mssv': 'TEST2600001',
        'last_name': 'Thử',
        'first_name': 'Nghiệm',
        'full_name': 'Thử Nghiệm',
        'date_of_birth': '2006-05-01',
        'gender': 'F',
        'phone': '0900000000',
        'email': 'thunghiem@thunghiem.test',
        'status': 'active',
        'class_id': '42',
        'class_code': '26CDCQC',
        'khoa': '26',
        'khoa_label': 'Khóa 26',
        'program_name': 'Cao đẳng chính quy',
        'program_code': 'CDCQ',
        'nganh_name': 'Công nghệ thông tin',
        'nganh_short': 'CNTT',
        'nganh_code': 'CNTT01',
      });

      expect(profile.fullName, 'Thử Nghiệm');
      expect(profile.genderLabel, 'Nữ');
      expect(profile.khoaDisplay, 'Khóa 26');
      expect(profile.classCode, '26CDCQC');
      expect(profile.dateOfBirth, DateTime(2006, 5, 1));
    });

    test('thiếu trường không làm vỡ app', () {
      final profile = CrmStudentProfile.fromJson({'mssv': 'TEST2600001'});
      expect(profile.fullName, '');
      expect(profile.genderLabel, '–');
      expect(profile.khoaDisplay, '–');
      expect(profile.dateOfBirth, isNull);
    });
  });

  group('CrmStudentGrade / CrmStudentGradesView', () {
    test('tính đạt/rớt đúng luật server (final_score >= 5 hoặc override_pass)', () {
      final view = CrmStudentGradesView.fromJson({
        'mssv': 'TEST2600001',
        'summary': {
          'total': 2, 'scored': 2, 'passed': 1, 'failed': 1, 'average_score': 5.5,
        },
        'grades': [
          {
            'grade_id': 1, 'semester_code': '253', 'class_code': '26CDCQC',
            'midterm_score': 7, 'final_exam_score': 8, 'final_score': 7.5,
            'status': 'graded', 'override_pass': false,
            'subject_id': 10, 'subject_code': 'CS101', 'subject_name': 'Nhập môn CNTT',
            'credits': 3, 'section_id': 100, 'section_code': '253_CS101_01',
            'teacher_name': 'Nguyễn Văn Thử',
            'recorded_at': '2026-01-10T00:00:00.000Z',
          },
          {
            'grade_id': 2, 'semester_code': '253', 'class_code': '26CDCQC',
            'midterm_score': 3, 'final_exam_score': 2, 'final_score': 2.5,
            'status': 'graded', 'override_pass': false,
            'subject_id': 11, 'subject_code': 'CS102', 'subject_name': 'Toán rời rạc',
            'credits': 4, 'section_id': 101, 'section_code': '253_CS102_01',
            'teacher_name': 'Trần Thị Nghiệm',
          },
        ],
      });

      expect(view.grades, hasLength(2));
      final passed = view.grades.firstWhere((g) => g.subjectCode == 'CS101');
      final failed = view.grades.firstWhere((g) => g.subjectCode == 'CS102');
      expect(passed.isPassed, isTrue);
      expect(passed.isUngraded, isFalse);
      expect(passed.gradeLetter, 'B'); // 7.5 → B theo quy ước hiển thị
      expect(failed.isPassed, isFalse);
      expect(failed.gradeLetter, 'F');
      expect(view.summary.averageScore, 5.5);
    });

    test('final_score null → chưa có điểm, không phải 0', () {
      final g = CrmStudentGrade.fromJson({
        'subject_code': 'CS103', 'subject_name': 'Cấu trúc dữ liệu', 'credits': 3,
      });
      expect(g.isUngraded, isTrue);
      expect(g.gradeLetter, '');
      expect(g.isPassed, isFalse);
    });

    test('override_pass thắng điểm số thấp', () {
      final g = CrmStudentGrade.fromJson({
        'final_score': 3, 'override_pass': true, 'subject_code': 'CS104',
      });
      expect(g.isPassed, isTrue);
      expect(g.gradeLetter, 'A');
    });
  });

  group('CrmRemainingSubjectsView', () {
    test('đọc has_curriculum + trạng thái từng môn', () {
      final view = CrmRemainingSubjectsView.fromJson({
        'mssv': 'TEST2600001',
        'has_curriculum': true,
        'all_required_count': 3,
        'passed_count': 1,
        'subjects': [
          {'subject_code': 'CS102', 'subject_name': 'Toán rời rạc', 'credits': 4, 'completion_status': 'failed'},
          {'subject_code': 'CS105', 'subject_name': 'Mạng máy tính', 'credits': 3, 'completion_status': 'pending'},
          {'subject_code': 'CS106', 'subject_name': 'Hệ điều hành', 'credits': 3, 'completion_status': 'not_taken'},
        ],
      });

      expect(view.hasCurriculum, isTrue);
      expect(view.subjects, hasLength(3));
      expect(view.subjects[0].statusLabel, 'Không đạt');
      expect(view.subjects[1].statusLabel, 'Đang học');
      expect(view.subjects[2].statusLabel, 'Chưa học');
    });
  });

  group('CrmStudentSection / CrmScheduleItem', () {
    test('đọc /me/sections', () {
      const j = {
        'semester_code': '253', 'section_id': 100, 'section_code': '253_CS101_01',
        'subject_code': 'CS101', 'subject_name': 'Nhập môn CNTT', 'credits': 3,
        'teacher_name': 'Nguyễn Văn Thử',
        'ngay_bat_dau': '2026-01-05', 'ngay_ket_thuc': '2026-05-01', 'si_so': 40,
      };
      final s = CrmStudentSection.fromJson(j);
      expect(s.sectionCode, '253_CS101_01');
      expect(s.credits, 3);
    });

    test('occursOn khớp đúng thứ + khoảng ngày, KHÔNG giải mã weeks_pattern', () {
      final item = CrmScheduleItem.fromJson({
        'subject_code': 'CS101', 'subject_name': 'Nhập môn CNTT',
        'section_code': '253_CS101_01', 'day_code': '3', // Thứ 3
        'start_time': '07:30', 'end_time': '09:30',
        'room_name': 'A101', 'teacher_name': 'Nguyễn Văn Thử',
        'weeks_pattern': '1111111111',
        'start_date': '2026-01-05', 'end_date': '2026-05-01',
      });

      // 2026-01-06 là thứ Ba.
      expect(item.occursOn(DateTime(2026, 1, 6)), isTrue);
      // Cùng tuần nhưng khác thứ.
      expect(item.occursOn(DateTime(2026, 1, 7)), isFalse);
      // Đúng thứ nhưng ngoài khoảng học phần.
      expect(item.occursOn(DateTime(2026, 6, 2)), isFalse);
    });

    test('dayCodeForWeekday khớp bảng ref_days', () {
      expect(dayCodeForWeekday(DateTime.monday), '2');
      expect(dayCodeForWeekday(DateTime.saturday), '7');
      expect(dayCodeForWeekday(DateTime.sunday), 'CN');
    });
  });

  group('CrmStudentExam / semesterCodeLabel', () {
    test('đọc mẫu thật từ docs/api/mobile-ims-replacement-S3.md', () {
      final view = CrmStudentExamsView.fromJson({
        'semester_code': '253',
        'exams': [
          {
            'exam_id': '37820', 'exam_date': '2026-08-28T00:00:00.000Z',
            'start_time': '18:00', 'duration_minutes': '60', 'exam_type': 'Cuối kì',
            'exam_format': null, 'exam_group': '253_2LKD041_01YS03L', 'note': '  ',
            'room': null, 'class_code': '253_2LKD041_01YS03L', 'subject_code': '2LKD041',
            'subject_name': 'Huyết học -  ung bướu', 'credits': '2',
            'semester_code': '253', 'semester_name': 'Học kỳ hè, 2025 - 2026',
          },
        ],
      });

      expect(view.exams, hasLength(1));
      final e = view.exams.first;
      expect(e.room, isNull); // phòng trống là chuyện thường của IMS, không phải lỗi
      expect(e.durationMinutes, 60);
      expect(e.examDateFormatted, '28/08/2026');
    });

    test('semesterCodeLabel suy nhãn từ mã học kỳ', () {
      expect(semesterCodeLabel('261'), 'Học kỳ 1, 2026 - 2027');
      expect(semesterCodeLabel('253'), 'Học kỳ hè, 2025 - 2026');
      expect(semesterCodeLabel(''), '–');
    });
  });

  group('CrmStudentApi (mạng, qua EmsApiService.send)', () {
    setUp(() {
      AppSession.instance
        ..emsToken = 'crm-token'
        ..mssv = 'TEST2600001';
    });

    test('me() gọi GET /student/me và trả CrmStudentProfile', () async {
      Uri? calledUri;
      EmsApiService.client = MockClient((req) async {
        calledUri = req.url;
        return http.Response(
          jsonEncode({'student': {'mssv': 'TEST2600001', 'full_name': 'Thử Nghiệm'}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final profile = await CrmStudentApi.me();
      expect(calledUri!.path, '/api/student/me');
      expect(profile.fullName, 'Thử Nghiệm');
    });

    test('401 nổi lên như EmsException để nơi gọi tự đăng xuất', () async {
      EmsApiService.client = MockClient((req) async => http.Response(
            jsonEncode({'error': 'Token expired'}),
            401,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => CrmStudentApi.me(),
        throwsA(isA<EmsException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });
}
