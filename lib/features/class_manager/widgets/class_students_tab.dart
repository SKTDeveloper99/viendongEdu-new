import 'package:flutter/material.dart';

import '../class_detail_sheet_view_model.dart';
import 'class_manager_state_views.dart';

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
      return const Center(
        child: Text('Không có học viên', style: TextStyle(color: Colors.grey)),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 15,
                color: Color(0xFFE65100),
              ),
              const SizedBox(width: 6),
              Text(
                'Tổng: ${students.length} sinh viên',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
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
                const Divider(height: 1, color: Color(0xFFF5F5F5)),
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65100),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF555555),
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
