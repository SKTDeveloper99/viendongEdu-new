import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/infinite_repository.dart';
import 'package:viendongedu2_flutter/features/infinite/infinite_screen.dart';
import 'package:viendongedu2_flutter/features/infinite/pet.dart';
import 'package:viendongedu2_flutter/features/infinite/quest.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

class _PreviewRepository extends InfiniteRepository {
  @override
  Future<InfinitePet> selectedPet() async => InfinitePet.cat;
  @override
  Future<QuestBook> loadBook() async => parseQuestBook(defaultQuestsJson)!;
  @override
  Future<Set<String>> cloudClaimed() async => {};
  @override
  Future<void> cloudEquip(String? frame, String? title) async {}
  @override
  Future<Set<String>> claimed() async => {'checkin-1'};
  @override
  Future<Set<String>> opened() async => {'tiktok-1'};
  @override
  Future<Set<String>> unlocked() async => {
    'frame_blue',
    'title_explorer',
    'frame_gold',
  };
  @override
  Future<Map<String, String?>> equipped() async => {
    'frame': 'frame_gold',
    'title': 'title_explorer',
  };
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile, this.tolerance);
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = await getGoldenBytes(golden);
    final r = await GoldenFileComparator.compareLists(imageBytes, goldenBytes);
    if (r.passed || r.diffPercent <= tolerance) return true;
    final error = await generateFailureOutput(r, golden, basedir);
    throw FlutterError(error);
  }
}

String? _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  try {
    final r = Process.runSync('which', ['flutter']);
    if (r.exitCode == 0) {
      final bin = File((r.stdout as String).trim()).resolveSymbolicLinksSync();
      return File(bin).parent.parent.path;
    }
  } catch (_) {}
  return null;
}

Future<void> _loadFonts() async {
  final be = FontLoader('BeVietnamPro');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    be.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$w.ttf'));
  }
  await be.load();
  final root = _flutterRoot();
  if (root == null) return;
  final f = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!f.existsSync()) return;
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await icons.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadFonts();
    final base = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _TolerantComparator(
      base.basedir.resolve('infinite_preview_golden_test.dart'),
      0.02,
    );
  });
  testWidgets('Lobby fits a narrow phone and respects reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> show(bool reducedMotion) => tester.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: InfiniteScreen(repository: _PreviewRepository()),
      ),
    );
    await show(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
    expect(tester.takeException(), isNull);
    await show(true);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.scrollUntilVisible(
      find.text('Bộ sưu tập'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final mode in ['light', 'dark']) {
    testWidgets('Infinite lobby preview ($mode)', (tester) async {
      tester.view.physicalSize = const Size(780, 2800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final oldName = AppSession.instance.fullName;
      AppSession.instance.fullName = 'Thử Nghiệm Ứng Dụng';
      addTearDown(() => AppSession.instance.fullName = oldName);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: VdTheme.light(),
          darkTheme: VdTheme.dark(),
          themeMode: mode == 'dark' ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: InfiniteScreen(repository: _PreviewRepository()),
        ),
      );
      await tester.pumpAndSettle();
      // Asset decoding runs outside the fake clock. Wait for every visible
      // image so the first preview cannot silently capture blank artwork.
      await tester.runAsync(() async {
        final context = tester.element(find.byType(InfiniteScreen));
        await Future.wait([
          for (final image in tester.widgetList<Image>(find.byType(Image)))
            precacheImage(image.image, context),
        ]);
      });
      await tester.pumpAndSettle();
      expect(find.text('Đã hoàn thành 1/6 nhiệm vụ'), findsOneWidget);
      expect(find.text('Đã xong'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/infinite_preview_$mode.png'),
      );
    });
  }
}
