part of '../student_questions_screen.dart';

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
          Text(
            'Gửi đúng nơi để được trả lời nhanh hơn.',
            style: TextStyle(color: context.vd.inkMuted),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            isExpanded: true,
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
              isExpanded: true,
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
          Text(
            'Bản nháp được giữ trên máy nếu mất mạng. Chỉ khi nhà trường xác nhận, câu hỏi mới được xem là đã gửi.',
            style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
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
      color: context.vd.accentSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: TextStyle(color: context.vd.ink)),
  );
}

String _shortDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
