import 'package:flutter/material.dart';

import '../../../models/teacher_conversation_models.dart';
import '../../../theme/vd_tokens.dart';
import '../conversation_format.dart';

/// Student messages sit left, the teacher's own right.
class MessageBubble extends StatelessWidget {
  final TeacherMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final mine = !message.fromStudent;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine ? vd.primary : vd.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message.body,
                  style: TextStyle(color: mine ? vd.onPrimary : vd.ink),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                conversationTime(message.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: mine ? vd.onPrimary : vd.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
