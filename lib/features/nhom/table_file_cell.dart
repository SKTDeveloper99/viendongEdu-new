import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/ems_api_service.dart';
import '../../services/ems_upload.dart';
import '../../theme/vd_tokens.dart';

/// What a "Tệp / ảnh" cell takes, from the server's `file_rules` on the table
/// answer (CRM LAW T-64), so a change needs no store build. A server that
/// does not send them yet gets today's values (CRM lib/spaces/list-files.js).
class CellFileRules {
  final List<String> accept;
  final int fileBytes;
  final int perCell;
  final String typeText;
  final String tooLargeText;
  const CellFileRules({
    required this.accept,
    required this.fileBytes,
    required this.perCell,
    required this.typeText,
    required this.tooLargeText,
  });

  static const fallback = CellFileRules(
    accept: [
      'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', //
      'pdf', 'doc', 'docx', 'xls', 'xlsx',
    ],
    fileBytes: 25 * 1024 * 1024,
    perCell: 5,
    typeText:
        'Chỉ nhận ảnh (JPG, PNG, WebP, HEIC), PDF, Word (.doc, .docx) hoặc Excel (.xls, .xlsx).',
    tooLargeText: 'Mỗi tệp tối đa 25 MB.',
  );

  /// From the table answer's `file_rules`; each missing or odd value keeps
  /// its fallback.
  factory CellFileRules.of(Object? raw) {
    if (raw is! Map) return fallback;
    final f = fallback;
    final acc = raw['accept'];
    final list = acc is List
        ? [
            for (final e in acc)
              if ('$e'.trim().isNotEmpty) '$e'.trim().toLowerCase(),
          ]
        : const <String>[];
    int pos(Object? v, int d) => v is num && v > 0 ? v.toInt() : d;
    String text(Object? v, String d) =>
        v is String && v.trim().isNotEmpty ? v : d;
    return CellFileRules(
      accept: list.isEmpty ? f.accept : list,
      fileBytes: pos(raw['file_bytes'], f.fileBytes),
      perCell: pos(raw['per_cell'], f.perCell),
      typeText: text(raw['type_text'], f.typeText),
      tooLargeText: text(raw['too_large_text'], f.tooLargeText),
    );
  }

  bool takes(String name) {
    final dot = name.lastIndexOf('.');
    return dot >= 0 && accept.contains(name.substring(dot + 1).toLowerCase());
  }

  /// The image extensions taken: what "Chọn ảnh" may send.
  bool get takesPhotos => accept.any(_imageExt.contains);
  static const _imageExt = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
}

/// The files of one cell as the server lists them (`cells[col].files`).
List<Map<String, dynamic>> cellFilesOf(Map? cell) => [
  for (final f in (cell?['files'] as List?) ?? const [])
    if (f is Map) f.cast<String, dynamic>(),
];

/// The web cell's routes (CRM routes/spaces/spaces.js, "Files in a table
/// cell"), with the person's session.
class CellFilesApi {
  final String spaceId, listId, rowId, columnId;
  const CellFilesApi(this.spaceId, this.listId, this.rowId, this.columnId);

  String get base =>
      '/spaces/$spaceId/student-lists/$listId/rows/$rowId/cells/$columnId/files';
  String fileUrl(String fileId) => '$base/$fileId';

  /// All picked files in one request (the server takes all or none).
  Future<Map<String, dynamic>> add(
    List<({List<int> bytes, String filename})> files, {
    required int maxBytes,
    void Function(int sent, int total)? onProgress,
    void Function(UploadStatus)? onStatus,
  }) => EmsUpload.files(
    base,
    files: files,
    field: 'files',
    maxBytes: maxBytes,
    onProgress: onProgress,
    onStatus: onStatus,
  );

  Future<void> remove(String fileId) =>
      EmsApiService.sendMap('DELETE', fileUrl(fileId));
}

/// Thumbnails downloaded once per screen (by file id).
class CellThumbs {
  final _got = <String, Future<File>>{};
  Future<File> of(CellFilesApi api, Map f) {
    final id = '${f['id']}';
    return _got.putIfAbsent(
      id,
      () => EmsUpload.download(
        api.fileUrl(id),
        filename: '${f['name'] ?? 'anh'}',
        key: 'cell_$id',
      ),
    );
  }
}

/// A file's short label on a chip: its extension ("PDF"), else "Tệp".
String fileBadge(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toUpperCase();
  return ext.isEmpty || ext.length > 4 ? 'Tệp' : ext;
}

/// One "Tệp / ảnh" cell in a table row: up to three thumbnails or file chips,
/// the count, and "+" for whoever may add here. Tapping a file opens it.
class TableFileCell extends StatelessWidget {
  final List<Map<String, dynamic>> files;
  final bool canAdd;
  final CellFilesApi api;
  final CellThumbs thumbs;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic> file) onOpen;
  const TableFileCell({
    super.key,
    required this.files,
    required this.canAdd,
    required this.api,
    required this.thumbs,
    required this.onAdd,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final shown = files.take(3).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in shown)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              key: ValueKey('cell-file-${f['id']}'),
              onTap: () => onOpen(f),
              borderRadius: BorderRadius.circular(6),
              child: _FileThumb(file: f, api: api, thumbs: thumbs),
            ),
          ),
        if (files.isEmpty)
          Text('—', style: TextStyle(color: vd.inkFaint))
        else
          Text(
            files.length > shown.length
                ? '+${files.length - shown.length} · ${files.length} tệp'
                : '${files.length} tệp',
            style: TextStyle(fontSize: 12, color: vd.inkMuted),
          ),
        if (canAdd)
          IconButton(
            key: const ValueKey('cell-file-add'),
            tooltip: 'Thêm tệp / ảnh',
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline),
          ),
      ],
    );
  }
}

/// A 36-point square: the photo itself (downloaded with the session) or a
/// chip with the file's extension.
class _FileThumb extends StatelessWidget {
  final Map<String, dynamic> file;
  final CellFilesApi api;
  final CellThumbs thumbs;
  const _FileThumb({
    required this.file,
    required this.api,
    required this.thumbs,
  });

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final name = '${file['name'] ?? ''}';
    final chip = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: vd.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: vd.hairline),
      ),
      child: Text(
        fileBadge(name),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: vd.inkMuted,
        ),
      ),
    );
    if (file['thumb'] != true) return chip;
    return FutureBuilder<File>(
      future: thumbs.of(api, file),
      builder: (_, snap) => snap.hasData
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                snap.data!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                cacheWidth: 108,
                errorBuilder: (_, _, _) => chip,
              ),
            )
          : chip,
    );
  }
}
