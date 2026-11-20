import '../../services/ems_api_service.dart' show EmsException;
import '../../services/ems_upload.dart' show UploadStatus;
import '../work/hand_in_sheet.dart' show PickedFile;
import 'papers_api.dart';

/// Sends one file of an item (tests replace it).
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

Future<PaperItem?> sendPaperWatched(
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

/// Sends [files] of one item one by one (one file per request, as the
/// server takes them). A file over [maxBytes] (the server's max_file_mb) is
/// left out with a line. When a file fails on the network after its resends,
/// the rest from it on are returned in `left`, so "Gửi tiếp" sends only
/// those; a refusal of the server is final (nothing left to resend).
Future<({int sent, List<PickedFile> left})> sendPaperFiles(
  List<PickedFile> files, {
  required int maxBytes,
  required Future<void> Function(
    PickedFile f,
    List<int> bytes,
    void Function(UploadStatus) onStatus,
  )
  send,
  required void Function(String line) onLine,
  required void Function(String text) say,
}) async {
  var sent = 0;
  final n = files.length;
  for (var i = 0; i < n; i++) {
    final f = files[i];
    final bytes = await f.read();
    if (bytes.length > maxBytes) {
      say('"${f.name}" quá lớn (tối đa ${maxBytes ~/ (1024 * 1024)} MB).');
      continue;
    }
    try {
      await send(
        f,
        bytes,
        (s) => onLine(n == 1 ? s.text : 'Tệp ${i + 1}/$n: ${s.text}'),
      );
    } on EmsException catch (e) {
      say(sent > 0 ? '${e.message} Đã gửi $sent tệp.' : e.message);
      // No status = no answer from the server (the network).
      return (
        sent: sent,
        left: e.statusCode == null ? files.sublist(i) : <PickedFile>[],
      );
    }
    sent++;
  }
  if (sent > 0) say(sent == 1 ? 'Đã gửi.' : 'Đã gửi $sent tệp.');
  return (sent: sent, left: <PickedFile>[]);
}
