import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/core/lantern_gate.dart';
import 'package:viendongedu2_flutter/features/infinite/quest.dart';

void main() {
  final book = parseQuestBook(defaultQuestsJson)!;
  final s = book.school;

  test('built-in quest book parses with the school point', () {
    expect(book.quests.map((q) => q.id), [
      'checkin-1',
      'tiktok-1',
      'fanpage-1',
    ]);
    expect(s.radiusM, 150);
    for (final q in book.quests) {
      for (final r in q.rewards) {
        expect(cosmeticById(r), isNotNull, reason: '$r in ${q.id}');
      }
    }
  });

  test('bad Remote Config JSON is rejected, not half-used', () {
    expect(parseQuestBook('{"school": {}}'), isNull);
    expect(parseQuestBook('not json'), isNull);
  });

  test('at the gate counts; 1 km away does not', () {
    expect(atSchool(s, s.lat, s.lng, 10), isTrue);
    expect(atSchool(s, s.lat + 0.001, s.lng, 10), isTrue); // ~111 m
    expect(atSchool(s, s.lat + 0.009, s.lng, 10), isFalse); // ~1 km
  });

  test('poor accuracy forgives at most 50 m', () {
    expect(atSchool(s, s.lat + 0.0017, s.lng, 500), isTrue); // ~189 m
    expect(atSchool(s, s.lat + 0.0025, s.lng, 500), isFalse); // ~278 m
  });

  test('code check ignores case and spaces; no code = any input', () {
    const q = Quest(
      id: 'x',
      title: 't',
      desc: '',
      rewards: [],
      code: 'Vien Dong',
    );
    expect(q.codeMatches(' viendong '), isTrue);
    expect(q.codeMatches('vien'), isFalse);
    expect(book.quests.first.codeMatches(''), isTrue);
  });

  test('quest dates are inclusive', () {
    final q = Quest(
      id: 'x',
      title: 't',
      desc: '',
      rewards: const [],
      from: DateTime(2026, 10, 15),
      to: DateTime(2026, 10, 31),
    );
    expect(q.activeOn(DateTime(2026, 10, 14, 23)), isFalse);
    expect(q.activeOn(DateTime(2026, 10, 15, 8)), isTrue);
    expect(q.activeOn(DateTime(2026, 10, 31, 22)), isTrue);
    expect(q.activeOn(DateTime(2026, 11, 1)), isFalse);
  });

  test('Lantern gate opens data only for MSSV 25 and up', () {
    expect(studentDataOpen('2516160001', minPrefix: 25), isTrue);
    expect(studentDataOpen(' 2602020001', minPrefix: 25), isTrue);
    expect(studentDataOpen('2416160001', minPrefix: 25), isFalse);
    expect(studentDataOpen('K19A001', minPrefix: 25), isFalse);
    expect(studentDataOpen(null, minPrefix: 25), isTrue);
    expect(studentDataOpen('2416160001', minPrefix: 0), isTrue);
  });

  test('a quest with its own place is checked there, not at school', () {
    final b = parseQuestBook(
      '{"school": {"lat": 10.85, "lng": 106.63},'
      ' "quests": [{"id": "t", "title": "t", "rewards": [],'
      ' "place": {"lat": -37.9489, "lng": 145.0471, "radius_m": 150}}]}',
    )!;
    final p = b.quests.single.place!;
    expect(atSchool(p, -37.9489, 145.0471, 10), isTrue);
    expect(atSchool(b.school, -37.9489, 145.0471, 10), isFalse);
  });
}
