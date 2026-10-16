import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/core/password_policy.dart';

String? student(String next, {String current = 'TEST26APP01'}) =>
    newPasswordProblem(
      next,
      current: current,
      mssv: 'TEST26APP01',
      student: true,
    );

void main() {
  test('student rules match the server order and wording', () {
    expect(student('test26app01x'), contains('mã số sinh viên'));
    expect(student('abc12'), contains('8 ký tự'));
    expect(student('abcdefgh'), contains('chữ và số'));
    expect(student('12345678'), contains('chữ và số'));
    expect(student('vienDong2026'), isNull);
    expect(student('vienDong2026', current: 'vienDong2026'), contains('khác'));
  });

  test('teachers only need 8 characters', () {
    expect(
      newPasswordProblem('abcdefgh', current: 'x', mssv: null, student: false),
      isNull,
    );
    expect(
      newPasswordProblem('abc', current: 'x', mssv: null, student: false),
      contains('8 ký tự'),
    );
  });
}
