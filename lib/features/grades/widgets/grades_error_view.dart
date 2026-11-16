import 'package:flutter/material.dart';
import '../../../theme/vd_tokens.dart';

/// Error state with a retry button.
class GradesErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const GradesErrorView(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.vd.inkFaint),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: context.vd.inkMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: context.vd.primary),
            child:
                Text('Thử lại', style: TextStyle(color: context.vd.onPrimary)),
          ),
        ],
      ),
    );
  }
}
