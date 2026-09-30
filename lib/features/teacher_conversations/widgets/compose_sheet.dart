import 'package:flutter/material.dart';

import '../../../models/teacher_conversation_models.dart';
import '../../../theme/vd_tokens.dart';

/// Bottom sheet for the first message of a new thread. [onSend] returns an
/// error message (shown inline, text kept) or null when the thread was
/// created — then the sheet closes.
class ComposeSheet extends StatefulWidget {
  final PickerStudent student;
  final Future<String?> Function(String subject, String message) onSend;
  const ComposeSheet({super.key, required this.student, required this.onSend});

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _message.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.onSend(_subject.text, _message.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _sending = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.student.name} · ${widget.student.mssv}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subject,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Chủ đề (không bắt buộc)',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _message,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Nội dung tin nhắn',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: context.vd.danger)),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            child: Text(_sending ? 'Đang gửi…' : 'Gửi'),
          ),
        ),
      ],
    ),
  );
}
