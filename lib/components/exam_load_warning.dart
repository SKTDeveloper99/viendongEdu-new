import 'package:flutter/material.dart';

class ExamLoadWarning extends StatelessWidget {
  final VoidCallback onRetry;
  const ExamLoadWarning({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Chưa kiểm tra được lịch thi', textAlign: TextAlign.center),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}
