import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/infinite_repository.dart';
import 'package:viendongedu2_flutter/features/infinite/infinite_screen.dart';
import 'package:viendongedu2_flutter/features/infinite/quest.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

class _Repo extends InfiniteRepository {
  final claimedIds = <String>{};
  @override
  Future<QuestBook> loadBook() async => parseQuestBook(defaultQuestsJson)!;
  @override
  Future<Set<String>> claimed() async => {...claimedIds};
  @override
  Future<Set<String>> opened() async => {};
  @override
  Future<Set<String>> unlocked() async => {};
  @override
  Future<Map<String, String?>> equipped() async => {};
  @override
  Future<void> markClaimedIds(Iterable<String> ids, Iterable<String> r) async =>
      claimedIds.addAll(ids);
  @override
  Future<void> equip(String slot, String? id) async {}
  @override
  Future<Set<String>> cloudClaimed() async => {};
  @override
  Future<CloudVerdict> cloudClaim(Quest q, String code, Fix? fix) async =>
      CloudVerdict.saved;
  @override
  Future<void> cloudEquip(String? frame, String? title) async {}
}

void main() {
  testWidgets('pin sheet: wrong answer shows in the card, right one closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: InfiniteScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Vườn cây')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Giảm học phí')),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Nhận thưởng')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Chưa đúng rồi. Thử lại nhé!'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Khung và danh hiệu')),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Nhận thưởng')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repo.claimedIds, {'quiz-1'});
    expect(find.textContaining('Hoàn thành!'), findsOneWidget);
  });
}
