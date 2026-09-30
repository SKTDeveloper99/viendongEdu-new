import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/core/default_semester.dart';

typedef _S = ({String code, DateTime? start});

void main() {
  final today = DateTime(2026, 9, 30);
  // Sorted desc by code like the screens do: two fake future semesters first.
  final list = <_S>[
    (code: '272', start: DateTime(2027, 2, 1)),
    (code: '271', start: DateTime(2026, 10, 15)),
    (code: '262', start: DateTime(2026, 2, 1)),
    (code: '261', start: DateTime(2025, 9, 1)),
  ];
  String code(_S s) => s.code;
  DateTime? start(_S s) => s.start;

  test('current_semester present wins over list order', () {
    final r = pickDefaultSemester(
      list,
      codeOf: code,
      startOf: start,
      currentCode: '262',
      today: today,
    );
    expect(r!.code, '262');
  });

  test('current absent: newest semester already started', () {
    final r = pickDefaultSemester(
      list,
      codeOf: code,
      startOf: start,
      currentCode: null,
      today: today,
    );
    expect(r!.code, '262');
    final unknown = pickDefaultSemester(
      list,
      codeOf: code,
      startOf: start,
      currentCode: '999',
      today: today,
    );
    expect(unknown!.code, '262');
  });

  test('everything in the future: first item; empty list: null', () {
    final future = list.take(2).toList();
    final r = pickDefaultSemester(
      future,
      codeOf: code,
      startOf: start,
      today: today,
    );
    expect(r!.code, '272');
    expect(pickDefaultSemester(<_S>[], codeOf: code), isNull);
  });

  test('no dates at all: first item', () {
    final r = pickDefaultSemester(
      [(code: 'a', start: null)],
      codeOf: code,
      startOf: start,
      today: today,
    );
    expect(r!.code, 'a');
  });
}
