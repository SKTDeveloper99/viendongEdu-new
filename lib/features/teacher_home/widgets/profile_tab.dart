import 'package:flutter/material.dart';

import '../../../theme/vd_theme.dart';
import 'profile_menu_card.dart';

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
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [VdColors.headerTop, VdColors.headerBottom],
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
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
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
                  ProfileMenuCard(
                    icon: Icons.logout,
                    label: 'Đăng xuất',
                    color: const Color(0xFFF44336),
                    onTap: onLogout,
                  ),
                ],
              ),
            ),
          ),

          // Footer
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              children: [
                Text(
                  'Phần mềm Viendongedu phiên bản 1.1.43',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2),
                Text(
                  'Thuộc bản quyền Cao đẳng Viễn Đông',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
