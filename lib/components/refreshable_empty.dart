import 'package:flutter/material.dart';

/// Keep normal pull-to-refresh available before the first record arrives.
class RefreshableEmpty extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const RefreshableEmpty({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 64),
      children: [child],
    ),
  );
}
