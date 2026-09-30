import 'package:flutter/material.dart';
import '../../../theme/vd_tokens.dart';

/// Orange header band: back arrow, title and the three tabs.
class GradesHeader extends StatelessWidget {
  final TabController controller;
  const GradesHeader({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
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
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back_ios,
                    color: context.vd.onPrimary, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Bảng điểm',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.vd.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TabBar(
            controller: controller,
            indicatorColor: context.vd.onPrimary,
            indicatorWeight: 3,
            labelColor: context.vd.onPrimary,
            unselectedLabelColor: context.vd.onPrimary.withValues(alpha: 0.6),
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            labelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Tổng quan'),
              Tab(text: 'Chi tiết'),
              Tab(text: 'Môn học'),
            ],
          ),
        ],
      ),
    );
  }
}
