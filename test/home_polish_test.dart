import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/work_home/home_widgets.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

Widget _app(Widget child) => MaterialApp(
  theme: VdTheme.light(),
  home: Scaffold(body: child),
);

List<HomeTileSpec> _six() => [
  for (final l in ['Việc', 'Nhóm', 'Lịch', 'Lớp', 'Văn phòng', 'Thêm'])
    HomeTileSpec(Icons.circle, l, onTap: () {}),
];

void main() {
  testWidgets('tiles keep one comfortable height on an empty tall home', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        SizedBox(width: 390, height: 700, child: HomeTileGrid(tiles: _six())),
      ),
    );
    final h = t.getSize(find.byType(HomeTile).first).height;
    expect(h, homeTileHeight);
  });

  testWidgets('tiles shrink only when a small phone has less room', (t) async {
    await t.pumpWidget(
      _app(
        SizedBox(width: 340, height: 180, child: HomeTileGrid(tiles: _six())),
      ),
    );
    final h = t.getSize(find.byType(HomeTile).first).height;
    expect(h, lessThan(homeTileHeight));
    expect(h, greaterThanOrEqualTo(64));
  });

  testWidgets('a long focus title wraps to a second line, not cut', (t) async {
    const long =
        'Báo cáo tổng hợp tình hình chăm sóc sinh viên năm nhất học kỳ 261';
    await t.pumpWidget(
      _app(
        SizedBox(
          width: 360,
          child: CompactFocusCard(
            chip: 'Sắp đến hạn',
            right: 'hạn 12:00 24/11',
            title: long,
            line: 'Việc của tôi',
            action: 'Mở',
            onAction: () {},
          ),
        ),
      ),
    );
    final text = t.widget<Text>(find.text(long));
    expect(text.maxLines, 2);
    final oneLine = (text.style?.fontSize ?? 17) * 1.6;
    expect(t.getSize(find.text(long)).height, greaterThan(oneLine));
  });
}
