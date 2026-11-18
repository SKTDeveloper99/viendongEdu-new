import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../services/ems_api_service.dart' show EmsException;
import '../../services/ems_upload.dart';
import '../../utils/snack.dart';

/// Opens one file of a piece for the giver or the receiver: downloaded with
/// the person's session into the app cache, a photo in the app, anything
/// else handed to the phone's viewer (open_filex).
Future<void> openAttachment(BuildContext context, String taskId, Map f) async {
  final id = '${f['id'] ?? ''}';
  if (id.isEmpty) return;
  final name = '${f['filename'] ?? 'tep'}';
  final given = '${f['mime_type'] ?? ''}';
  final type = given.isEmpty || given == 'application/octet-stream'
      ? EmsUpload.typeOf(name)
      : given;
  try {
    final file = await EmsUpload.download(
      '/v1/tasks/$taskId/attachments/$id',
      filename: name,
      key: id,
    );
    if (!context.mounted) return;
    if (type.startsWith('image/')) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(name)),
            body: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Image.file(
                  file,
                  // HEIC / SVG on Android: the phone's own viewer may know it.
                  errorBuilder: (ctx, _, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Máy không hiển thị được ảnh này trong ứng dụng.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _openOutside(ctx, file.path, type),
                          child: const Text('Mở bằng ứng dụng khác'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }
    await _openOutside(context, file.path, type);
  } on EmsException catch (e) {
    if (context.mounted) showErrorSnack(context, e.message);
  } catch (_) {
    if (context.mounted) showErrorSnack(context, 'Không mở được tệp.');
  }
}

/// Hands a saved file to the phone's own viewer (open_filex).
Future<void> _openOutside(BuildContext context, String path, String type) async {
  final r = await OpenFilex.open(path, type: type);
  if (!context.mounted || r.type == ResultType.done) return;
  showErrorSnack(
    context,
    r.type == ResultType.noAppToOpen
        ? 'Máy chưa có ứng dụng mở loại tệp này.'
        : 'Không mở được tệp.',
  );
}
