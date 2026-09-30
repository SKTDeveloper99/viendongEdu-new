import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import '../theme/vd_tokens.dart';

/// Bottom sheet chọn giao diện Sáng / Tối / Theo máy. Dùng chung cho tab
/// "Cá nhân" của giảng viên và học viên.
Future<void> showThemeModeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.vd.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final controller = ThemeController.instance;
      return SafeArea(
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: controller,
          builder: (_, current, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                'Giao diện',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: sheetContext.vd.ink,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<ThemeMode>(
                groupValue: current,
                onChanged: (m) {
                  if (m == null) return;
                  controller.set(m);
                  Navigator.pop(sheetContext);
                },
                child: Column(
                  children: [
                    for (final m in ThemeMode.values)
                      RadioListTile<ThemeMode>(
                        value: m,
                        title: Text(ThemeController.label(m)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
