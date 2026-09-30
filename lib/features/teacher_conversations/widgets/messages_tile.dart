import 'package:flutter/material.dart';

import '../../../components/menu_item.dart';
import '../../../data/api/teacher_conversations_api.dart';
import '../../../theme/vd_tokens.dart';

/// "Tin nhắn" tile of the teacher home, with the unread-thread count.
/// The count is re-read when the teacher comes back from the inbox; a
/// failed read just hides the badge (the inbox itself shows real errors).
class MessagesTile extends StatefulWidget {
  const MessagesTile({super.key, required this.index, this.loadCount});

  final int index;

  /// Tests may inject the counter; the app uses the CRM endpoint.
  final Future<int> Function()? loadCount;

  @override
  State<MessagesTile> createState() => _MessagesTileState();
}

class _MessagesTileState extends State<MessagesTile> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final n =
          await (widget.loadCount ?? TeacherConversationsApi.unreadCount)();
      if (mounted) setState(() => _unread = n);
    } catch (_) {}
  }

  Future<void> _open() async {
    await Navigator.pushNamed(context, '/teacher_conversations');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: MenuItemWidget(
            index: widget.index,
            icon: Icons.chat_bubble_outline,
            label: 'Tin nhắn',
            onTap: _open,
          ),
        ),
        if (_unread > 0)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: t.danger,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                style: TextStyle(
                  fontSize: 11,
                  color: t.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
