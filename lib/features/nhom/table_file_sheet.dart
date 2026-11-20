import 'package:flutter/material.dart';

import '../../services/ems_api_service.dart' show EmsException;
import '../../services/ems_upload.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../work/file_pick.dart';
import '../work/hand_in_sheet.dart' show PickedFile, PickFiles;
import '../work/open_attachment.dart';
import 'table_file_cell.dart';

/// The three ways to pick (tests replace them).
class CellPickers {
  final PickFiles camera;
  final PickFiles photos;
  final Future<List<PickedFile>> Function(List<String> extensions) files;
  const CellPickers({
    this.camera = takePhotoFile,
    this.photos = pickPhotoFilesForHandIn,
    this.files = pickFilesOfTypes,
  });
}

/// What may be sent of [picked] under [rules] with [already] files in the
/// cell, and a Vietnamese line for each one left out.
({List<PickedFile> ok, List<String> notes}) checkCellFiles(
  List<PickedFile> picked,
  CellFileRules rules,
  int already,
) {
  final ok = <PickedFile>[];
  final notes = <String>[];
  var room = rules.perCell - already;
  for (final f in picked) {
    if (!rules.takes(f.name)) {
      notes.add('${f.name}: ${rules.typeText}');
    } else if ((f.size ?? 0) > rules.fileBytes) {
      notes.add('${f.name}: ${rules.tooLargeText}');
    } else if (room <= 0) {
      notes.add('${f.name}: mỗi ô giữ tối đa ${rules.perCell} tệp.');
    } else {
      ok.add(f);
      room--;
    }
  }
  return (ok: ok, notes: notes);
}

/// "+": Chụp ảnh / Chọn ảnh / Chọn tệp, the checks above, then one upload with
/// a progress bar and, on a weak network, "Mạng yếu, đang gửi lại (lần 2/3)…".
/// True when the server took the files; a refusal shows the server's own
/// message.
Future<bool> addCellFiles(
  BuildContext context, {
  required CellFilesApi api,
  required CellFileRules rules,
  required int already,
  CellPickers pickers = const CellPickers(),
}) async {
  final which = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rules.takesPhotos) ...[
            ListTile(
              key: const ValueKey('cell-pick-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              key: const ValueKey('cell-pick-photo'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh'),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
          ],
          ListTile(
            key: const ValueKey('cell-pick-file'),
            leading: const Icon(Icons.description_outlined),
            title: const Text('Chọn tệp'),
            subtitle: Text(rules.typeText),
            onTap: () => Navigator.pop(ctx, 'file'),
          ),
        ],
      ),
    ),
  );
  if (which == null || !context.mounted) return false;
  List<PickedFile> picked;
  try {
    picked = await switch (which) {
      'camera' => pickers.camera(),
      'photo' => pickers.photos(),
      _ => pickers.files(rules.accept),
    };
  } catch (_) {
    if (context.mounted) {
      showErrorSnack(
        context,
        which == 'camera'
            ? 'Không mở được máy ảnh trên máy này.'
            : 'Không mở được nơi chọn tệp.',
      );
    }
    return false;
  }
  if (picked.isEmpty || !context.mounted) return false;
  final c = checkCellFiles(picked, rules, already);
  if (c.notes.isNotEmpty) showErrorSnack(context, c.notes.join('\n'));
  if (c.ok.isEmpty) return false;
  final progress = ValueNotifier<UploadStatus?>(null);
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<UploadStatus?>(
          valueListenable: progress,
          builder: (_, s, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Đang tải lên ${c.ok.length} tệp'
                '${s?.fraction == null ? '…' : ' · ${(s!.fraction! * 100).round()}%'}',
              ),
              if (s != null && s.resending)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(s.text, key: const ValueKey('cell-upload-retry')),
                ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                key: const ValueKey('cell-upload-progress'),
                value: s?.fraction,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final bytes = [
      for (final f in c.ok) (bytes: await f.read(), filename: f.name),
    ];
    await api.add(
      bytes,
      maxBytes: rules.fileBytes,
      onStatus: (s) => progress.value = s,
    );
    nav.pop();
    if (context.mounted) {
      showSuccessSnack(context, 'Đã thêm ${c.ok.length} tệp.');
    }
    return true;
  } catch (e) {
    nav.pop();
    if (context.mounted) {
      showErrorSnack(
        context,
        e is EmsException ? e.message : 'Không gửi được tệp. Thử lại.',
      );
    }
    return false;
  } finally {
    progress.dispose();
  }
}

/// Opens one cell file: a photo in the app, others in the phone's viewer.
Future<void> openCellFile(BuildContext context, CellFilesApi api, Map f) {
  final name = '${f['name'] ?? 'tep'}';
  final given = '${f['mime'] ?? ''}';
  return openServerFile(
    context,
    api.fileUrl('${f['id']}'),
    name: name,
    type: given.isEmpty ? EmsUpload.typeOf(name) : given,
    key: 'cell_${f['id']}',
  );
}

/// Tapping the cell: every file in it (open each, remove one after a
/// confirm when the server allows) and "Thêm tệp / ảnh". True when
/// something changed and the table should reload.
Future<bool> showCellFilesSheet(
  BuildContext context, {
  required String title,
  required List<Map<String, dynamic>> files,
  required CellFilesApi api,
  required CellFileRules rules,
  required bool canAdd,
  CellPickers pickers = const CellPickers(),
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final vd = ctx.vd;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '$title · ${files.length}/${rules.perCell} tệp',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            if (files.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Ô này chưa có tệp.',
                  style: TextStyle(color: vd.inkMuted),
                ),
              ),
            for (final f in files)
              ListTile(
                key: ValueKey('cell-sheet-file-${f['id']}'),
                leading: Icon(
                  '${f['mime']}'.startsWith('image/')
                      ? Icons.image_outlined
                      : Icons.description_outlined,
                ),
                title: Text(
                  '${f['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    _size(f['size']),
                    if (f['by'] != null) '${f['by']}',
                  ].join(' · '),
                ),
                onTap: () => openCellFile(ctx, api, f),
                trailing: f['can_remove'] == true
                    ? IconButton(
                        key: ValueKey('cell-remove-${f['id']}'),
                        tooltip: 'Gỡ tệp',
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          if (await _removeFile(ctx, api, f) && ctx.mounted) {
                            Navigator.pop(ctx, true);
                          }
                        },
                      )
                    : null,
              ),
            if (canAdd && files.length < rules.perCell)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  key: const ValueKey('cell-sheet-add'),
                  onPressed: () async {
                    final ok = await addCellFiles(
                      ctx,
                      api: api,
                      rules: rules,
                      already: files.length,
                      pickers: pickers,
                    );
                    if (ok && ctx.mounted) Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm tệp / ảnh'),
                ),
              ),
          ],
        ),
      );
    },
  );
  return changed == true;
}

Future<bool> _removeFile(BuildContext context, CellFilesApi api, Map f) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text('Gỡ tệp “${f['name'] ?? ''}” khỏi ô này?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Thôi'),
        ),
        FilledButton(
          key: const ValueKey('cell-remove-confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Gỡ'),
        ),
      ],
    ),
  );
  if (go != true) return false;
  try {
    await api.remove('${f['id']}');
    if (context.mounted) showSuccessSnack(context, 'Đã gỡ tệp.');
    return true;
  } catch (e) {
    if (context.mounted) {
      showErrorSnack(
        context,
        e is EmsException ? e.message : 'Không gỡ được tệp. Thử lại.',
      );
    }
    return false;
  }
}

String _size(Object? v) {
  final n = v is num ? v.toInt() : 0;
  if (n >= 1024 * 1024) return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(n / 1024).ceil()} KB';
}
