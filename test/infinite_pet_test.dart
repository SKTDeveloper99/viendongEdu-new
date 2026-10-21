import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/data/infinite_repository.dart';
import 'package:viendongedu2_flutter/features/infinite/infinite_screen.dart';
import 'package:viendongedu2_flutter/features/infinite/pet.dart';
import 'package:viendongedu2_flutter/features/infinite/pet_motion.dart';
import 'package:viendongedu2_flutter/features/infinite/widgets/pet_companion.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';

final _target = find.byKey(const ValueKey('pet-tap-target'));
final _dizzy = find.byKey(const ValueKey('pet-dizzy'));
final _ready = find.byKey(const ValueKey('pet-ready'));

Widget _host({
  InfinitePet pet = InfinitePet.cat,
  bool reduced = false,
  bool accessible = false,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduced,
        accessibleNavigation: accessible,
      ),
      child: PetCompanion(pet: pet),
    ),
  ),
);

List<double> _matrix(WidgetTester tester, String key) => tester
    .widget<Transform>(find.byKey(ValueKey(key)))
    .transform
    .storage
    .toList();

Future<void> _spam(WidgetTester tester) async {
  for (var i = 0; i < PetMotion.tapsForDizzy; i++) {
    await tester.tap(_target);
    await tester.pump(
      i < PetMotion.tapsForDizzy - 1
          ? const Duration(milliseconds: 100)
          : Duration.zero,
    );
  }
}

void main() {
  for (final pet in InfinitePet.values) {
    testWidgets('${pet.name}: single tap squashes, stretches, then rests', (
      tester,
    ) async {
      await tester.pumpWidget(_host(pet: pet));
      final idle = _matrix(tester, 'pet-squash');
      await tester.tap(_target);
      await tester.pump();
      await tester.pump(PetMotion.squashDuration * 0.3);
      final squashed = _matrix(tester, 'pet-squash');
      expect(squashed[0], greaterThan(1));
      expect(squashed[5], lessThan(1));
      expect(_dizzy, findsNothing);
      await tester.pump(PetMotion.squashDuration * 0.35);
      final stretched = _matrix(tester, 'pet-squash');
      expect(stretched[0], lessThan(1));
      expect(stretched[5], greaterThan(1));
      await tester.pumpAndSettle();
      expect(_matrix(tester, 'pet-squash'), idle);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('only N quick taps enter dizzy with wobble and spinning stars', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final idle = _matrix(tester, 'pet-wobble');
    for (var i = 0; i < PetMotion.tapsForDizzy - 1; i++) {
      await tester.tap(_target);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_dizzy, findsNothing);
    }
    await tester.tap(_target);
    await tester.pump();
    expect(_dizzy, findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(3));
    final star = _matrix(tester, 'pet-star-0');
    final position = tester.getCenter(find.byKey(const ValueKey('pet-star-0')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_matrix(tester, 'pet-wobble'), isNot(idle));
    expect(_matrix(tester, 'pet-star-0'), isNot(star));
    expect(
      tester.getCenter(find.byKey(const ValueKey('pet-star-0'))),
      isNot(position),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dizzy recovers on time despite more taps, then can play again', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final idle = _matrix(tester, 'pet-squash');
    await _spam(tester);
    await tester.pump(
      PetMotion.dizzyDuration - const Duration(milliseconds: 1),
    );
    expect(_dizzy, findsOneWidget);
    await tester.tap(_target);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_ready, findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(_matrix(tester, 'pet-squash'), idle);
    await tester.tap(_target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(_matrix(tester, 'pet-squash'), isNot(idle));
    expect(_dizzy, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('taps outside the rolling window do not cause dizziness', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    for (var i = 0; i < PetMotion.tapsForDizzy + 2; i++) {
      await tester.tap(_target);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_dizzy, findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
  });

  for (final accessible in [false, true]) {
    testWidgets(
      'reduced motion (accessible=$accessible) keeps feedback static',
      (tester) async {
        await tester.pumpWidget(
          _host(reduced: !accessible, accessible: accessible),
        );
        final scale = _matrix(tester, 'pet-squash');
        final rotation = _matrix(tester, 'pet-wobble');
        await tester.tap(_target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(_matrix(tester, 'pet-squash'), scale);
        expect(_dizzy, findsNothing);
        // Let this tap expire before starting a fresh burst.
        await tester.pump(PetMotion.tapWindow);
        await _spam(tester);
        expect(_dizzy, findsOneWidget);
        final star = _matrix(tester, 'pet-star-0');
        final position = tester.getCenter(
          find.byKey(const ValueKey('pet-star-0')),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(_matrix(tester, 'pet-squash'), scale);
        expect(_matrix(tester, 'pet-wobble'), rotation);
        expect(_matrix(tester, 'pet-star-0'), star);
        expect(
          tester.getCenter(find.byKey(const ValueKey('pet-star-0'))),
          position,
        );
        await tester.pump(
          PetMotion.dizzyDuration - const Duration(milliseconds: 100),
        );
        expect(_ready, findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }

  testWidgets('enabling reduced motion stops active squash and dizzy motion', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final idleScale = _matrix(tester, 'pet-squash');
    final idleRotation = _matrix(tester, 'pet-wobble');
    await tester.tap(_target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(_host(reduced: true));
    expect(_matrix(tester, 'pet-squash'), idleScale);
    await tester.pump(PetMotion.tapWindow);
    await tester.pumpWidget(_host());
    await _spam(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_matrix(tester, 'pet-wobble'), isNot(idleRotation));
    await tester.pumpWidget(_host(reduced: true));
    expect(_dizzy, findsOneWidget);
    expect(_matrix(tester, 'pet-wobble'), idleRotation);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('switching pet clears reactions and disposing cancels timers', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await _spam(tester);
    await tester.pumpWidget(_host(pet: InfinitePet.dog));
    expect(_ready, findsOneWidget);
    expect(find.text('Chạm để chơi với Cún'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);
    await _spam(tester);
    expect(_dizzy, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(PetMotion.dizzyDuration + PetMotion.tapWindow);
    expect(tester.takeException(), isNull);
  });

  group('pet selection', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppSession.instance.mssv = 'TEST26PET01';
    });
    tearDown(() => AppSession.instance.mssv = null);

    test('defaults safely and stores a separate choice per student', () async {
      final repo = InfiniteRepository();
      expect(await repo.selectedPet(), InfinitePet.cat);
      await repo.selectPet(InfinitePet.dog);
      expect(await InfiniteRepository().selectedPet(), InfinitePet.dog);
      AppSession.instance.mssv = 'TEST26PET02';
      expect(await repo.selectedPet(), InfinitePet.cat);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('infinite.TEST26PET02.pet', 'unknown');
      expect(await repo.selectedPet(), InfinitePet.cat);
    });

    testWidgets(
      'Infinite screen selects one pet and restores it on reopening',
      (tester) async {
        Widget screen() => const MaterialApp(home: InfiniteScreen());
        await tester.pumpWidget(screen());
        await tester.pumpAndSettle();
        expect(find.byType(PetCompanion), findsOneWidget);
        expect(find.byType(ChoiceChip), findsNWidgets(2));
        await tester.tap(find.widgetWithText(ChoiceChip, 'Chó Cún'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<PetCompanion>(find.byType(PetCompanion)).pet,
          InfinitePet.dog,
        );
        expect(
          tester
              .widgetList<ChoiceChip>(find.byType(ChoiceChip))
              .where((chip) => chip.selected),
          hasLength(1),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(screen());
        await tester.pumpAndSettle();
        expect(
          tester.widget<PetCompanion>(find.byType(PetCompanion)).pet,
          InfinitePet.dog,
        );
      },
    );
  });
}
