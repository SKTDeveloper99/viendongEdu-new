import 'package:flutter/material.dart';

import '../services/crm_questions_api.dart';
import '../theme/vd_tokens.dart';

/// One message in a Hỏi nhà trường thread: the student's on the right, the
/// school's on the left.
class QuestionMessageBubble extends StatelessWidget {
  final QuestionMessage message;
  const QuestionMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromStudent
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .83,
        ),
        child: Card(
          color: message.fromStudent
              ? context.vd.accentSoft
              : context.vd.surfaceAlt,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fromStudent ? 'Bạn' : 'Nhà trường',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message.body),
                if (message.createdAt != null)
                  Text(
                    questionDateText(message.createdAt!),
                    style: TextStyle(fontSize: 11, color: context.vd.inkMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `dd/MM/yyyy HH:mm` on the phone's clock.
String questionDateText(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}
