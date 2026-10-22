import 'package:flutter/material.dart';

import '../services/crm_questions_api.dart';
import '../services/crm_session_guard.dart';
import '../services/ems_api_service.dart';
import '../services/offline_snapshot.dart';
import '../theme/vd_tokens.dart';

part 'widgets/student_questions_widgets.dart';

/// Student-to-school questions. Reads may use a clearly marked local copy;
/// messages remain drafts until the server confirms them.

class StudentQuestionsScreen extends StatefulWidget {
  const StudentQuestionsScreen({super.key});

  @override
  State<StudentQuestionsScreen> createState() => _StudentQuestionsScreenState();
}

class _StudentQuestionsScreenState extends State<StudentQuestionsScreen> {
  List<QuestionThread> _threads = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await CrmQuestionsApi.list();
      if (mounted) {
        setState(() {
          _threads = rows;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (mounted) {
        setState(() {
          _threads = const [];
          _error = 'Không có kết nối. Kiểm tra mạng rồi kéo xuống để thử lại.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hỏi nhà trường')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const _NewQuestionScreen()),
        );
        if (created == true) _load();
      },
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Đặt câu hỏi'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(
            'Câu hỏi được gửi đến Phòng Đào tạo, Kế toán, Khoa hoặc giảng viên phù hợp.',
            style: TextStyle(color: context.vd.inkMuted),
          ),
          const SizedBox(height: 12),
          if (_error != null) _Notice(_error!),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!_loading && _error == null && _threads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 52),
              child: Center(child: Text('Bạn chưa có câu hỏi nào.')),
            ),
          for (final thread in _threads)
            Card(
              child: ListTile(
                title: Text(
                  thread.subject,
                  maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  thread.preview.isEmpty
                      ? (thread.isClosed ? 'Đã đóng' : 'Đang chờ phản hồi')
                      : thread.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _QuestionThreadScreen(thread: thread),
                    ),
                  );
                  if (mounted) _load();
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class _QuestionThreadScreen extends StatefulWidget {
  const _QuestionThreadScreen({required this.thread});
  final QuestionThread thread;

  @override
  State<_QuestionThreadScreen> createState() => _QuestionThreadScreenState();
}

class _QuestionThreadScreenState extends State<_QuestionThreadScreen> {
  final _reply = TextEditingController();
  Future<void> _draftWrites = Future.value();
  QuestionDetail? _detail;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _load();
  }

  Future<void> _loadDraft() async {
    final value = await OfflineSnapshot.load(
      'question_reply_${widget.thread.id}',
    );
    if (value?.data is String && mounted && _reply.text.isEmpty) {
      _reply.text = value!.data as String;
    }
  }

  Future<void> _load() async {
    try {
      final detail = await CrmQuestionsApi.detail(widget.thread.id);
      if (mounted) {
        setState(() {
          _detail = detail;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (mounted) {
        setState(() {
          _detail = null;
          _error = 'Không có kết nối. Kéo xuống để tải phản hồi từ máy chủ.';
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await CrmQuestionsApi.sendMessage(widget.thread.id, text);
      _reply.clear();
      await _draftWrites;
      await OfflineSnapshot.save('question_reply_${widget.thread.id}', '');
      await _load();
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(
        () => _error =
            'Chưa xác nhận đã gửi. Kiểm tra cuộc trao đổi trước khi thử lại; bản nháp vẫn còn.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.subject ?? widget.thread.subject)),
      body: Column(
        children: [
          if (_error != null) _Notice(_error!),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (detail == null && _error == null)
                    const Center(child: CircularProgressIndicator()),
                  if (detail != null && detail.messages.isEmpty)
                    const Text('Chưa có tin nhắn.'),
                  for (final message
                      in detail?.messages ?? const <QuestionMessage>[])
                    Align(
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
                                    _shortDate(message.createdAt!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.vd.inkMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (detail != null && !detail.isClosed)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (text) {
                          _draftWrites = _draftWrites.then(
                            (_) => OfflineSnapshot.save(
                              'question_reply_${widget.thread.id}',
                              text,
                            ),
                          );
                        },
                        decoration: const InputDecoration(
                          hintText: 'Viết phản hồi…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Gửi phản hồi',
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
