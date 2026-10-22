// Fictional contracts checked against the committed CRM student portal,
// phone-app-compat and student-partial-open response definitions.
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/models/crm_money_capbu.dart';
import 'package:viendongedu2_flutter/models/crm_money_fees.dart';
import 'package:viendongedu2_flutter/models/crm_money_tuition.dart';
import 'package:viendongedu2_flutter/models/crm_registration_models.dart';
import 'package:viendongedu2_flutter/models/crm_student_exams.dart';
import 'package:viendongedu2_flutter/models/crm_student_grades.dart';
import 'package:viendongedu2_flutter/models/crm_student_graduation_summary.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/models/json_values.dart';

void main() {
  test(
    'PostgreSQL numeric strings and true zeros survive all student models',
    () {
      final section = CrmStudentSection.fromJson({
        'section_id': 'fixture-uuid',
        'credits': '0.0',
        'si_so': '12',
        'ngay_bat_dau': '2026-10-01',
        'ngay_ket_thuc': '2026-12-01',
        'ngay_thi': '2026-12-02',
        'room': 'TEST-R1',
      });
      expect(section.sectionId, isNull); // UUIDs are not numeric identities.
      expect(section.credits, 0);
      expect(section.siSo, 12);
      expect(section.examDate, DateTime.utc(2026, 12, 2));
      expect(section.room, 'TEST-R1');
      final grade = CrmStudentGrade.fromJson({
        'grade_id': 'fixture-uuid',
        'credits': '3.0',
        'midterm_score': '0',
        'final_exam_score': '7.5',
        'final_score': '0.0',
      });
      expect(grade.credits, 3);
      expect(grade.midtermScore, 0);
      expect(grade.finalExamScore, 7.5);
      expect(grade.isUngraded, isFalse);
      expect(grade.gradeLetter, 'F');
      final academic = CrmAcademicSummary.fromJson({
        'total': '1',
        'scored': '1',
        'average_score': '0.0',
        'failed': '1',
        'has_curriculum': true,
        'required_subjects': '2',
        'required_passed': '0',
      });
      expect(academic.total, 1);
      expect(academic.averageScore, 0);
      expect(academic.requiredPassed, 0);
      final exam = CrmStudentExam.fromJson({
        'duration_minutes': '0',
        'credits': '3.0',
      });
      expect(exam.durationMinutes, 0);
      expect(exam.credits, 3);
      expect(CrmScheduleItem.fromJson({'num_periods': '2'}).numPeriods, 2);
      expect(CrmRemainingSubject.fromJson({'credits': '2.0'}).credits, 2);
      expect(
        CrmRegistrationOffering.fromJson({
          'offering_id': 'TEST-O',
          'credits': '3.0',
          'registered_count': '0',
        }).registeredCount,
        0,
      );
    },
  );

  for (final invalid in [null, '', 'wrong', 'NaN', 'Infinity', true, [], {}]) {
    test('malformed numeric $invalid stays unknown without throwing', () {
      expect(jsonDouble(invalid), isNull);
      expect(jsonInt(invalid), isNull);
      final grade = CrmStudentGrade.fromJson({
        'final_score': invalid,
        'credits': invalid,
        'diem4': invalid,
      });
      expect(grade.finalScore, isNull);
      expect(grade.credits, isNull);
      expect(grade.gradeLetter, '');
      expect(grade.isPassed, isFalse);
      expect(
        CrmStudentExam.fromJson({'duration_minutes': invalid}).durationMinutes,
        isNull,
      );
      expect(CrmTuitionPayment.fromJson({'so_tien': invalid}).soTien, isNull);
      expect(CrmFeeItem.fromJson({'so_tien': invalid}).soTien, isNull);
      expect(CrmCapBuItem.fromJson({'total': invalid}).total, isNull);
    });
  }

  test('integers do not silently truncate malformed money or identifiers', () {
    expect(jsonInt('1.5'), isNull);
    expect(jsonInt(2.9), isNull);
    expect(jsonInt('-125000.0'), -125000);
    expect(jsonInt('9007199254740993'), 9007199254740993);
  });

  test(
    'missing and malformed nested blocks keep academic progress unknown',
    () {
      for (final block in [null, 'wrong', [], {}]) {
        final summary = CrmGraduationSummary.fromJson({
          'academic': block,
          'remaining_subjects': 'wrong',
        });
        expect(summary.academic.hasCurriculum, isFalse);
        expect(summary.academic.total, isNull);
        expect(summary.academic.requiredSubjects, isNull);
        expect(summary.academic.academicallyClear, isNull);
        expect(summary.remainingSubjectsKnown, isFalse);
      }
      final partial = CrmGraduationSummary.fromJson({
        'academic': {
          'has_curriculum': false,
          'required_subjects': 0,
          'required_passed': 0,
          'academically_clear': null,
          'average_score': '7.0',
        },
        'remaining_subjects': [],
      });
      expect(partial.academic.hasCurriculum, isFalse);
      expect(partial.academic.averageScore, 7);
      expect(partial.academic.academicallyClear, isNull);
      expect(partial.remainingSubjectsKnown, isTrue);
      expect(
        CrmStudentGradesView.fromJson({
          'summary': [],
          'grades': [null, <String, dynamic>{}, 'wrong'],
        }).grades,
        hasLength(1),
      );
      expect(
        CrmStudentExamsView.fromJson({
          'exams': [null, <String, dynamic>{}, false],
        }).exams,
        hasLength(1),
      );
      expect(
        CrmStudentScheduleView.fromJson({
          'schedule': false,
          'chua_co_lich': [null, <String, dynamic>{}],
        }).chuaCoLich,
        hasLength(1),
      );
    },
  );

  test(
    'money totals, receipts, fees and credits are separate server figures',
    () {
      final tuition = CrmTuitionResponse.fromJson({
        'mssv': 'TEST260001',
        'summary': {
          'owedTotal': '0',
          'paid': '125000',
          'balance': '0.0',
          'money_known': true,
          'other_receipts': {
            'mien_giam_khen_thuong': '-25000',
            'hoan_phi': '10000',
          },
        },
        'payments': [
          null,
          {'phieu_thu_id': 'TEST-P', 'so_tien': '-125000.0'},
        ],
      });
      expect(tuition.summary.owedTotal, 0);
      expect(tuition.summary.paid, 125000);
      expect(tuition.summary.otherReceipts.mienGiamKhenThuong, -25000);
      expect(tuition.summary.otherReceipts.hoanPhi, 10000);
      expect(tuition.payments.single.soTien, -125000);
      final fees = CrmFeesResponse.fromJson({
        'totals': {'le_phi_khac': '0', 'mien_giam_khen_thuong': '-25000'},
        'by_type': [
          null,
          {'tong': '-25000', 'so_lan': '1'},
        ],
        'items': [
          false,
          {'so_tien': '-25000'},
        ],
      });
      expect(fees.totals.lePhiKhac, 0);
      expect(fees.totals.mienGiamKhenThuong, -25000);
      expect(fees.byType.single.tong, -25000);
      expect(fees.items.single.soTien, -25000);
      for (final block in [null, false, [], 'wrong']) {
        expect(
          CrmTuitionResponse.fromJson({'summary': block}).summary.owedTotal,
          isNull,
        );
        expect(
          CrmFeesResponse.fromJson({'totals': block}).totals.lePhiKhac,
          isNull,
        );
      }
      final partial = CrmTuitionResponse.fromJson({
        'summary': {
          'money_known': false,
          'money_unknown_reason': 'Đang đối chiếu',
        },
        'payments': [
          {'so_tien': '125000'},
        ],
      });
      expect(partial.summary.balance, isNull);
      expect(partial.summary.moneyKnown, isFalse);
      expect(partial.payments.single.soTien, 125000);
      expect(CrmCongNo.fromJson({'computable': false}).congNo, isNull);
      expect(
        CrmCapBuResponse.fromJson({
          'items': [
            null,
            {'total': '0.0'},
            {'total': null},
          ],
        }).items.map((i) => i.total),
        [0, null],
      );
    },
  );

  test('registration flags do not grant access from malformed booleans', () {
    expect(CrmRegistrationPeriod.fromJson({'is_open': 'true'}).isOpen, isFalse);
    expect(CrmRegistrationPeriod.fromJson({'is_open': true}).isOpen, isTrue);
    final page = CrmRegistrationOfferingsPage.fromJson({
      'curriculum_resolved': false,
      'offerings': [
        null,
        {'offering_id': 'TEST-O', 'in_my_curriculum': 'true'},
      ],
    });
    expect(page.curriculumResolved, isFalse);
    expect(page.offerings.single.inMyCurriculum, isNull);
    expect(
      CrmRegistrationResult.fromJson({'source': 'ems_request'}).sourceLabel,
      'Đã gửi (EMS)',
    );
    expect(
      CrmRegistrationResult.fromJson({'source': 'ims_roster'}).sourceLabel,
      'Đã xếp lớp',
    );
  });
}
