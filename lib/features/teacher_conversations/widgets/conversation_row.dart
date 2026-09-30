import 'package:flutter/material.dart';

import '../../../models/teacher_conversation_models.dart';
import '../../../theme/vd_tokens.dart';
import '../conversation_format.dart';

/// One inbox row: student name + MSSV, subject, last message, time and an
/// unread dot while the ball is in the teacher's court.
class ConversationRow extends StatelessWidget {
  final TeacherConversation conversation;
  final VoidCallback onTap;
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final c = conversation;
    final name = c.studentName.isEmpty ? 'Sinh viên' : c.studentName;
    final unread = c.awaitingReply && !c.isClosed;
    final preview = c.preview.isEmpty
        ? ''
        : (c.lastFromStudent ? c.preview : 'Bạn: ${c.preview}');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 14,
                child: unread
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          key: const ValueKey('unread-dot'),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: vd.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name · ${c.studentMssv}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                        color: vd.ink,
                      ),
                    ),
                    if (c.subject.isNotEmpty)
                      Text(
                        c.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: vd.inkMuted, fontSize: 13),
                      ),
                    if (preview.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: vd.inkFaint, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                conversationTime(c.updatedAt),
                style: TextStyle(color: vd.inkFaint, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
