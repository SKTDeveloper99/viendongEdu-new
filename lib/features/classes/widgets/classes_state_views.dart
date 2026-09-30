import 'package:flutter/material.dart';
import '../../../theme/vd_tokens.dart';

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
          Icon(Icons.error_outline, size: 48, color: context.vd.inkFaint),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: context.vd.inkMuted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: context.vd.primary),
            child: Text('Thử lại', style: TextStyle(color: context.vd.onPrimary)),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, size: 64, color: context.vd.inkFaint),
          SizedBox(height: 12),
          Text('Không có lớp học', style: TextStyle(color: context.vd.inkMuted)),
        ],
      ),
    );
  }
}
