import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/services/crm_teacher_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

/// Kiểm tra phân giải JSON cho `CrmTeacherApi` — dữ liệu mẫu bám sát hình dạng
/// thật của server (`routes/portals/teacher-portal.js` +
/// `repositories/portals-teacher-portal-repo.js`, crm-clean repo), chỉ đổi
/// tên/mã sang dữ liệu hư cấu (THUNGHIEM/9990001) theo quy định test data.
void main() {
  tearDown(() => EmsApiService.client = http.Client());

  MockClient jsonMock(Map<String, dynamic> Function(Uri url) respond) {
    return MockClient((request) async {
      final body = respond(request.url);
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  group('CrmTeacherApi.me', () {
    test('parses GET /api/teacher/me', () async {
      EmsApiService.client = jsonMock(
        (_) => {
          'teacher': {
            'teacher_id': 'aaaaaaaa-1111-2222-3333-444444444444',
            'teacher_code': '9990001',
            'name': 'Thử Nghiệm',
            'email': 'thunghiem@thunghiem.test',
            'phone': '0900000000',
            'type': 'gvch',
            'is_active': true,
            'ims_id': '834',
          },
        },
      );

      final profile = await CrmTeacherApi.me();
      expect(profile.teacherId, 'aaaaaaaa-1111-2222-3333-444444444444');
      expect(profile.teacherCode, '9990001');
      expect(profile.name, 'Thử Nghiệm');
      expect(profile.isCoHuu, isTrue);
      expect(profile.isActive, isTrue);
    });
  });

  group('CrmTeacherApi.semesters', () {
    test('parses bare array from GET /me/semesters', () async {
      // /me/semesters returns a bare JSON array, not a map — jsonMock()
      // assumes an object, so this test builds its own MockClient.
      EmsApiService.client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 261,
              'ma': '261',
              'ten': 'Học kỳ 1, 2026 - 2027',
              'ngaybatdau': '2026-08-10',
              'ngayketthuc': '2026-12-20',
            },
            {
              'id': 252,
              'ma': '252',
              'ten': 'Học kỳ 2, 2025 - 2026',
              'ngaybatdau': '2026-01-05',
              'ngayketthuc': '2026-06-01',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final sems = await CrmTeacherApi.semesters();
      expect(sems, hasLength(2));
      expect(sems.first.id, 261);
      expect(sems.first.ma, '261');
      expect(sems.first.ten, 'Học kỳ 1, 2026 - 2027');
    });
  });

  group('CrmTeacherApi.scheduleForDate / scheduleForSemester', () {
    test('parses { data: [...] } for a specific date', () async {
      EmsApiService.client = jsonMock(
        (_) => {
          'data': [
            {
              'lmhid': '43461',
              'lmhma': '261_THUNGHIEM01_06CD15THUNGHIEM',
              'mhten': 'Môn thử nghiệm',
              'sotinchi': 3,
              'phongten': 'P.101',
              'thoigianbd': '18:00',
              'thoigiankt': '2026-09-24T20:30:00.000Z',
              'tietbd': 13,
              'ngayma': '4',
              'ngayten': 'Thứ 4',
              'ngay': '2026-09-24',
              'baonghiyn': false,
            },
          ],
        },
      );

      final slots = await CrmTeacherApi.scheduleForDate('2026-09-24');
      expect(slots, hasLength(1));
      final s = slots.single;
      expect(s.lmhId, '43461');
      expect(s.lmhMa, '261_THUNGHIEM01_06CD15THUNGHIEM');
      expect(s.mhTen, 'Môn thử nghiệm');
      expect(s.soTinChi, 3);
      expect(s.thoiGianBd, '18:00');
      expect(s.baoNghiYn, isFalse);

      // toJson() keeps the old field names widgets already read.
      final json = s.toJson();
      expect(json['lmhma'], s.lmhMa);
      expect(json['mhten'], s.mhTen);
      expect(json['thoigianbd'], s.thoiGianBd);
    });

    test('parses semester slots without a specific date', () async {
      EmsApiService.client = jsonMock(
        (_) => {
          'data': [
            {
              'lmhid': '43461',
              'lmhma': '261_THUNGHIEM01_06CD15THUNGHIEM',
              'mhten': 'Môn thử nghiệm',
              'sotinchi': 3,
              'phongten': 'P.101',
              'tietbd': 13,
              'tgbatdau': '18:00',
              'tgketthuc': '20:30',
              'ngayma': '4',
              'ngayten': 'Thứ 4',
              'baonghiyn': false,
            },
          ],
        },
      );

      final slots = await CrmTeacherApi.scheduleForSemester('261');
      expect(slots.single.tgBatDau, '18:00');
      expect(slots.single.ngay, isNull);
    });
  });

  group('CrmTeacherApi.classes', () {
    test('parses { classes: [...] } with UUID section_id', () async {
      EmsApiService.client = jsonMock(
        (_) => {
          'classes': [
            {
              'section_id': 'bbbbbbbb-1111-2222-3333-444444444444',
              'section_code': '261_THUNGHIEM01_06CD15THUNGHIEM',
              'semester_code': '261',
              'room': 'P.101',
              'si_so': 40,
              'ngay_bat_dau': '2026-08-10',
              'ngay_ket_thuc': '2026-12-20',
              'ngay_thi': '2026-12-22',
              'subject_code': 'THUNGHIEM001',
              'subject_name': 'Môn thử nghiệm',
              'credits': 3,
              'enrolled_students': 38,
              'sessions': 15,
              'attendance_rows': 300,
              'grade_rows': 38,
            },
          ],
        },
      );

      final classes = await CrmTeacherApi.classes(semester: '261');
      expect(classes, hasLength(1));
      final c = classes.single;
      expect(c.sectionId, 'bbbbbbbb-1111-2222-3333-444444444444');
      expect(c.sectionCode, '261_THUNGHIEM01_06CD15THUNGHIEM');
      expect(c.enrolledStudents, 38);
      expect(c.credits, 3);
    });
  });

  group('CrmTeacherApi.classStudents', () {
    test('parses { students: [...] }', () async {
      EmsApiService.client = jsonMock(
        (_) => {
          'students': [
            {
              'enrollment_id': 'cccccccc-1111-2222-3333-444444444444',
              'mssv': 'TEST260001',
              'full_name': 'Nguyễn Thử Nghiệm',
              'status': 'active',
              'class_code': '06CD15THUNGHIEM',
              'grade_id': null,
              'midterm_score': 8.5,
              'final_exam_score': null,
              'final_score': null,
              'grade_status': null,
              'attendance_rows': 10,
              'present_rows': 9,
              'absent_rows': 1,
            },
          ],
        },
      );

      final students = await CrmTeacherApi.classStudents(
        'bbbbbbbb-1111-2222-3333-444444444444',
      );
      expect(students, hasLength(1));
      expect(students.single.mssv, 'TEST260001');
      expect(students.single.fullName, 'Nguyễn Thử Nghiệm');
      expect(students.single.presentRows, 9);
      expect(students.single.midtermScore, 8.5);
    });
  });

  group('CrmTeacherApi.classAttendance', () {
    test('parses the flat { attendance: [...] } rows', () async {
      EmsApiService.client = jsonMock(
        (_) => {
          'attendance': [
            {
              'session_id': 'dddddddd-1111-2222-3333-444444444444',
              'date': '2026-09-08T00:00:00.000Z',
              'start_time': '18:00:00',
              'end_time': '20:30:00',
              'room': 'P.101',
              'session_status': 'done',
              'attendance_id': 'eeeeeeee-1111-2222-3333-444444444444',
              'mssv': 'TEST260001',
              'full_name': 'Nguyễn Thử Nghiệm',
              'status': 'present',
              'notes': null,
            },
            // A session with no attendance recorded yet: mssv/status null.
            {
              'session_id': 'ffffffff-1111-2222-3333-444444444444',
              'date': '2026-09-15T00:00:00.000Z',
              'start_time': '18:00:00',
              'end_time': '20:30:00',
              'room': 'P.101',
              'session_status': 'scheduled',
              'attendance_id': null,
              'mssv': null,
              'full_name': null,
              'status': null,
              'notes': null,
            },
          ],
        },
      );

      final rows = await CrmTeacherApi.classAttendance(
        'bbbbbbbb-1111-2222-3333-444444444444',
      );
      expect(rows, hasLength(2));
      expect(rows.first.mssv, 'TEST260001');
      expect(rows.first.status, 'present');
      expect(rows.last.mssv, isNull);
    });
  });

  group('CrmTeacherApi.exams', () {
    test('parses { exams: [...] } with string-typed numeric fields', () async {
      EmsApiService.client = jsonMock(
        (_) => {
          'semester_code': '261',
          'exams': [
            {
              'exam_id': '99001',
              'exam_date': '2026-12-22T00:00:00.000Z',
              'start_time': '08:00',
              'duration_minutes': '60',
              'exam_type': 'Cuối kì',
              'exam_format': null,
              'class_size': '38',
              'proctor_1': 'Thử Nghiệm',
              'proctor_2': '',
              'note': '  ',
              'room': null,
              'class_code': '261_THUNGHIEM01_06CD15THUNGHIEM',
              'subject_code': 'THUNGHIEM001',
              'subject_name': 'Môn thử nghiệm',
              'credits': '3',
              'semester_code': '261',
              'semester_name': 'Học kỳ 1, 2026 - 2027',
            },
          ],
        },
      );

      final exams = await CrmTeacherApi.exams(semester: '261');
      expect(exams, hasLength(1));
      final e = exams.single;
      expect(e.examId, '99001');
      expect(e.durationMinutes, 60);
      expect(e.classSize, 38);
      expect(e.credits, 3);
      expect(e.room, isNull, reason: 'IMS phòng thi thường null — không bịa');
      expect(e.proctor1, 'Thử Nghiệm');
    });
  });

  group('CrmTeacherApi.overview', () {
    test('parses the combined /me/overview payload', () async {
      EmsApiService.client = jsonMock(
        (_) => {
          'teacher': {
            'teacher_id': 'aaaaaaaa-1111-2222-3333-444444444444',
            'teacher_code': '9990001',
            'name': 'Thử Nghiệm',
            'type': 'gvtg',
            'email': null,
            'phone': null,
            'ims_id': '834',
            'is_active': true,
          },
          'semesters': [
            {'id': 261, 'ma': '261', 'ten': 'Học kỳ 1, 2026 - 2027'},
          ],
          'current_semester': '261',
          'today_date': '2026-09-24',
          'today_sessions': [
            {
              'lmhid': '43461',
              'lmhma': '261_THUNGHIEM01_06CD15THUNGHIEM',
              'mhten': 'Môn thử nghiệm',
              'thoigianbd': '18:00',
              'thoigiankt': '2026-09-24T20:30:00.000Z',
              'ngay': '2026-09-24',
              'baonghiyn': false,
            },
          ],
          'semester_slots': [],
          'summary': {
            'section_count': 4,
            'student_count': 120,
            'subject_count': 4,
            'session_count': 60,
          },
          'cached_at': '2026-09-24T10:00:00.000Z',
        },
      );

      final overview = await CrmTeacherApi.overview(semester: '261');
      expect(overview.teacher.name, 'Thử Nghiệm');
      expect(overview.teacher.isCoHuu, isFalse, reason: "'gvtg' không phải cơ hữu");
      expect(overview.currentSemester, '261');
      expect(overview.todaySessions, hasLength(1));
      expect(overview.summary.studentCount, 120);
    });
  });
}
