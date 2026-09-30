import 'package:flutter/material.dart';

import '../../../components/skeleton.dart';
import '../../../models/teacher_conversation_models.dart';
import '../../../screens/stale_note.dart';
import '../../../theme/vd_tokens.dart';
import '../conversation_inbox_view_model.dart';
import 'conversation_row.dart';

/// Body of one inbox tab: pull to refresh, stale note, error, empty state.
class InboxList extends StatelessWidget {
  final InboxTab tab;
  final Future<void> Function() onRefresh;
  final void Function(TeacherConversation) onOpen;
  const InboxList({
    super.key,
    required this.tab,
    required this.onRefresh,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final rows = tab.rows;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (tab.staleAt != null) StaleNote(tab.staleAt!),
          if (tab.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(tab.error!, style: TextStyle(color: vd.danger)),
            ),
          if (tab.loading && rows.isEmpty)
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Skeleton(height: 72, radius: 12),
              ),
          if (!tab.loading && rows.isEmpty && tab.error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: Text(
                  'Chưa có tin nhắn',
                  style: TextStyle(color: vd.inkMuted),
                ),
              ),
            ),
          for (final c in rows)
            ConversationRow(conversation: c, onTap: () => onOpen(c)),
        ],
      ),
    );
  }
}
