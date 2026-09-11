import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  test('attendance mark keeps gate provenance in the save payload', () {
    const mark = EmsMark(
      mssv: 'TEST26APP01',
      status: 'present',
      note: 'teacher-confirmed',
      punchId: 123,
    );
    expect(mark.toJson(), {
      'mssv': 'TEST26APP01',
      'status': 'present',
      'note': 'teacher-confirmed',
      'punch_id': 123,
    });
  });

  test('student timeline preserves pending status and gate arrival', () {
    final mark = EmsStudentMark.fromJson({
      'session_date': '2026-09-08',
      'status': null,
      'start_time': '18:00',
      'end_time': '20:30',
      'arrived_at': '2026-09-08T07:10:00+07:00',
      'arrival_on_time': true,
    });
    expect(mark.status, isNull);
    expect(mark.arrivedAt, isNotNull);
    expect(mark.arrivalOnTime, isTrue);
    expect(EmsStudentMark.fromJson(mark.toJson()).arrivalOnTime, isTrue);
  });
}
