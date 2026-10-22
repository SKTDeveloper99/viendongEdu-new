import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/core/lantern_gate.dart';
import 'package:viendongedu2_flutter/core/remote/app_remote_config.dart';
import 'package:viendongedu2_flutter/features/infinite/quest.dart';

void main() {
  final book = parseQuestBook(defaultQuestsJson)!;
  final s = book.school;

  test('built-in quest book parses with the school point', () {
    expect(book.quests.map((q) => q.id), [
      'checkin-1',
      'tiktok-1',
      'fanpage-1',
      'screen-qr-1',
      'quiz-1',
      'meeting-1',
    ]);
    expect(book.skipped, 0);
    expect(s.radiusM, 150);
    for (final q in book.quests) {
      expect(q.spot, isNotNull, reason: '${q.id} has a map pin');
      for (final r in q.rewards) {
        expect(book.cosmeticById(r), isNotNull, reason: '$r in ${q.id}');
      }
    }
  });

  test('the built-in book equals firebase/infinite/book.json', () {
    final file = jsonDecode(
      File('firebase/infinite/book.json').readAsStringSync(),
    );
    expect(jsonDecode(defaultQuestsJson), file);
  });

  test('an unusable document is rejected so the last good copy stays', () {
    expect(parseQuestBook('{"school": {}}'), isNull);
    expect(parseQuestBook('not json'), isNull);
    expect(parseQuestBook('[1, 2]'), isNull);
  });

  test('one bad quest is skipped, the rest still play', () {
    final b = parseQuestBook(
      '{"school": {"lat": 10.85, "lng": 106.63}, "quests": ['
      '{"id": "ok-1", "title": "Ok", "rewards": ["frame_blue", "nope"]},'
      '{"id": "Bad Id", "title": "x"},'
      '{"id": "no-title"},'
      '{"id": "ok-1", "title": "duplicate"},'
      '{"id": "link-1", "kind": "link", "title": "no url"},'
      '{"id": "qr-9", "kind": "qr", "title": "no hash"},'
      '{"id": "quiz-9", "kind": "quiz", "title": "one choice",'
      ' "code_sha256": "ab", "choices": ["a"]},'
      '{"id": "dance-1", "kind": "dance", "title": "Future kind"},'
      '"garbage"],'
      ' "cosmetics": [{"id": "frame_new", "name": "Mới", "frame": "accent"},'
      ' {"id": "broken"}]}',
    )!;
    expect(b.quests.map((q) => q.id), ['ok-1', 'dance-1']);
    expect(b.quests.last.playable, isFalse);
    expect(b.skipped, 8);
    expect(b.cosmeticById('frame_new')?.frameToken, 'accent');
    expect(b.cosmeticById('frame_blue'), isNotNull, reason: 'built-ins kept');
  });

  test('kill switch and notice come from the book', () {
    final b = parseQuestBook(
      '{"enabled": false, "notice": "Bảo trì",'
      ' "school": {"lat": 1, "lng": 2}}',
    )!;
    expect(b.enabled, isFalse);
    expect(b.notice, 'Bảo trì');
    expect(b.quests, isEmpty);
  });

  test('answers are hashed with the quest id; plain text is never shipped', () {
    final quiz = book.quests.firstWhere((q) => q.id == 'quiz-1');
    expect(quiz.codeMatches('Khung và danh hiệu'), isTrue);
    expect(quiz.codeMatches('  khung VÀ danh   hiệu '), isTrue);
    expect(quiz.codeMatches('Giảm học phí'), isFalse);
    expect(defaultQuestsJson.contains('VD-QR'), isFalse);
    expect(codeSha256('a', 'X'), isNot(codeSha256('b', 'X')));
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
    final q = Quest(
      id: 'x',
      kind: QuestKind.code,
      title: 't',
      codeHash: codeSha256('x', 'VIENDONG'),
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
    expect(studentDataOpen('K19A001', minPrefix: 0), isTrue);
    expect(AppRemoteConfig.defaultMinPrefix, 0, reason: 'open by default');
    expect(
      studentDataOpen('2416160001', minPrefix: 25, serverDataOpen: true),
      isTrue,
    );
    expect(
      studentDataOpen('2616160001', minPrefix: 25, serverDataOpen: false),
      isFalse,
    );
    expect(
      studentDataOpen('2416160001', minPrefix: 25, serverDataOpen: null),
      isFalse,
    );
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
