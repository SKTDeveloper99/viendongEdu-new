import 'package:flutter/material.dart';

import '../../services/ems_api_service.dart' show EmsException;
import '../../services/ems_upload.dart' show EmsUpload, UploadStatus;
import '../../theme/vd_tokens.dart';
import '../work/file_pick.dart';
import '../work/hand_in_sheet.dart' show PickFiles, PickedFile;
import '../work/open_attachment.dart';
import 'papers_api.dart';
import 'widgets/paper_item_card.dart';

typedef SendPaper =
    Future<PaperItem?> Function(
      String code,
      List<int> bytes,
      String filename,
      int maxBytes,
    );

/// [SendPaper] that also reports how the upload goes (resends included).
typedef SendPaperWatched =
    Future<PaperItem?> Function(
      String code,
      List<int> bytes,
      String filename,
      int maxBytes,
      void Function(UploadStatus) onStatus,
    );

Future<PaperItem?> _send(
  String code,
  List<int> b,
  String n,
  int max,
  void Function(UploadStatus) onStatus,
) => StudentPapersApi.send(
  code,
  bytes: b,
  filename: n,
  maxBytes: max,
  onStatus: onStatus,
);

/// "Nộp hồ sơ": what the school asks this student for (told by the server),
/// each item's state, what was sent, and Chụp ảnh / Chọn ảnh / Chọn tệp.
class StudentPapersScreen extends StatefulWidget {
  final Future<PapersPage> Function() load;

  /// A sender without status (tests); when null, [sendWatched] is used.
  final SendPaper? send;
  final SendPaperWatched sendWatched;
  final PickFiles takePhoto;
  final PickFiles pickPhotos;
  final Future<List<PickedFile>> Function(List<String> ext) pickFiles;
  const StudentPapersScreen({
    super.key,
    this.load = StudentPapersApi.list,
    this.send,
    this.sendWatched = _send,
    this.takePhoto = takePhotoFile,
    this.pickPhotos = pickPhotoFilesForHandIn,
    this.pickFiles = pickFilesOfTypes,
  });

  @override
  State<StudentPapersScreen> createState() => _StudentPapersScreenState();
}

class _StudentPapersScreenState extends State<StudentPapersScreen> {
  PapersPage? _page;
  String? _error;
  String? _sending;

  /// The line under the item being sent ("Tệp 2/3: Mạng yếu, đang gửi lại
  /// (lần 2/3)…").
  String? _status;

  /// Per item: the picked files not sent yet after a network failure. "Gửi
  /// tiếp" sends these only; what already went is not sent again.
  final Map<String, List<PickedFile>> _left = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final page = await widget.load();
      if (!mounted) return;
      setState(() {
        _page = page;
        _error = null;
      });
    } on EmsException catch (e) {
      if (mounted) {
        setState(
          () => _error = StudentPapersApi.notOnServer(e)
              ? StudentPapersApi.notOpenMessage
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được. Thử lại sau.');
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add(PaperItem item) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.label),
              subtitle: Text(item.acceptsLabel),
            ),
            if (item.takesPhoto) ...[
              _choice(ctx, 'camera', Icons.photo_camera_outlined, 'Chụp ảnh'),
              _choice(ctx, 'photos', Icons.photo_library_outlined, 'Chọn ảnh'),
            ],
            if (item.takesFile)
              _choice(ctx, 'file', Icons.attach_file, 'Chọn tệp'),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final List<PickedFile> files;
    try {
      files = switch (source) {
        'camera' => await widget.takePhoto(),
        'photos' => await widget.pickPhotos(),
        _ => await widget.pickFiles(
          item.takesPhoto ? ['pdf', 'jpg', 'jpeg', 'png'] : ['pdf'],
        ),
      };
    } catch (_) {
      if (mounted) {
        _say('Không mở được ${source == 'camera' ? 'máy ảnh' : 'thư viện'}.');
      }
      return;
    }
    if (files.isEmpty || !mounted) return;
    await _upload(item, files);
  }

  Widget _choice(BuildContext ctx, String key, IconData icon, String text) =>
      ListTile(
        key: Key('paper-source-$key'),
        leading: Icon(icon),
        title: Text(text),
        onTap: () => Navigator.pop(ctx, key),
      );

  Future<void> _upload(PaperItem item, List<PickedFile> files) async {
    final max = _page?.maxFileBytes ?? 12 * 1024 * 1024;
    setState(() {
      _sending = item.code;
      _status = null;
      _left.remove(item.code);
    });
    var sent = 0;
    var i = 0;
    void status(UploadStatus s) {
      if (!mounted) return;
      final n = files.length;
      setState(() => _status = n == 1 ? s.text : 'Tệp ${i + 1}/$n: ${s.text}');
    }

    try {
      for (; i < files.length; i++) {
        final f = files[i];
        final bytes = await f.read();
        if (bytes.length > max) {
          _say('"${f.name}" quá lớn (tối đa ${max ~/ (1024 * 1024)} MB).');
          continue;
        }
        final plain = widget.send;
        if (plain != null) {
          await plain(item.code, bytes, f.name, max);
        } else {
          await widget.sendWatched(item.code, bytes, f.name, max, status);
        }
        sent++;
      }
      if (sent > 0) _say(sent == 1 ? 'Đã gửi.' : 'Đã gửi $sent tệp.');
    } on EmsException catch (e) {
      // No answer from the server (the network, after its resends): keep
      // what is left for "Gửi tiếp". An answer (a refusal) is final.
      if (e.statusCode == null && mounted) {
        setState(() => _left[item.code] = files.sublist(i));
      }
      _say(sent > 0 ? '${e.message} Đã gửi $sent tệp.' : e.message);
    } catch (_) {
      _say('Không gửi được. Thử lại sau.');
    } finally {
      await _reload();
      if (mounted) {
        setState(() {
          _sending = null;
          _status = null;
        });
      }
    }
  }

  void _open(PaperFile f) => openServerFile(
    context,
    StudentPapersApi.filePath(f.id),
    name: f.name,
    type: f.isPhoto ? 'image/jpeg' : EmsUpload.typeOf(f.name),
    key: 'paper_${f.id}',
  );

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final page = _page;
    Widget body;
    if (page == null && _error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (page == null) {
      body = _error == StudentPapersApi.notOpenMessage
          ? _message(Icons.hourglass_empty, _error!)
          : _message(Icons.cloud_off, _error!, retry: true);
    } else if (page.items.isEmpty) {
      body = _message(Icons.inbox_outlined, page.emptyMessage);
    } else {
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Những giấy tờ trường cần bạn gửi. Kéo xuống để cập nhật.',
                style: TextStyle(color: vd.inkMuted),
              ),
            ),
            for (final item in page.items)
              PaperItemCard(
                item: item,
                sending: _sending == item.code,
                status: _sending == item.code ? _status : null,
                left: _left[item.code]?.length ?? 0,
                onResume: _sending == null && _left[item.code] != null
                    ? () => _upload(item, _left[item.code]!)
                    : null,
                onAdd: _sending == null ? () => _add(item) : null,
                onOpen: _open,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: vd.surface,
      appBar: AppBar(title: const Text('Nộp hồ sơ')),
      body: body,
    );
  }

  Widget _message(IconData icon, String text, {bool retry = false}) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      Icon(icon, size: 48, color: context.vd.inkFaint),
      const SizedBox(height: 12),
      Text(
        text,
        key: const Key('papers-message'),
        textAlign: TextAlign.center,
        style: TextStyle(color: context.vd.inkMuted),
      ),
      if (retry) TextButton(onPressed: _reload, child: const Text('Thử lại')),
    ],
  );
}
