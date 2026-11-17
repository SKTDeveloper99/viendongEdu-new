import 'package:flutter/material.dart';
import '../../theme/vd_tokens.dart';
import '../crm_web/android_photo_picker.dart' show pickPhotosForHandIn;

/// THE SWITCH for attachments on a hand-in (owner 2026-11-17: any type of
/// file or drop it). Off: the app can upload any file, but a giver cannot yet
/// open a PDF or Word file from the piece screen on Android without a second
/// package (open_filex) or native code, so no photo-only half version ships.
/// The code stays; true (or --dart-define=HAND_IN_ATTACH=true) shows it.
const bool handInAttachEnabled = bool.fromEnvironment(
  'HAND_IN_ATTACH',
  defaultValue: false,
);

/// One picked file: where it is on the phone and its name.
typedef PickedFile = ({String path, String name});

/// What the person hands in: a note and the photos picked ("Đính kèm").
class HandInResult {
  final String note;
  final List<PickedFile> files;
  const HandInResult(this.note, this.files);
}

/// Picks photos for a hand-in; tests replace it.
typedef PickPhotos = Future<List<PickedFile>> Function();

/// The hand-in sheet: a note (optional) and "Đính kèm ảnh"; files go to the
/// server the way the web sends them (WorkApi.attach) before the hand-in.
Future<HandInResult?> showHandInSheet(
  BuildContext context, {
  PickPhotos pick = pickPhotosForHandIn,
  bool attach = handInAttachEnabled,
}) => showModalBottomSheet<HandInResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => HandInSheet(pick: pick, attach: attach),
);

class HandInSheet extends StatefulWidget {
  final PickPhotos pick;
  final bool attach;
  const HandInSheet({super.key, required this.pick, this.attach = false});

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
    try {
      final picked = await widget.pick();
      if (mounted && picked.isNotEmpty) setState(() => _files.addAll(picked));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Không mở được thư viện ảnh.')),
      );
    }
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
              leading: Icon(Icons.image_outlined, color: t.inkMuted),
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
              label: Text(
                _files.isEmpty ? 'Đính kèm ảnh' : 'Đính kèm thêm ảnh',
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('handin-send'),
            onPressed: () => Navigator.pop(
              context,
              HandInResult(_note.text.trim(), List.of(_files)),
            ),
            child: Text(
              _files.isEmpty ? 'Nộp' : 'Nộp kèm ${_files.length} ảnh',
            ),
          ),
        ],
      ),
    );
  }
}
