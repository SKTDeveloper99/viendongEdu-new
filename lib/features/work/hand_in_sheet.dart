import 'package:flutter/material.dart';

import '../../services/ems_upload.dart';
import '../../theme/vd_tokens.dart';
import 'file_pick.dart';

/// THE SWITCH for attachments on a hand-in (owner 2026-11-17: "any type of
/// files"). On: "Đính kèm" offers Ảnh (photo picker) and Tệp (any file);
/// files go up with the person's session and open from the piece screen.
/// false (or --dart-define=HAND_IN_ATTACH=false) hides it again.
const bool handInAttachEnabled = bool.fromEnvironment(
  'HAND_IN_ATTACH',
  defaultValue: true,
);

/// One picked file: its name and a way to read its bytes (a photo path on
/// iOS, a content URI on Android).
typedef PickedFile = ({
  String name,
  int? size,
  Future<List<int>> Function() read,
});

/// What the person hands in: a note and the files picked ("Đính kèm").
class HandInResult {
  final String note;
  final List<PickedFile> files;
  const HandInResult(this.note, this.files);
}

/// Picks files for a hand-in; tests replace it.
typedef PickFiles = Future<List<PickedFile>> Function();

/// The hand-in sheet: a note (optional) and "Đính kèm" (Ảnh or Tệp); files go
/// to the server the way the web sends them (WorkApi.attach) before the
/// hand-in.
Future<HandInResult?> showHandInSheet(
  BuildContext context, {
  PickFiles pickPhotos = pickPhotoFilesForHandIn,
  PickFiles pickFiles = pickFilesForHandIn,
  PickFiles takePhoto = takePhotoFile,
  bool attach = handInAttachEnabled,
}) => showModalBottomSheet<HandInResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => HandInSheet(
    pickPhotos: pickPhotos,
    pickFiles: pickFiles,
    takePhoto: takePhoto,
    attach: attach,
  ),
);

class HandInSheet extends StatefulWidget {
  final PickFiles pickPhotos;
  final PickFiles pickFiles;
  final PickFiles takePhoto;
  final bool attach;
  const HandInSheet({
    super.key,
    required this.pickPhotos,
    required this.pickFiles,
    this.takePhoto = takePhotoFile,
    this.attach = false,
  });

  @override
  State<HandInSheet> createState() => _HandInSheetState();
}

class _HandInSheetState extends State<HandInSheet> {
  final _note = TextEditingController();
  final _files = <PickedFile>[];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final ok = await pickAttachments(
      context,
      pickPhotos: widget.pickPhotos,
      pickFiles: widget.pickFiles,
      takePhoto: widget.takePhoto,
    );
    if (mounted && ok.isNotEmpty) setState(() => _files.addAll(ok));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    final pad = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        pad.viewInsets.bottom + pad.padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nộp phần việc', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Ghi chú khi nộp',
              border: OutlineInputBorder(),
            ),
          ),
          for (var i = 0; i < _files.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.attach_file, color: t.inkMuted),
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
          if (widget.attach)
            OutlinedButton.icon(
              key: const ValueKey('handin-attach'),
              onPressed: _attach,
              icon: const Icon(Icons.attach_file),
              label: Text(_files.isEmpty ? 'Đính kèm' : 'Đính kèm thêm'),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('handin-send'),
            onPressed: () => Navigator.pop(
              context,
              HandInResult(_note.text.trim(), List.of(_files)),
            ),
            child: Text(
              _files.isEmpty ? 'Nộp' : 'Nộp kèm ${_files.length} tệp',
            ),
          ),
        ],
      ),
    );
  }
}

/// "Đính kèm": asks Chụp ảnh, Chọn ảnh or Chọn tệp, opens that one and
/// returns what may be sent. [pickFiles] null = photos only (a report).
/// [takePhoto] null hides "Chụp ảnh". The size is checked here, before
/// anything is read into memory: a file over the server's 25 MB ceiling is
/// refused at once with its message. Used by the hand-in sheet, the report
/// sheet and Giao việc.
Future<List<PickedFile>> pickAttachments(
  BuildContext context, {
  PickFiles pickPhotos = pickPhotoFilesForHandIn,
  PickFiles? pickFiles = pickFilesForHandIn,
  PickFiles? takePhoto = takePhotoFile,
}) async {
  final which = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (takePhoto != null)
            ListTile(
              key: const ValueKey('attach-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ListTile(
            key: const ValueKey('attach-photo'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Chọn ảnh'),
            onTap: () => Navigator.pop(ctx, 'photo'),
          ),
          if (pickFiles != null)
            ListTile(
              key: const ValueKey('attach-file'),
              leading: const Icon(Icons.description_outlined),
              title: const Text('Chọn tệp (PDF, Word, Excel…)'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
        ],
      ),
    ),
  );
  if (which == null) return const [];
  try {
    final picked = await switch (which) {
      'camera' => takePhoto!(),
      'photo' => pickPhotos(),
      _ => pickFiles!(),
    };
    final big = picked
        .where((f) => (f.size ?? 0) > EmsUpload.maxFileBytes)
        .toList();
    if (big.isNotEmpty && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            '${EmsUpload.refusal('file_too_large', 413)} '
            '${big.map((f) => f.name).join(', ')}',
          ),
        ),
      );
    }
    return picked.where((f) => !big.contains(f)).toList();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            which == 'camera'
                ? 'Không mở được máy ảnh trên máy này.'
                : 'Không mở được nơi chọn tệp.',
          ),
        ),
      );
    }
    return const [];
  }
}
