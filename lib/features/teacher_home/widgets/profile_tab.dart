import 'package:flutter/material.dart';

import 'profile_menu_card.dart';
import '../../../components/theme_mode_sheet.dart';
import '../../../services/theme_controller.dart';
import '../../../theme/vd_tokens.dart';

/// Profile tab: identity header, three menu cards and the version footer.
class ProfileTab extends StatelessWidget {
  final String name;
  final String code;
  final VoidCallback onOpenInfo;
  final VoidCallback onLogout;
  const ProfileTab({
    super.key,
    required this.name,
    required this.code,
    required this.onOpenInfo,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.vd.surface,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.vd.headerTop, context.vd.headerBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.vd.onHeader.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.vd.onHeader, width: 2.5),
                  ),
                  child: Icon(
                    Icons.person,
                    color: context.vd.onHeader,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.vd.onHeader,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        code,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.vd.onHeader.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                children: [
                  ProfileMenuCard(
                    icon: Icons.person_outline,
                    label: 'Thông tin cá nhân',
                    onTap: onOpenInfo,
                  ),
                  const SizedBox(height: 10),
                  ProfileMenuCard(
                    icon: Icons.lock_outline,
                    label: 'Đổi mật khẩu',
                    onTap: () =>
                        Navigator.pushNamed(context, '/change_password'),
                  ),
                  const SizedBox(height: 10),
                  // Giao diện Sáng/Tối/Theo máy — mặc định Sáng.
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.instance,
                    builder: (_, mode, _) => ProfileMenuCard(
                      icon: Icons.brightness_6_outlined,
                      label: 'Giao diện',
                      subtitle: ThemeController.label(mode),
                      onTap: () => showThemeModeSheet(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ProfileMenuCard(
                    icon: Icons.logout,
                    label: 'Đăng xuất',
                    color: context.vd.danger,
                    onTap: onLogout,
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              children: [
                Text(
                  'Phần mềm Viendongedu phiên bản 1.1.43',
                  style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2),
                Text(
                  'Thuộc bản quyền Cao đẳng Viễn Đông',
                  style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
