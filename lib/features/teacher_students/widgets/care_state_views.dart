import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';

class CareLoadingView extends StatelessWidget {
  const CareLoadingView({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(child: CircularProgressIndicator(color: context.vd.primary)),
  );
}

class CareMessageView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const CareMessageView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: context.vd.inkMuted),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, 56),
              backgroundColor: context.vd.primary,
            ),
            child: const Text('Thử lại', style: TextStyle(fontSize: 18)),
          ),
        ],
      ],
    ),
  );
}
