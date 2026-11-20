import '../../services/app_session.dart';
import '../../services/ems_api_service.dart';
import '../../services/ems_upload.dart';

/// One file the student sent (or staff filed) for an item.
class PaperFile {
  final String id;
  final String name;
  final bool isPhoto;
  final DateTime? sentAt;
  final String review;
  final String reviewLabel;
  final String? rejectReason;
  const PaperFile({
    required this.id,
    required this.name,
    required this.isPhoto,
    required this.sentAt,
    required this.review,
    required this.reviewLabel,
    this.rejectReason,
  });

  factory PaperFile.fromJson(Map<String, dynamic> j) => PaperFile(
    id: '${j['id']}',
    name: '${j['name'] ?? 'Tệp'}',
    isPhoto: j['kind'] == 'photo',
    sentAt: DateTime.tryParse('${j['sent_at'] ?? ''}')?.toLocal(),
    review: '${j['review'] ?? 'pending'}',
    reviewLabel: '${j['review_label'] ?? ''}',
    rejectReason: j['reject_reason']?.toString(),
  );
}

/// One thing the school asks of this student, as the server words it (CRM
/// LAW S-57, proposed): a new ask is a server catalog row, no app build.
class PaperItem {
  final String code;
  final String label;
  final String description;

  /// `photo`, `photo_or_pdf` or `pdf`.
  final String accepts;
  final String acceptsLabel;
  final bool required;
  final DateTime? dueOn;
  final bool overdue;

  /// `ok`, `wait`, `bad` or `none`.
  final String state;
  final String stateLabel;
  final List<String> reasons;
  final List<PaperFile> files;
  const PaperItem({
    required this.code,
    required this.label,
    required this.description,
    required this.accepts,
    required this.acceptsLabel,
    required this.required,
    required this.dueOn,
    required this.overdue,
    required this.state,
    required this.stateLabel,
    required this.reasons,
    required this.files,
  });

  bool get takesPhoto => accepts != 'pdf';
  bool get takesFile => accepts != 'photo';

  factory PaperItem.fromJson(Map<String, dynamic> j) => PaperItem(
    code: '${j['code']}',
    label: '${j['label'] ?? ''}',
    description: '${j['description'] ?? ''}',
    accepts: '${j['accepts'] ?? 'photo'}',
    acceptsLabel: '${j['accepts_label'] ?? ''}',
    required: j['required'] == true,
    dueOn: DateTime.tryParse('${j['due_on'] ?? ''}'),
    overdue: j['overdue'] == true,
    state: '${j['state'] ?? 'none'}',
    stateLabel: '${j['state_label'] ?? ''}',
    reasons: [for (final r in (j['reasons'] as List? ?? const [])) '$r'],
    files: [
      for (final f in (j['files'] as List? ?? const []))
        PaperFile.fromJson((f as Map).cast<String, dynamic>()),
    ],
  );
}

class PapersPage {
  final List<PaperItem> items;
  final String emptyMessage;
  final int maxFileBytes;
  const PapersPage(this.items, this.emptyMessage, this.maxFileBytes);
}

/// "Nộp hồ sơ" of the signed-in student: `GET /student/me/papers`,
/// `POST /student/me/papers/:code/files` (one file per request, field
/// `files[]`), `GET /student/me/papers/files/:id`.
abstract final class StudentPapersApi {
  /// A server from before "Nộp hồ sơ" (CRM S-57) answers its catch-all 404
  /// `{error: 'Endpoint not found'}`: the feature is not open there yet, and
  /// trying again will not help.
  static bool notOnServer(EmsException e) =>
      e.statusCode == 404 && e.code == 'Endpoint not found';
  static const notOpenMessage =
      'Mục Nộp hồ sơ chưa mở trên máy chủ của trường. Khi trường mở, '
      'những giấy tờ cần nộp sẽ hiện ở đây.';

  static Future<PapersPage> list() async {
    final b = await EmsApiService.sendMap('GET', '/student/me/papers');
    return EmsApiService.parse(
      () => PapersPage(
        [
          for (final i in (b['items'] as List))
            PaperItem.fromJson((i as Map).cast<String, dynamic>()),
        ],
        '${b['empty_message'] ?? 'Hiện trường chưa yêu cầu bạn nộp giấy tờ nào.'}',
        ((b['max_file_mb'] as num?) ?? 12).toInt() * 1024 * 1024,
      ),
    );
  }

  /// Sends one file; the server answers with the item as it now stands.
  static Future<PaperItem?> send(
    String code, {
    required List<int> bytes,
    required String filename,
    required int maxBytes,
    void Function(UploadStatus)? onStatus,
  }) async {
    final b = await EmsUpload.files(
      '/student/me/papers/${Uri.encodeComponent(code)}/files',
      files: [(bytes: bytes, filename: filename)],
      field: 'files[]',
      maxBytes: maxBytes,
      onStatus: onStatus,
    );
    final item = b['item'];
    return item is Map
        ? PaperItem.fromJson(item.cast<String, dynamic>())
        : null;
  }

  /// Server path of one own file (for openServerFile).
  static String filePath(String id) => '/student/me/papers/files/$id';

  /// Full URL and session header of a photo's thumbnail (Image.network).
  static String thumbUrl(String id) =>
      '${EmsApiService.baseUrl}${filePath(id)}?size=thumb';
  static Map<String, String> get authHeaders {
    final t = AppSession.instance.emsToken;
    return {if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t'};
  }
}
