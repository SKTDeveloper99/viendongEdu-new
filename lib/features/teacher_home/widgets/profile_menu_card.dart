import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';

class ProfileMenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// Dòng phụ dưới nhãn (vd. lựa chọn hiện tại). Bỏ trống thì chỉ có nhãn.
  final String? subtitle;

  const ProfileMenuCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.vd.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.vd.hairline, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (color ?? context.vd.primary).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color ?? context.vd.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.vd.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.vd.inkFaint, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
