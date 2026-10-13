import 'package:viendongedu2_flutter/models/teacher_care_student.dart';

const careSectionId = 'section-test';
const careJsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> careMoneyJson({bool owes = false}) => {
  'money_known': true,
  'owedTotal': 4000000,
  'paid': 2500000,
  'balance': 1500000,
  'owes': owes,
  'as_of': '2026-10-13T03:15:00Z',
  'stale': false,
  'source': 'bang_ke',
  'basis': 'crm_law',
  'payment_status': 'IMS CRM Kế toán bảng kê staff_reason',
};

Map<String, dynamic> careStudentJson([int index = 0]) => {
  'mssv': 'TEST25-$index',
  'checks': [],
  'can_review_sections': [careSectionId],
  'dossier': {
    'full_name': 'Sinh viên thử nghiệm $index',
    'class_code': 'TEST',
    'money': {'status': 'no', 'ims_balance': 9999999},
    'money_one': careMoneyJson(),
    'freshness': {'attendance': true, 'grades': true},
    'sections': [
      {
        'section_id': careSectionId,
        'subject_name': 'Môn thử nghiệm',
        'present': 3,
        'absent': 0,
        'unrecorded': 2,
        'conflicts': 0,
        'midterm_score': '7.5',
        'final_score': null,
      },
    ],
  },
};

TeacherCareStudent careStudent([int index = 0]) =>
    TeacherCareStudent.fromJson(careStudentJson(index));
