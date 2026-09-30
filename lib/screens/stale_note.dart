import 'package:flutter/material.dart';
import '../theme/vd_tokens.dart';

/// Small grey line shown when a screen displays stored data because the
/// refresh failed.
class StaleNote extends StatelessWidget {
  final DateTime savedAt;
  const StaleNote(this.savedAt, {super.key});

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final t = savedAt.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Chưa cập nhật được — dữ liệu lúc ${_two(t.hour)}:${_two(t.minute)} ${_two(t.day)}/${_two(t.month)}',
        style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
      ),
    );
  }
}
