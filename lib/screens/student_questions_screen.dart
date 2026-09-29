import 'package:flutter/material.dart';

import '../services/crm_questions_api.dart';
import '../services/crm_session_guard.dart';
import '../services/ems_api_service.dart';
import '../services/offline_snapshot.dart';
import '../theme/vd_theme.dart';

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
          const Text(
            'Câu hỏi được gửi đến Phòng Đào tạo, Kế toán, Khoa hoặc giảng viên phù hợp.',
            style: TextStyle(color: VdColors.ink60),
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
                              ? VdColors.orangeTint
                              : VdColors.paper,
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
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: VdColors.ink60,
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

class _NewQuestionScreen extends StatefulWidget {
  const _NewQuestionScreen();
  @override
  State<_NewQuestionScreen> createState() => _NewQuestionScreenState();
}

class _NewQuestionScreenState extends State<_NewQuestionScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  List<QuestionTarget> _targets = const [];
  String _target = 'pdt';
  String? _teacher;
  bool _sending = false;
  bool _sent = false;
  String? _error;
  Future<void> _draftWrites = Future.value();

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _loadTargets();
  }

  Future<void> _restoreDraft() async {
    final value = await OfflineSnapshot.load('new_question_draft');
    final data = value?.data;
    if (data is! Map<String, dynamic> ||
        !mounted ||
        _subject.text.isNotEmpty ||
        _message.text.isNotEmpty) {
      return;
    }
    _subject.text = data['subject']?.toString() ?? '';
    _message.text = data['message']?.toString() ?? '';
    setState(() {
      _target = data['target']?.toString() ?? 'pdt';
      _teacher = data['teacher']?.toString();
      if (_targets.isNotEmpty && !_targets.any((t) => t.type == _target)) {
        _target = _targets.first.type;
        _teacher = null;
      }
    });
  }

  Future<void> _loadTargets() async {
    try {
      final targets = await CrmQuestionsApi.targets();
      if (mounted) {
        setState(() {
          _targets = targets.where((t) => t.available).toList();
          if (_targets.isNotEmpty && !_targets.any((t) => t.type == _target)) {
            _target = _targets.first.type;
            _teacher = null;
          }
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (mounted) {
        setState(
          () => _error =
              'Không tải được nơi nhận. Bạn có thể viết nháp và thử lại khi có mạng.',
        );
      }
    }
  }

  void _saveDraft() {
    final draft = {
      'subject': _subject.text,
      'message': _message.text,
      'target': _target,
      'teacher': _teacher,
    };
    _draftWrites = _draftWrites.then(
      (_) => OfflineSnapshot.save('new_question_draft', draft),
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_targets.isEmpty || !_targets.any((t) => t.type == _target)) {
      setState(() => _error = 'Hãy kết nối để tải nơi nhận trước khi gửi.');
      return;
    }
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Hãy viết nội dung câu hỏi.');
      return;
    }
    if (_target == 'teacher' && (_teacher == null || _teacher!.isEmpty)) {
      setState(() => _error = 'Hãy chọn giảng viên.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await CrmQuestionsApi.create(
        subject: _subject.text,
        message: _message.text,
        targetType: _target,
        teacherId: _teacher,
      );
      await _draftWrites;
      await OfflineSnapshot.save('new_question_draft', <String, dynamic>{});
      _sent = true;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(
        () => _error = e is EmsException && e.statusCode != null
            ? e.message
            : 'Chưa xác nhận đã gửi. Kiểm tra danh sách trước khi thử lại; bản nháp vẫn còn.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    if (!_sent) _saveDraft();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets.isEmpty
        ? const [
            QuestionTarget(
              type: 'pdt',
              label: 'Phòng Đào tạo',
              available: true,
            ),
          ]
        : _targets;
    final selectedTarget = targets.any((t) => t.type == _target)
        ? _target
        : targets.first.type;
    final teachers = targets
        .where((t) => t.type == 'teacher')
        .expand((t) => t.teachers)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt câu hỏi')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Gửi đúng nơi để được trả lời nhanh hơn.',
            style: TextStyle(color: VdColors.ink60),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: ValueKey('target-$selectedTarget-${targets.length}'),
            initialValue: selectedTarget,
            decoration: const InputDecoration(
              labelText: 'Gửi đến',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final target in targets)
                DropdownMenuItem(
                  value: target.type,
                  child: Text(target.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _target = value;
                  _teacher = null;
                  _saveDraft();
                });
              }
            },
          ),
          if (selectedTarget == 'teacher') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('teacher-$_teacher-${teachers.length}'),
              initialValue: teachers.any((t) => t.id == _teacher)
                  ? _teacher
                  : null,
              decoration: const InputDecoration(
                labelText: 'Giảng viên',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final teacher in teachers)
                  DropdownMenuItem(
                    value: teacher.id,
                    child: Text(
                      '${teacher.name}${teacher.subject == null ? '' : ' · ${teacher.subject}'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                _teacher = value;
                _saveDraft();
              }),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            onChanged: (_) => _saveDraft(),
            decoration: const InputDecoration(
              labelText: 'Chủ đề',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            onChanged: (_) => _saveDraft(),
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Nội dung câu hỏi',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) _Notice(_error!),
          if (_targets.isEmpty)
            OutlinedButton.icon(
              onPressed: _loadTargets,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại nơi nhận'),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _sending || _targets.isEmpty ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(_sending ? 'Đang gửi…' : 'Gửi câu hỏi'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bản nháp được giữ trên máy nếu mất mạng. Chỉ khi nhà trường xác nhận, câu hỏi mới được xem là đã gửi.',
            style: TextStyle(fontSize: 12, color: VdColors.ink60),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: VdColors.orangeTint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: const TextStyle(color: VdColors.espresso)),
  );
}

String _shortDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
