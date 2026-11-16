import 'package:flutter/material.dart';
import '../../../theme/vd_tokens.dart';

/// Orange header of the detail page: back arrow, subject name, semester.
class ClassDetailHeader extends StatelessWidget {
  final String title;
  final String semTen;
  const ClassDetailHeader(
      {super.key, required this.title, required this.semTen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.vd.primary, context.vd.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios,
                color: context.vd.onPrimary, size: 20),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: context.vd.onPrimary)),
          const SizedBox(height: 4),
          Text(semTen,
              style: TextStyle(color: context.vd.onPrimary.withValues(alpha: 0.7), fontSize: 13)),
        ],
      ),
    );
  }
}
