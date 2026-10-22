import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/classes/class_models.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';

void main() {
  test('skipsWeeks: only a break between active weeks counts', () {
    bool skips(String? p) => CrmScheduleItem(weeksPattern: p).skipsWeeks;
    expect(skips('-234567890123456--------------'), isFalse);
    expect(skips('-23-56'), isTrue);
    expect(skips('12 45'), isTrue);
    expect(skips(null), isFalse);
    expect(skips(''), isFalse);
  });

  test('course dates read dd/MM/yyyy, N/A when unknown', () {
    expect(fmtCalendarDay(DateTime.utc(2026, 12, 5)), '05/12/2026');
    expect(fmtCalendarDay(null), 'N/A');
  });
}
