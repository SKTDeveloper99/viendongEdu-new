import 'package:flutter/material.dart';

import '../class_detail_sheet_view_model.dart';
import 'class_manager_state_views.dart';
import '../../../theme/vd_tokens.dart';

/// "Danh sách" tab: enrolled students of the class.
class ClassStudentsTab extends StatelessWidget {
  final ClassDetailSheetViewModel vm;
  const ClassStudentsTab({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.loadingStudents) return const SheetLoading();
    final error = vm.studentsError;
    if (error != null) {
      return SheetErrorView(message: error, onRetry: vm.loadStudents);
    }
    final students = vm.students;
    if (students.isEmpty) {
      return Center(
        child: Text('Không có học viên', style: TextStyle(color: context.vd.inkMuted)),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.people_outline,
                size: 15,
                color: context.vd.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Tổng: ${students.length} sinh viên',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.vd.primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: students.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: context.vd.hairline),
            itemBuilder: (_, i) {
              final hv = students[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(
                        0xFFE65100,
                      ).withValues(alpha: 0.1),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.vd.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hv.fullName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hv.mssv,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.vd.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
