import 'package:flutter/material.dart';
import '../../../theme/vd_tokens.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.vd.accentSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(Icons.cloud_off, size: 18, color: context.vd.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
