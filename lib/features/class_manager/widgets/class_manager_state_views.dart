import 'package:flutter/material.dart';
import '../../../theme/vd_tokens.dart';

/// Full-area error with a retry button (list level).
class ClassManagerErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ClassManagerErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.vd.inkFaint),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: context.vd.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.vd.primary,
            ),
            child: Text('Thử lại', style: TextStyle(color: context.vd.onPrimary)),
          ),
        ],
      ),
    );
  }
}

class ClassManagerEmptyView extends StatelessWidget {
  const ClassManagerEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_accounts_outlined, size: 64, color: context.vd.inkFaint),
          SizedBox(height: 12),
          Text('Không có lớp', style: TextStyle(color: context.vd.inkMuted)),
        ],
      ),
    );
  }
}

/// Compact error with a small retry button, used inside the bottom sheets.
class SheetErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const SheetErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: context.vd.inkFaint),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: context.vd.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Thử lại',
              style: TextStyle(color: context.vd.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class SheetLoading extends StatelessWidget {
  const SheetLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: context.vd.primary),
    );
  }
}

/// White rounded sheet body with the grab handle on top.
class SheetFrame extends StatelessWidget {
  final List<Widget> children;
  const SheetFrame({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.vd.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
