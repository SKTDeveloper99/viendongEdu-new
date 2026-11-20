import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';

/// Under an item's "Gửi" button: the upload's line while it goes ("Mạng
/// yếu, đang gửi lại (lần 2/3)…") and, after a network failure, "Gửi tiếp"
/// for the files not sent yet.
class PaperSendState extends StatelessWidget {
  final String code;
  final bool sending;
  final String? status;
  final int left;
  final VoidCallback? onResume;
  const PaperSendState({
    super.key,
    required this.code,
    required this.sending,
    required this.status,
    required this.left,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final line = status;
    if (sending && line != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          line,
          key: Key('paper-status-$code'),
          style: TextStyle(color: context.vd.inkMuted, fontSize: 13),
        ),
      );
    }
    if (sending || left <= 0) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: Key('paper-resume-$code'),
        onPressed: onResume,
        icon: const Icon(Icons.refresh),
        label: Text('Gửi tiếp $left tệp chưa gửi'),
      ),
    );
  }
}
