import 'package:flutter/material.dart';

/// Error state of the classes list: message and "Thử lại".
class ClassesErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ClassesErrorView(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100)),
            child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Empty state: no classes in the selected semester.
class ClassesEmptyView extends StatelessWidget {
  const ClassesEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Không có lớp học', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
