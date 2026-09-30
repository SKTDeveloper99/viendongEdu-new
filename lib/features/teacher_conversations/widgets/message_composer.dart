import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';

/// Text box + send button. Clears the draft only when [onSend] reports
/// success (returns true), so a failed send never loses the text.
class MessageComposer extends StatefulWidget {
  final bool sending;
  final Future<bool> Function(String text) onSend;
  const MessageComposer({
    super.key,
    required this.sending,
    required this.onSend,
  });

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (widget.sending || _text.text.trim().isEmpty) return;
    if (await widget.onSend(_text.text)) _text.clear();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Nhập tin nhắn',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Gửi',
            onPressed: widget.sending ? null : _send,
            style: IconButton.styleFrom(backgroundColor: context.vd.primary),
            icon: widget.sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.send, color: context.vd.onPrimary),
          ),
        ],
      ),
    ),
  );
}
