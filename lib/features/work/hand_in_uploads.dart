import '../../services/upload_sender.dart' show UploadStatus;
import 'hand_in_sheet.dart' show PickedFile;

/// Sends one picked file and reports how it goes (WorkApi.attach in the app).
typedef SendOne =
    Future<void> Function(
      PickedFile file,
      void Function(UploadStatus) onStatus,
    );

/// A multi-file hand-in sent one file per request. The files that went are
/// remembered, so after a failure (file 3 of 5 still failing after its
/// resends) the next "Thử lại" sends only files 3 to 5.
class HandInUploads {
  final List<PickedFile> files;
  HandInUploads(this.files);

  final Set<int> _sent = {};

  int get sentCount => _sent.length;
  bool get allSent => _sent.length == files.length;

  /// Sends every file not sent yet, in order; stops at the first failure
  /// (rethrown). [onLine]: the person's line for the file on its way.
  Future<void> sendRest(SendOne send, {void Function(String)? onLine}) async {
    for (var i = 0; i < files.length; i++) {
      if (_sent.contains(i)) continue;
      await send(files[i], (s) => onLine?.call(lineFor(i, s)));
      _sent.add(i);
    }
  }

  /// "Tệp 3/5: Mạng yếu, đang gửi lại (lần 2/3)…" (no prefix for one file).
  String lineFor(int index, UploadStatus s) => files.length == 1
      ? s.text
      : 'Tệp ${index + 1}/${files.length}: ${s.text}';

  /// After a failure: what already went and stays (null when nothing went
  /// or everything did).
  String? get keptLine => _sent.isEmpty || allSent
      ? null
      : 'Đã gửi ${_sent.length}/${files.length} tệp. '
            'Bấm Thử lại để gửi tiếp các tệp còn lại.';
}
