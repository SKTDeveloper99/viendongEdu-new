import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/menu_item.dart';
import 'package:viendongedu2_flutter/core/lantern_gate.dart';
import 'package:viendongedu2_flutter/features/student_home/widgets/menu_grid.dart';
import 'package:viendongedu2_flutter/models/mock_data.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';

void main() {
  tearDown(
    () => AppSession.instance
      ..mssv = null
      ..dataOpen = null,
  );

  for (final scenario in [
    (gate: true, mssv: '24TEST', open: true),
    (gate: false, mssv: '26TEST', open: false),
    (gate: null, mssv: '24TEST', open: false),
    (gate: null, mssv: '26TEST', open: true),
  ]) {
    testWidgets(
      'all data menus honor ${scenario.gate} for ${scenario.mssv}; board/chat/game stay available',
      (tester) async {
        AppSession.instance
          ..mssv = scenario.mssv
          ..dataOpen = scenario.gate;
        final navigator = GlobalKey<NavigatorState>();
        final visited = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: MenuGrid()),
            onGenerateRoute: (settings) {
              visited.add(settings.name!);
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Trang thử nghiệm')),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(
          MockData.menuItems
              .map((m) => m['route'])
              .where(dataRoutes.contains)
              .toSet(),
          dataRoutes,
        );
        for (final menu in MockData.menuItems) {
          final label = menu['label']!;
          final route = menu['route']!;
          final before = visited.length;
          final widget = tester
              .widgetList<MenuItemWidget>(find.byType(MenuItemWidget))
              .singleWhere((w) => w.label == label);
          widget.onTap();
          await tester.pumpAndSettle();
          if (dataRoutes.contains(route) && !scenario.open) {
            expect(visited.length, before, reason: route);
            expect(find.text(noDataText), findsOneWidget);
            final messenger = tester.state<ScaffoldMessengerState>(
              find.byType(ScaffoldMessenger),
            );
            messenger.clearSnackBars();
          } else {
            expect(visited.last, route);
            navigator.currentState!.pop();
          }
          await tester.pumpAndSettle();
        }
      },
    );
  }
}
