import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';

/// Shared building blocks of the teacher student view: large text and big
/// tap targets for teachers who are not used to apps.

/// Labelled back button ("← Quay lại …") above the screen title.
class CareBackHeader extends StatelessWidget {
  final String backLabel;
  final String title;
  final String? subtitle;
  const CareBackHeader({
    super.key,
    required this.backLabel,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(56, 56),
            foregroundColor: context.vd.ink,
            backgroundColor: context.vd.surface,
            side: BorderSide(color: context.vd.hairline, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(
            '← Quay lại $backLabel',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 17, color: context.vd.inkMuted),
          ),
        ],
      ],
    );
  }
}

enum CareTone { danger, warning, neutral, success }

class CarePill extends StatelessWidget {
  final String label;
  final CareTone tone;
  const CarePill(this.label, {super.key, required this.tone});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      CareTone.danger => (context.vd.danger, context.vd.dangerSoft),
      CareTone.warning => (context.vd.warning, context.vd.warningSoft),
      CareTone.success => (context.vd.success, context.vd.successSoft),
      CareTone.neutral => (context.vd.inkMuted, context.vd.surfaceAlt),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// A whole-width tappable row (at least 72 high) ending in a chevron.
class CareRow extends StatelessWidget {
  final String title;
  final String? meta;
  final List<Widget> pills;
  final VoidCallback onTap;
  const CareRow({
    super.key,
    required this.title,
    this.meta,
    this.pills = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.vd.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: context.vd.hairline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (meta != null)
                          Text(
                            meta!,
                            style: TextStyle(
                              fontSize: 16,
                              color: context.vd.inkMuted,
                            ),
                          ),
                        if (pills.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: pills),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 30,
                    color: context.vd.inkMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
