// "Chụp ảnh" in the hand-in and report sheets, and the top notice clear of
// the status bar.
//
//   flutter test test/camera_and_notice_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_sheet.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';
import 'package:viendongedu2_flutter/utils/snack.dart';

void main() {
  testWidgets('hand-in: Chụp ảnh adds the camera photo; a camera that fails '
      'says so', (t) async {
    HandInResult? got;
    var fail = false;
    await t.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async => got = await showHandInSheet(
                ctx,
                pickPhotos: () async => const [],
                pickFiles: () async => const [],
                takePhoto: () async {
                  if (fail) throw Exception('no camera');
                  return [
                    (
                      name: 'Ảnh 20-11 22.00.jpg',
                      size: 3,
                      read: () async => <int>[1, 2, 3],
                    ),
                  ];
                },
                attach: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('handin-attach')));
    await t.pumpAndSettle();
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn ảnh'), findsOneWidget);
    expect(find.text('Chọn tệp (PDF, Word, Excel…)'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('attach-camera')));
    await t.pumpAndSettle();
    expect(find.text('Ảnh 20-11 22.00.jpg'), findsOneWidget);
    fail = true;
    await t.tap(find.byKey(const ValueKey('handin-attach')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('attach-camera')));
    await t.pumpAndSettle();
    expect(find.text('Không mở được máy ảnh trên máy này.'), findsOneWidget);
    await t.tap(find.text('Nộp kèm 1 tệp'));
    await t.pumpAndSettle();
    expect(got?.files.single.name, 'Ảnh 20-11 22.00.jpg');
  });

  testWidgets('the notice sits below the status bar on a screen with a '
      'floating button, and grows downward', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        // Around the Navigator, so the top overlay sees the status bar too.
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            size: const Size(402, 874),
            padding: const EdgeInsets.only(top: 62, bottom: 34),
          ),
          child: child!,
        ),
        home: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            label: const Text('Thêm dòng'),
          ),
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    showSuccessSnack(ctx, 'Đã thêm 1 tệp.');
    await t.pumpAndSettle();
    final one = t.getRect(find.text('Đã thêm 1 tệp.'));
    expect(one.top, greaterThan(62));
    showErrorSnack(
      ctx,
      List.filled(6, 'Một dòng giải thích dài cho người dùng.').join('\n'),
    );
    await t.pumpAndSettle();
    expect(
      find.text('Đã thêm 1 tệp.'),
      findsNothing,
      reason: 'a new notice replaces the old one',
    );
    final many = t.getRect(find.textContaining('Một dòng giải thích'));
    expect(many.top, greaterThan(62));
    expect(many.bottom, lessThan(874));
    // It closes by itself.
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.textContaining('Một dòng giải thích'), findsNothing);
  });
}
