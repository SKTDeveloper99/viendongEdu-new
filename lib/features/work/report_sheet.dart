import 'package:flutter/material.dart';

import '../../theme/vd_tokens.dart';
import 'file_pick.dart';
import 'hand_in_sheet.dart';
import 'work_api.dart';

/// What the person wrote, kept while the app runs: a 200-word duty report is
/// not lost when the sheet is closed by mistake or the sending fails.
final Map<String, String> _drafts = {};

/// Forgets the kept text of [assignmentId] (after it was handed in).
void forgetReportDraft(String assignmentId) => _drafts.remove(assignmentId);

/// The report sheet for a piece with minimums (duty reports): a long text with
/// its word count against [rule].minWords, and photos against
/// [rule].minPhotos..photoCap. [photosOnPart] already on the part count toward
/// the minimum, as on the server. Returns the text and the photos picked.
Future<HandInResult?> showReportSheet(
  BuildContext context, {
  required String assignmentId,
  required ReportRule rule,
  int photosOnPart = 0,
  PickFiles pickPhotos = pickPhotoFilesForHandIn,
  PickFiles? pickFiles,
}) => showModalBottomSheet<HandInResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => ReportSheet(
    assignmentId: assignmentId,
    rule: rule,
    photosOnPart: photosOnPart,
    pickPhotos: pickPhotos,
    pickFiles: pickFiles,
  ),
);

class ReportSheet extends StatefulWidget {
  final String assignmentId;
  final ReportRule rule;
  final int photosOnPart;
  final PickFiles pickPhotos;

  /// Any file besides photos (ordinary pieces with a minimum); null = photos
  /// only (a report takes images only).
  final PickFiles? pickFiles;
  const ReportSheet({
    super.key,
    required this.assignmentId,
    required this.rule,
    required this.pickPhotos,
    this.photosOnPart = 0,
    this.pickFiles,
  });

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  late final _text = TextEditingController(
    text: _drafts[widget.assignmentId] ?? '',
  );
  final _files = <PickedFile>[];

  @override
  void initState() {
    super.initState();
    _text.addListener(() => _drafts[widget.assignmentId] = _text.text);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool _isPhoto(String name) => RegExp(
    r'\.(jpe?g|png|webp|heic|heif)$',
    caseSensitive: false,
  ).hasMatch(name);

  int get _photos =>
      widget.photosOnPart + _files.where((f) => _isPhoto(f.name)).length;

  int get _picked => _files.where((f) => _isPhoto(f.name)).length;

  Future<void> _add() async {
    final more = widget.pickFiles == null
        ? await widget.pickPhotos()
        : await pickAttachments(
            context,
            pickPhotos: widget.pickPhotos,
            pickFiles: widget.pickFiles!,
          );
    if (!mounted || more.isEmpty) return;
    setState(() => _files.addAll(more));
  }

  /// What still keeps the button off, in one line; null when it may go.
  String? _missing(int words) {
    final r = widget.rule;
    final parts = <String>[
      if (words < r.minWords) 'còn thiếu ${r.minWords - words} từ',
      if (_photos < r.minPhotos) 'cần thêm ${r.minPhotos - _photos} ảnh',
      if (_picked > r.photoCap) 'tối đa ${r.photoCap} ảnh một lần nộp',
      if (r.minFiles > 0 && widget.photosOnPart + _files.length < r.minFiles)
        'cần ít nhất ${r.minFiles} tệp',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    final r = widget.rule;
    final pad = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, pad.viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              r.isReport ? 'Nộp báo cáo' : 'Nộp phần việc',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (r.minWords > 0) 'Ít nhất ${r.minWords} từ',
                if (r.minPhotos > 0)
                  'từ ${r.minPhotos} đến ${r.photoCap} ảnh'
                else if (r.isReport)
                  'tối đa ${r.photoCap} ảnh',
              ].join(', '),
              style: TextStyle(color: t.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('report-text'),
              controller: _text,
              minLines: 6,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Nội dung báo cáo',
                border: OutlineInputBorder(),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (_, v, _) {
                final n = wordCount(v.text);
                final ok = n >= r.minWords;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    r.minWords > 0 ? '$n/${r.minWords} từ' : '$n từ',
                    key: const ValueKey('report-words'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: ok ? t.success : t.inkMuted,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              widget.photosOnPart > 0
                  ? 'Ảnh: $_photos (đã có ${widget.photosOnPart} ảnh gửi trước)'
                  : 'Ảnh: $_photos',
              style: TextStyle(color: t.ink, fontWeight: FontWeight.w600),
            ),
            for (var i = 0; i < _files.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _isPhoto(_files[i].name)
                      ? Icons.image_outlined
                      : Icons.attach_file,
                  color: t.inkMuted,
                ),
                title: Text(
                  _files[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Bỏ tệp này',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _files.removeAt(i)),
                ),
              ),
            OutlinedButton.icon(
              key: const ValueKey('report-add-photo'),
              onPressed: _add,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                widget.pickFiles == null ? 'Thêm ảnh' : 'Đính kèm ảnh hoặc tệp',
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (_, v, _) {
                final missing = _missing(wordCount(v.text));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (missing != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Chưa nộp được: $missing.',
                          key: const ValueKey('report-missing'),
                          style: TextStyle(color: t.warning, fontSize: 13),
                        ),
                      ),
                    FilledButton(
                      key: const ValueKey('report-send'),
                      onPressed: missing != null
                          ? null
                          : () => Navigator.pop(
                              context,
                              HandInResult(v.text.trim(), List.of(_files)),
                            ),
                      child: Text(
                        _files.isEmpty ? 'Nộp' : 'Nộp kèm ${_files.length} tệp',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
