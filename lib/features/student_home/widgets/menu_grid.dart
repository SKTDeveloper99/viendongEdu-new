import 'package:flutter/material.dart';

import '../../../components/menu_item.dart';
import '../../../core/lantern_gate.dart';
import '../../../services/app_session.dart';
import '../../../models/mock_data.dart';

IconData mapStringToIcon(String? name) => switch (name) {
  'calendar_today' => Icons.calendar_today,
  'assignment' => Icons.assignment,
  'account_balance' => Icons.account_balance,
  'add_circle' => Icons.add_circle,
  'bar_chart' => Icons.bar_chart,
  'fact_check' => Icons.fact_check_outlined,
  'people' => Icons.people,
  'payments' => Icons.payments,
  'receipt_long' => Icons.receipt_long,
  'campaign' => Icons.campaign,
  'help' => Icons.question_answer_outlined,
  'games' => Icons.sports_esports_outlined,
  _ => Icons.help_outline,
};

/// The 4-column menu of shortcuts (routes come from [MockData.menuItems]).
class MenuGrid extends StatelessWidget {
  const MenuGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final items = MockData.menuItems;
    final dataOpen = studentDataOpen(
      AppSession.instance.mssv,
      serverDataOpen: AppSession.instance.dataOpen,
    );
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: items.length,
      gridDelegate: menuGridDelegate(context),
      itemBuilder: (context, index) {
        final m = items[index];
        final route = m['route']?.toString() ?? '/home';
        return MenuItemWidget(
          index: index,
          icon: mapStringToIcon(m['icon']?.toString()),
          label: m['label']?.toString() ?? '',
          onTap: () => !dataOpen && dataRoutes.contains(route)
              ? ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text(noDataText)))
              : Navigator.pushNamed(context, route),
        );
      },
    );
  }
}
