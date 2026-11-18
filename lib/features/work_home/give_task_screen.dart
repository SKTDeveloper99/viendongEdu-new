import 'package:flutter/material.dart';

import '../../services/ems_api_service.dart' show EmsException;
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../nhom/small_group_screens.dart';
import '../work/file_pick.dart';
import '../work/hand_in_sheet.dart';
import '../work/piece_screen.dart';
import '../work/work_api.dart';

/// "+ Giao việc": a new piece of work to one or more people, with files.
///
/// The piece is made first (one `client_request_id` per form, so a resend is
/// answered once), then each file goes up on the piece the way the web sends
/// it. A file that fails keeps the form open: "Gửi lại tệp" sends only the
/// files not yet on the piece, never a second piece.
class GiveTaskScreen extends StatefulWidget {
  final PickFiles? pickPhotos;
  final PickFiles? pickFiles;

  /// People already chosen (user id → name), e.g. from a person's page.
  final Map<String, String> people;
  const GiveTaskScreen({
    super.key,
    this.pickPhotos,
    this.pickFiles,
    this.people = const {},
  });

  @override
  State<GiveTaskScreen> createState() => _GiveTaskScreenState();
}

class _GiveTaskScreenState extends State<GiveTaskScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  late Map<String, String> _people = {...widget.people};
  DateTime? _due;
  bool _busy = false;
  final _requestId = newRequestId(); // same id on a resend: made once
  final _files = <PickedFile>[];
  final _sent = <PickedFile>{};
  String? _taskId; // set once the piece exists

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      _taskId ??= await _create();
      for (final f in _files) {
        if (_sent.contains(f)) continue;
        await WorkApi.attachToPiece(_taskId!, await f.read(), filename: f.name);
        _sent.add(f);
      }
      if (!mounted) return;
      showSuccessSnack(context, 'Đã giao việc cho ${_people.length} người.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PieceScreen(taskId: _taskId!)),
      );
    } on EmsException catch (e) {
      if (!mounted) return;
      showErrorSnack(
        context,
        _taskId == null
            ? e.message
            : 'Đã giao việc, nhưng chưa gửi được tệp: ${e.message}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _create() => WorkApi.give(
    title: _title.text.trim(),
    description: _desc.text.trim(),
    due: _due,
    people: _people.keys.toList(),
    requestId: _requestId,
  );

  Future<void> _attach() async {
    final picked = await pickAttachments(
      context,
      pickPhotos: widget.pickPhotos ?? pickPhotoFilesForHandIn,
      pickFiles: widget.pickFiles ?? pickFilesForHandIn,
    );
    if (mounted && picked.isNotEmpty) setState(() => _files.addAll(picked));
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final created = _taskId != null;
    final ok = _people.isNotEmpty && _title.text.trim().isNotEmpty && !_busy;
    final left = _files.where((f) => !_sent.contains(f)).length;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Giao việc')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            enabled: !created,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Việc cần làm',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            enabled: !created,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mô tả (không bắt buộc)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: created
                ? null
                : () async {
                    final r = await Navigator.push<Map<String, String>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PeoplePicker(title: 'Giao cho ai?'),
                      ),
                    );
                    if (r != null) setState(() => _people = {..._people, ...r});
                  },
            icon: const Icon(Icons.person_add_alt),
            label: Text(
              _people.isEmpty ? 'Chọn người nhận' : _people.values.join(', '),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: created ? null : _pickDue,
            icon: const Icon(Icons.event),
            label: Text(
              _due == null ? 'Chọn hạn' : dueLabel(_due!.toIso8601String()),
            ),
          ),
          const SizedBox(height: 12),
          for (final f in _files)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _sent.contains(f) ? Icons.check_circle : Icons.attach_file,
                color: _sent.contains(f) ? vd.success : vd.inkMuted,
              ),
              title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: _sent.contains(f) || _busy
                  ? null
                  : IconButton(
                      tooltip: 'Bỏ tệp này',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _files.remove(f)),
                    ),
            ),
          OutlinedButton.icon(
            key: const ValueKey('give-attach'),
            onPressed: _busy ? null : _attach,
            icon: const Icon(Icons.attach_file),
            label: Text(_files.isEmpty ? 'Đính kèm tệp' : 'Đính kèm thêm'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('give-send'),
            onPressed: ok ? _send : null,
            child: Text(
              _busy
                  ? 'Đang giao…'
                  : created
                  ? 'Gửi lại $left tệp chưa gửi'
                  : _files.isEmpty
                  ? 'Giao việc'
                  : 'Giao việc kèm ${_files.length} tệp',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 2)),
    );
    if (d != null) setState(() => _due = DateTime(d.year, d.month, d.day, 17));
  }
}
